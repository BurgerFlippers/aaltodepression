import Foundation
import Observation
import HealthKit
import CoreMotion
import CoreLocation
import UserNotifications

/// Everything the app may ask the person for, in the order onboarding should ask.
/// Contacts are not here on purpose: the system contact picker needs no permission.
nonisolated enum PermissionKind: String, CaseIterable, Sendable, Identifiable {
    case health, motion, location, notifications, medications
    var id: String { rawValue }

    var title: String {
        switch self {
        case .health: "Apple Health"
        case .motion: "Motion"
        case .location: "Location"
        case .notifications: "Notifications"
        case .medications: "Medications in Health"
        }
    }

    /// Why the app asks, in words for the person (onboarding can show these as they are).
    var reason: String {
        switch self {
        case .health: "Sleep, steps and heart data tick things off for you, so you don't have to log them. Headphone use is read only for when it happens late at night, never what or how loud."
        case .motion: "Notices a walk even without an Apple Watch."
        case .location: "Counts time at home and out as a few daily numbers. Places never leave the phone."
        case .notifications: "A morning check-in, medicine times, the shop question and an evening wind-down. At most a few a day."
        case .medications: "iOS 26: pick which medicines Health may share, and doses tick themselves."
        }
    }
}

nonisolated enum PermissionStatus: String, Sendable {
    case notAsked
    /// Asked, answer unknown. Health never tells an app what was allowed (by design).
    case asked
    case allowed, denied, restricted, unavailable
    /// Medications: granted one medicine at a time in Health's own sheet.
    case perItem

    var text: String {
        switch self {
        case .notAsked: "Not asked yet"
        case .asked: "Asked"
        case .allowed: "Allowed"
        case .denied: "Denied (change in the Settings app)"
        case .restricted: "Restricted"
        case .unavailable: "Not on this device"
        case .perItem: "Chosen per medicine"
        }
    }
}

/// Asks for permissions and reports their state. Uses only real iOS prompts.
/// Frontend: show `PermissionKind.allCases` with `status[kind]` and call `request(kind)`.
@MainActor @Observable
final class PermissionCenter: NSObject, CLLocationManagerDelegate {
    private(set) var status: [PermissionKind: PermissionStatus] = [:]
    @ObservationIgnored private let location = CLLocationManager()

    override init() {
        super.init()
        location.delegate = self
    }

    func refresh() async {
        status[.health] = await Self.healthStatus()
        status[.motion] = Self.motionStatus()
        status[.location] = Self.locationStatus(location.authorizationStatus)
        status[.notifications] = await Self.notificationStatus()
        if #available(iOS 26.0, *) { status[.medications] = .perItem } else { status[.medications] = .unavailable }
    }

    func request(_ kind: PermissionKind) async {
        switch kind {
        case .health: try? await HealthKitSource().requestAuthorization()
        case .motion: _ = await MotionSource.read()     // the first query shows the Motion prompt
        case .location: location.requestAlwaysAuthorization()
        case .notifications: _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        case .medications: await HealthKitSource().requestMedicationAccess()
        }
        await refresh()
    }

    /// Asks for everything in order (onboarding's "Allow all" button).
    func requestAll() async {
        for k in PermissionKind.allCases where k != .medications { await request(k) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in self.status[.location] = Self.locationStatus(s) }
    }

    // MARK: - Probes

    nonisolated static func healthStatus() async -> PermissionStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let read = HealthKitSource.readTypes.filter { !HealthKitSource.disallowed.contains($0.identifier) }
        guard let s = try? await HKHealthStore().statusForAuthorizationRequest(toShare: HealthKitSource.shareTypes, read: read) else { return .notAsked }
        return s == .unnecessary ? .asked : .notAsked
    }

    nonisolated static func motionStatus() -> PermissionStatus {
        guard CMMotionActivityManager.isActivityAvailable() else { return .unavailable }
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized: return .allowed
        case .denied: return .denied
        case .restricted: return .restricted
        default: return .notAsked
        }
    }

    nonisolated static func locationStatus(_ s: CLAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorizedAlways, .authorizedWhenInUse: return .allowed
        case .denied: return .denied
        case .restricted: return .restricted
        default: return .notAsked
        }
    }

    nonisolated static func notificationStatus() async -> PermissionStatus {
        let s = await withCheckedContinuation { (c: CheckedContinuation<UNAuthorizationStatus, Never>) in
            UNUserNotificationCenter.current().getNotificationSettings { c.resume(returning: $0.authorizationStatus) }
        }
        switch s {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .denied: return .denied
        default: return .notAsked
        }
    }
}
