import Foundation
import CoreLocation

/// Visits from install onward. Turns each day into a few numbers: time at home and away,
/// places visited, furthest distance from home and how spread the day was.
/// Place centres (rounded to about 100 m) stay in a local file so home can be recognised;
/// nothing about location leaves the phone.
@MainActor
final class LocationSource: NSObject, CLLocationManagerDelegate {
    struct Place: Codable { var lat: Double; var lon: Double; var overnights: Int }
    struct Stay: Codable { var place: Int; var arrival: Date; var departure: Date }
    struct Log: Codable { var places: [Place] = []; var stays: [Stay] = [] }

    private let manager = CLLocationManager()
    private var log = Log()
    private let url = URL.applicationSupportDirectory.appending(path: "visits.json")
    var onChange: (() -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(Log.self, from: data) { log = saved }
    }

    var authorization: CLAuthorizationStatus { manager.authorizationStatus }
    var isEnabled: Bool { [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) }
    var approximateLocation: CLLocation? { manager.location }

    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    func start() {
        guard isEnabled else { return }
        manager.startMonitoringVisits()
        manager.startMonitoringSignificantLocationChanges()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let lat = visit.coordinate.latitude, lon = visit.coordinate.longitude
        let arrival = visit.arrivalDate, departure = visit.departureDate
        Task { @MainActor in self.record(lat: lat, lon: lon, arrival: arrival, departure: departure) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.start(); self.onChange?() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

    private func record(lat: Double, lon: Double, arrival: Date, departure: Date) {
        let here = CLLocation(latitude: lat, longitude: lon)
        let index = log.places.firstIndex { CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: here) < 150 }
            ?? { log.places.append(Place(lat: (lat * 1000).rounded() / 1000, lon: (lon * 1000).rounded() / 1000, overnights: 0)); return log.places.count - 1 }()
        let a = arrival == .distantPast ? departure.addingTimeInterval(-3600) : arrival
        let d = departure == .distantFuture ? Date() : departure
        // An overnight stay covers 03:00.
        let cal = Calendar.current
        let threeAM = cal.date(bySettingHour: 3, minute: 0, second: 0, of: d) ?? d
        if a <= threeAM && threeAM <= d { log.places[index].overnights += 1 }
        log.stays.removeAll { $0.place == index && $0.arrival == a }
        log.stays.append(Stay(place: index, arrival: a, departure: d))
        log.stays = log.stays.filter { $0.departure > Date().addingTimeInterval(-400 * 86400) }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(log).write(to: url, options: [.atomic, .completeFileProtection])
        onChange?()
    }

    /// Daily numbers from the stays. Days without any stay stay unknown.
    func table(calendar: Calendar = .current) -> FeatureTable {
        var t = FeatureTable()
        guard let home = log.places.indices.max(by: { log.places[$0].overnights < log.places[$1].overnights }) else { return t }
        let homeLoc = CLLocation(latitude: log.places[home].lat, longitude: log.places[home].lon)
        var byDay: [Day: [Int: Double]] = [:]   // hours per place
        for s in log.stays {
            var cursor = s.arrival
            while cursor < s.departure {
                let next = min(s.departure, calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: cursor)!))
                byDay[Day(cursor, calendar: calendar), default: [:]][s.place, default: 0] += next.timeIntervalSince(cursor) / 3600
                cursor = next
            }
        }
        for (day, places) in byDay {
            let homeHours = min(24, places[home] ?? 0)
            t.set(F.homeHours, day, homeHours)
            t.set(F.awayHours, day, max(0, 24 - homeHours))
            t.set(F.placesVisited, day, Double(places.keys.filter { $0 != home }.count))
            let km = places.keys.map { CLLocation(latitude: log.places[$0].lat, longitude: log.places[$0].lon).distance(from: homeLoc) / 1000 }.max() ?? 0
            t.set(F.maxKmFromHome, day, km)
            let total = places.values.reduce(0, +)
            if total > 0 {
                t.set(F.locationEntropy, day, -places.values.map { $0 / total }.filter { $0 > 0 }.map { $0 * log2($0) }.reduce(0, +))
            }
        }
        return t
    }
}

/// Sunrise, sunset and day length for each day, from approximate location.
nonisolated enum SolarSource {
    static func table(days: [Day], latitude: Double, longitude: Double, calendar: Calendar = .current) -> FeatureTable {
        var t = FeatureTable()
        let tz = calendar.timeZone
        for d in days {
            let s = Solar.times(date: d.start(in: calendar), latitude: latitude, longitude: longitude, timeZone: tz)
            t.set(F.dayLengthH, d, s.dayLengthHours)
            let start = d.start(in: calendar)
            if let r = s.sunrise { t.set(F.sunrise, d, r.timeIntervalSince(start) / 3600) }
            if let x = s.sunset { t.set(F.sunset, d, x.timeIntervalSince(start) / 3600) }
        }
        return t
    }
}

/// The research version with Aalto plugs SensorKit in here. SensorKit needs an Apple research
/// entitlement granted per approved study, so this build has no implementation.
protocol SensorKitSource: Sendable {
    /// deviceUsageMin, unlocks, keyboardTypingSpeed, messagesContacts, callMin, ambientLux, speechRate
    static var featureKeys: [String] { get }
    func read(from: Day, to: Day) async throws -> FeatureTable
}

extension SensorKitSource {
    static var featureKeys: [String] {
        [F.deviceUsageMin, F.unlocks, F.keyboardTypingSpeed, F.messagesContacts, F.callMin, F.ambientLux, F.speechRate]
    }
}
