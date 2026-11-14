import Foundation
import Observation

@MainActor
@Observable
final class EverydayStore {
    var state: EverydayState { didSet { persist() } }
    private(set) var persistenceError: String?
    private let file: URL
    private var unreadableProfile = false
    private(set) var sensorStatus: String?
    private(set) var isRefreshingSensors = false
    #if os(iOS)
    @ObservationIgnored private let sensors = EverydaySensors()
    #endif

    init(directory: URL? = nil) {
        let folder = directory ?? URL.applicationSupportDirectory.appendingPathComponent("Everyday", isDirectory: true)
        file = folder.appendingPathComponent("profile-v1.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var privateFolder = folder
            try privateFolder.setResourceValues(values)
            if FileManager.default.fileExists(atPath: file.path) {
                state = try JSONDecoder().decode(EverydayState.self, from: Data(contentsOf: file))
            } else { state = EverydayState() }
        } catch {
            state = EverydayState()
            unreadableProfile = true
            persistenceError = "Your saved profile could not be opened. The original file has been kept."
        }
        let genders = ["En halua kertoa": "Prefer not to say", "Nainen": "Female", "Mies": "Male", "Muu": "Other"]
        if let migrated = genders[state.profile.gender] { state.profile.gender = migrated }
        for index in state.supportDrafts.indices {
            let text = state.supportDrafts[index].text
            if text == "Voisitko ehdottaa yhteistä kauppareissua tai tuoda muutaman ruokaostoksen?" {
                state.supportDrafts[index].text = "Could you suggest a grocery trip together or bring over a few groceries?"
            } else if text == "Voisitko tarjota apua pyykkien pesuun tällä viikolla?" {
                state.supportDrafts[index].text = "Could you offer a little help with laundry this week?"
            }
        }
        refreshDay()
    }

