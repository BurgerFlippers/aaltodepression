import Foundation

@main
struct EverydayStoreCheck {
    @MainActor static func main() throws {
        let directory = URL.temporaryDirectory.appendingPathComponent("everyday-check-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = EverydayStore(directory: directory)
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 12))!
        store.refreshDay(now: now)
        assert(store.priority(at: now) == .food)
        assert(!store.activeTasks.contains(.medication))
        store.state.profile.usesMedication = true
        store.state.profile.medicationHour = 8
        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        assert(store.priority(at: morning) == .medication)
        store.complete(.food)
        assert(store.priority(at: now) == .movement)
        store.deferTask(.movement)
        assert(store.priority(at: now) == .medication)
        store.undo(.movement)
        assert(store.priority(at: now) == .movement)
        store.addPerson(EverydayPerson(id: "friend", name: "Ystävä", phone: "+358 40 123 4567", role: .friend))
        store.addPerson(EverydayPerson(id: "duplicate", name: "Sama", phone: "+358401234567", role: .close))
        assert(store.state.people.count == 1)
        store.state.supportDemoEnabled = true
        store.answerHousehold(.groceries, needsHelp: true, at: now)
        assert(store.state.supportDrafts.isEmpty, "Friends must not receive household support")
        assert(store.dueHousehold(at: now) == nil)
        store.addPerson(EverydayPerson(id: "close", name: "Lähimmäinen", phone: "+358 40 765 4321", role: .close))
        let later = now.addingTimeInterval(3 * 86400)
        store.answerHousehold(.groceries, needsHelp: true, at: later)
        assert(store.state.supportDrafts.count == 1)
        assert(store.state.supportDrafts.first?.personID == "close")
        assert(store.dueHousehold(at: later.addingTimeInterval(86400)) == nil, "No daily household questions")
        store.postponeHousehold(.groceries, at: later)
        assert(store.state.household[HouseholdKind.groceries.rawValue]?.needsHelp == true)
        assert(store.persistenceError == nil)
        let loaded = EverydayStore(directory: directory)
        assert(loaded.state.people.count == 2)
        assert(loaded.state.supportDrafts.count == 1)
        assert(loaded.state.profile.usesMedication)
        loaded.refreshDay(now: later)
        assert(loaded.state.completed.isEmpty && loaded.state.deferred.isEmpty)
        assert(loaded.state.household.count == 1)
        let sensorStore = EverydayStore(directory: directory.appendingPathComponent("sensors"))
        sensorStore.refreshDay(now: now)
        sensorStore.recordMovement(EverydayMovementReading(date: now, steps: 499))
        assert(!sensorStore.isDone(.movement, at: now))
        sensorStore.recordMovement(EverydayMovementReading(date: now, steps: 500))
        assert(sensorStore.isDone(.movement, at: now))
        sensorStore.undo(.movement)
        sensorStore.recordMovement(EverydayMovementReading(date: now, steps: 700))
        assert(!sensorStore.isDone(.movement, at: now), "A user's correction must survive refresh")
        sensorStore.state.sleepReading = EverydaySleepReading(start: now.addingTimeInterval(-8 * 3600), end: now, minutes: 420)
        assert(sensorStore.isDone(.sleep, at: now))
        assert(!sensorStore.isDone(.sleep, at: later), "Yesterday's sleep cannot fill a later day")
        sensorStore.undo(.sleep)
        assert(!sensorStore.isDone(.sleep, at: now))
        sensorStore.state.profile.usesMedication = true
        sensorStore.state.profile.medicationHour = 8
        sensorStore.state.profile.medicationMinute = 30
        assert(sensorStore.priority(at: morning) == .food)
        assert(sensorStore.priority(at: morning.addingTimeInterval(30 * 60)) == .medication)
        sensorStore.disconnectMotion()
        assert(sensorStore.state.motionEnabled == false && sensorStore.state.movementReading == nil)
        sensorStore.disconnectSleep()
        assert(sensorStore.state.healthSleepEnabled == false && sensorStore.state.sleepReading == nil)
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(EverydayState())) as! [String: Any]
        for key in ["motionEnabled", "healthSleepEnabled", "movementReading", "sleepReading", "ignoredMovementDay", "ignoredSleepDay"] { old.removeValue(forKey: key) }
        let legacy = try JSONDecoder().decode(EverydayState.self, from: JSONSerialization.data(withJSONObject: old))
        assert(legacy.movementReading == nil && legacy.motionEnabled == nil)
        print("ALL EVERYDAY CHECKS PASSED: priority, optional medication, day rollover, persistence, contact deduplication, household spacing, role routing, local support drafts")
    }
}
