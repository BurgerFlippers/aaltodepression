#if os(iOS)
import Foundation
import CoreMotion
import HealthKit

@MainActor
final class EverydaySensors {
    private let pedometer = CMPedometer()
    private let health = HKHealthStore()

    func movement(requestAccess: Bool = false) async throws -> EverydayMovementReading? {
        guard CMPedometer.isStepCountingAvailable() else { throw SensorError.unavailable }
        let status = CMPedometer.authorizationStatus()
        guard status != .denied && status != .restricted else { throw SensorError.permission }
        guard requestAccess || status == .authorized else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        return try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: Date()) { data, error in
                if let error { continuation.resume(throwing: error) }
                else if let data { continuation.resume(returning: EverydayMovementReading(date: data.endDate, steps: data.numberOfSteps.intValue)) }
                else { continuation.resume(returning: nil) }
            }
        }
    }

    func authorizeSleep() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw SensorError.unavailable }
        try await health.requestAuthorization(toShare: [], read: [HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!])
    }

    func sleep() async throws -> EverydaySleepReading? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-12 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let asleep = Set([HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue])
                let intervals = (samples as? [HKCategorySample] ?? []).filter { asleep.contains($0.value) }.map { ($0.startDate, $0.endDate) }.sorted { $0.0 < $1.0 }
                guard let first = intervals.first else { continuation.resume(returning: nil); return }
                // Merge overlapping sources so an iPhone and Watch never double-count sleep.
                var begin = first.0, end = first.1, duration: TimeInterval = 0
                let earliest = begin
                for interval in intervals.dropFirst() {
                    if interval.0 <= end { end = max(end, interval.1) }
                    else { duration += end.timeIntervalSince(begin); begin = interval.0; end = interval.1 }
                }
                duration += end.timeIntervalSince(begin)
                continuation.resume(returning: EverydaySleepReading(start: earliest, end: end, minutes: Int(duration / 60)))
            }
            health.execute(query)
        }
    }

    enum SensorError: Error { case unavailable, permission }
}
#endif
