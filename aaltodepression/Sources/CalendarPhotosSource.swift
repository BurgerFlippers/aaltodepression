import Foundation
import EventKit
import Photos
import CoreLocation

/// Calendar: number of events and hours in them per day. Read-only, titles are never stored.
nonisolated enum CalendarSource {
    static func requestAccess() async {
        _ = try? await EKEventStore().requestFullAccessToEvents()
    }

    static func read(days: Int = 365, calendar: Calendar = .current) -> FeatureTable {
        var t = FeatureTable()
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return t }
        let store = EKEventStore()
        let end = Date()
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: end)!)
        var count: [Day: Double] = [:], hours: [Day: Double] = [:]
        // EventKit limits one predicate to about four years; a year is fine in one go.
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        for e in events where !e.isAllDay {
            let day = Day(e.startDate, calendar: calendar)
            count[day, default: 0] += 1
            hours[day, default: 0] += max(0, e.endDate.timeIntervalSince(e.startDate)) / 3600
        }
        // A day the calendar covers but with no events is a real zero, not unknown.
        for d in Day.range(Day(start, calendar: calendar), Day(end, calendar: calendar) + 1) {
            t.set(F.calendarEvents, d, count[d] ?? 0)
            t.set(F.eventHours, d, hours[d] ?? 0)
        }
        return t
    }
}

/// Photos: how many photos were taken per day and how many away from home. Only creation
/// dates and the distance to home are used; the pictures themselves are never opened.
nonisolated enum PhotosSource {
    static func requestAccess() async {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    static func read(home: CLLocation?, days: Int = 365, calendar: Calendar = .current) -> FeatureTable {
        var t = FeatureTable()
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return t }
        let start = calendar.date(byAdding: .day, value: -days, to: Date())!
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@", start as NSDate)
        var taken: [Day: Double] = [:], away: [Day: Double] = [:]
        PHAsset.fetchAssets(with: .image, options: options).enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            let day = Day(date, calendar: calendar)
            taken[day, default: 0] += 1
            if let home, let loc = asset.location, loc.distance(from: home) > 1000 { away[day, default: 0] += 1 }
        }
        for (d, v) in taken {
            t.set(F.photosTaken, d, v)
            if home != nil { t.set(F.photosAwayFromHome, d, away[d] ?? 0) }
        }
        return t
    }
}