    private func persist() {
        // Never overwrite an unreadable profile with an empty one.
        guard persistenceError == nil else { return }
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            persistenceError = "Your changes could not be saved. Please try again before closing Beside."
        }
    }

    func retrySaving() {
        if unreadableProfile, FileManager.default.fileExists(atPath: file.path) {
            do { try FileManager.default.copyItem(at: file, to: file.deletingLastPathComponent().appendingPathComponent("profile-recovery-\(UUID().uuidString).json")) }
            catch { persistenceError = "The original file could not be backed up. Your data has not been replaced."; return }
        }
        unreadableProfile = false
        persistenceError = nil
        persist()
    }

    func refreshDay(now: Date = Date()) {
        let calendar = Calendar.current
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        let key = "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
        guard state.taskDay != key else { return }
        state.taskDay = key
        state.completed = []
        state.deferred = []
    }

    var activeTasks: [EverydayTaskKind] {
        EverydayTaskKind.allCases.filter { $0 != .medication || state.profile.usesMedication }
    }

    func priority(at date: Date = Date()) -> EverydayTaskKind? {
        let hour = Calendar.current.component(.hour, from: date)
        let minuteOfDay = hour * 60 + Calendar.current.component(.minute, from: date)
        let medicationTime = state.profile.medicationHour * 60 + (state.profile.medicationMinute ?? 0)
        var order: [EverydayTaskKind] = [.food, .movement, .medication, .sleep]
        if hour >= state.profile.bedtimeHour - 1 || hour < 5 { order = [.sleep, .food, .medication, .movement] }
        else if state.profile.usesMedication && minuteOfDay >= medicationTime && minuteOfDay < medicationTime + 60 { order = [.medication, .food, .movement, .sleep] }
        return order.first { activeTasks.contains($0) && !isDone($0, at: date) && !state.deferred.contains($0) }
    }

    func complete(_ task: EverydayTaskKind) { state.completed.insert(task); state.deferred.remove(task) }
    func deferTask(_ task: EverydayTaskKind) { state.deferred.insert(task) }
    func undo(_ task: EverydayTaskKind) {
        state.completed.remove(task); state.deferred.remove(task)
        if task == .movement { state.ignoredMovementDay = state.taskDay }
        if task == .sleep { state.ignoredSleepDay = state.taskDay }
    }

    func isDone(_ task: EverydayTaskKind, at date: Date = Date()) -> Bool {
        if state.completed.contains(task) { return true }
        if task == .movement, state.ignoredMovementDay != state.taskDay,
           let reading = state.movementReading, Calendar.current.isDate(reading.date, inSameDayAs: date), reading.steps >= 500 { return true }
        if task == .sleep, state.ignoredSleepDay != state.taskDay,
           let reading = state.sleepReading, Calendar.current.isDate(reading.end, inSameDayAs: date), reading.minutes > 0 { return true }
        return false
    }

    func recordMovement(_ reading: EverydayMovementReading) { state.movementReading = reading }

    func refreshSensors() async {
        #if os(iOS)
        guard !isRefreshingSensors else { return }
        isRefreshingSensors = true
        defer { isRefreshingSensors = false }
        if state.motionEnabled == true {
            do { if let reading = try await sensors.movement() { recordMovement(reading) } }
            catch { sensorStatus = "Movement data is unavailable. Check Motion & Fitness access in Settings." }
        }
        if state.healthSleepEnabled == true {
            do { state.sleepReading = try await sensors.sleep() }
            catch { sensorStatus = "Sleep data is unavailable. You can still mark rest yourself." }
        }
        #endif
    }

    func disconnectMotion() {
        state.motionEnabled = false
        state.movementReading = nil
        sensorStatus = nil
    }

    func disconnectSleep() {
        state.healthSleepEnabled = false
        state.sleepReading = nil
        sensorStatus = nil
    }

    func connectMotion() async {
        #if os(iOS)
        do {
            if let reading = try await sensors.movement(requestAccess: true) { recordMovement(reading) }
            state.motionEnabled = true
            sensorStatus = "Movement is connected. Your iPhone can notice steps for you."
        } catch { state.motionEnabled = false; sensorStatus = "Motion access is unavailable. You can enable Motion & Fitness in iPhone Settings." }
        #endif
    }

    func connectSleep() async {
        #if os(iOS)
        do {
            try await sensors.authorizeSleep()
            state.healthSleepEnabled = true
            state.sleepReading = try await sensors.sleep()
            sensorStatus = state.sleepReading == nil ? "No shared sleep data yet. You can manage sleep access in Apple Health." : "Sleep data is connected."
        } catch { sensorStatus = "Sleep access could not be opened. You can still mark rest yourself." }
        #endif
    }

    func dueHousehold(at date: Date = Date()) -> HouseholdKind? {
        if let latest = state.household.values.map(\.date).max(), date.timeIntervalSince(latest) < 2 * 86400 { return nil }
        return HouseholdKind.allCases.first { kind in
            guard let last = state.household[kind.rawValue] else { return true }
            return date.timeIntervalSince(last.date) >= kind.interval
        }
    }

    // A positive interval after every answer, including "later", prevents daily nagging.
    func answerHousehold(_ kind: HouseholdKind, needsHelp: Bool, at date: Date = Date()) {
        state.household[kind.rawValue] = HouseholdAnswer(date: date, needsHelp: needsHelp)
        guard needsHelp, state.supportDemoEnabled,
              let person = state.people.first(where: { $0.role == .close }) else { return }
        let text = kind == .groceries
            ? "Could you suggest a grocery trip together or bring over a few groceries?"
            : "Could you offer a little help with laundry this week?"
        state.supportDrafts.insert(SupportDraft(personID: person.id, reason: kind, text: text), at: 0)
    }

    func postponeHousehold(_ kind: HouseholdKind, at date: Date = Date()) {
        // Preserve an existing request for help when postponing the next question.
        let help = state.household[kind.rawValue]?.needsHelp ?? false
        state.household[kind.rawValue] = HouseholdAnswer(date: date, needsHelp: help)
    }

    func addPerson(_ person: EverydayPerson) {
        guard !state.people.contains(where: { normalizedPhone($0.phone) == normalizedPhone(person.phone) }) else { return }
        state.people.append(person)
    }

    private func normalizedPhone(_ number: String) -> String { number.filter(\.isNumber) }
}
