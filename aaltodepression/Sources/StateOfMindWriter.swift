import Foundation
import HealthKit

/// Saves the daily check-in to Apple Health as a State of Mind (iOS 18+), so the person's own
/// Health app shows it too. Failing to save never blocks the check-in.
nonisolated enum StateOfMindWriter {
    static func save(_ c: CheckIn) async {
        guard #available(iOS 18.0, *), HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        guard store.authorizationStatus(for: HKObjectType.stateOfMindType()) == .sharingAuthorized else { return }
        // Mood 1...5 → valence -1...1.
        let valence = Double(c.mood - 3) / 2
        let labels: [HKStateOfMind.Label] = c.feelings.compactMap {
            switch $0 {
            case .calm: .calm
            case .good: .content
            case .tired: .drained
            case .low: .sad
            case .anxious: .anxious
            }
        }
        // One sample per day: a redone check-in replaces the earlier one (same sync identifier, newer version).
        let metadata: [String: Any] = [HKMetadataKeySyncIdentifier: "usual.checkin.\(c.day.jdn)",
                                       HKMetadataKeySyncVersion: Int(c.at.timeIntervalSince1970)]
        let sample = HKStateOfMind(date: c.at, kind: .dailyMood, valence: valence, labels: labels, associations: [], metadata: metadata)
        try? await store.save(sample)
    }
}
