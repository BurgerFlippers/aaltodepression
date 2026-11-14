import Foundation

/// Everything the person can do, as plain changes to `PlannerState`. The store saves the result;
/// keeping the changes here makes them testable without the app.
extension PlannerState {
    nonisolated mutating func record(_ c: CheckIn) {
        checkIns[c.day.jdn] = c
    }

    /// Screen time for `day` (usually yesterday). A missing range (hours < 0) keeps an earlier one.
    nonisolated mutating func recordScreenTime(_ r: ScreenTimeReport, day: Day) {
        var report = r
        if report.hours < 0 { report.hours = screenTime[day.jdn]?.hours ?? -1 }
        if report.phoneInBed == nil { report.phoneInBed = screenTime[day.jdn]?.phoneInBed }
        screenTime[day.jdn] = report
    }

    /// The person's own answers as signals, so tracking and the rules read them like any other data.
    nonisolated func selfReportTable() -> FeatureTable {
        var t = FeatureTable()
        for (jdn, r) in screenTime {
            if r.hours >= 0 { t.set(F.screenTimeSelf, Day(jdn: jdn), r.hours) }
            if let b = r.phoneInBed { t.set(F.phoneInBed, Day(jdn: jdn), b ? 1 : 0) }
        }
        return t
    }

    /// "Did you get to the shop today?" Never creates a check-in.
    nonisolated mutating func answerGroceries(_ done: Bool, day: Day) {
        groceryAnswers[day.jdn] = done
    }

    nonisolated mutating func mark(_ item: PlanItem, _ status: ItemStatus, at: Date) {
        mark(id: item.id, pillar: item.pillar, status, at: at)
    }

    /// Marks by id, so a notification can tick a dose without building the day's plan first.
    nonisolated mutating func mark(id: String, pillar: Pillar, _ status: ItemStatus, at: Date) {
        var m = marks[id] ?? ItemMark(status: status, at: at)
        m.status = status
        m.at = at
        marks[id] = m
        guard pillar == .chores else { return }
        let parts = id.split(separator: "|").map(String.init)
        guard parts.count >= 3, let day = Int(parts[0]) else { return }
        let choreID = parts[2]
        if status == .done {
            choreDone[choreID] = max(choreDone[choreID] ?? Int.min, day)
        } else if choreDone[choreID] == day {
            // Undo: fall back to the latest other done day for this chore.
            choreDone[choreID] = marks.compactMap { k, v -> Int? in
                let p = k.split(separator: "|").map(String.init)
                guard p.count >= 3, p[1] == Pillar.chores.rawValue, p[2] == choreID, v.status == .done, let d = Int(p[0]), d != day else { return nil }
                return d
            }.max()
        }
    }

    /// "Make it smaller": one size down; the smallest size is never removed. Keeps any status.
    nonisolated mutating func shrink(_ item: PlanItem, at: Date) {
        guard let smaller = item.size.smaller else { return }
        var m = marks[item.id] ?? ItemMark(status: nil, at: at)
        m.size = smaller
        m.at = at
        marks[item.id] = m
    }

    nonisolated mutating func dismiss(_ card: Card, day: Day) {
        dismissedCards[card.id] = day.jdn
        if case .social = card { socialOfferedDays.insert(day.jdn) }
    }

    nonisolated mutating func markSafetyAsked(day: Day) {
        safetyAskedDays.insert(day.jdn)
    }

    /// Keeps only that the day was heavy (talk soon or more), never the answers.
    nonisolated mutating func recordSafetyOutcome(_ o: SafetyOutcome, day: Day) {
        if o != .noThoughts { heavySafetyDays.insert(day.jdn) }
    }

    /// Queues a suggestion to a contact. Outside 08–20 it waits as pending until the morning.
    /// With `askEachTime` it waits for `confirm`. A suggestion the person cancelled is never queued again.
    /// Nothing is really sent in the prototype.
    @discardableResult
    nonisolated mutating func queue(_ s: ContactSuggestion, now: Int, at: Date, simulateReply: Bool) -> OutgoingMessage? {
        if outbox.contains(where: { $0.id == s.id }) { return outbox.first { $0.id == s.id } }
        let inWindow = InterventionRules.sendWindow.contains(now)
        let auto = setup.helpConsent == .sendRightAway
        var msg = OutgoingMessage(id: s.id, day: s.day, createdAt: at, contactID: s.contact.id, contactName: s.contact.name,
                                  kind: s.kind, text: s.message, status: auto && inWindow ? .sent : .pending,
                                  confirmed: auto ? true : nil)
        if msg.status == .sent, simulateReply { msg.simulatedReply = MessageTemplates.simulatedReply(s.kind) }
        outbox.append(msg)
        return msg
    }

    /// The person tapped Send on a waiting message. Outside 08–20 it stays waiting, confirmed.
    nonisolated mutating func confirm(messageID: String, now: Int, simulateReply: Bool) {
        guard let i = outbox.firstIndex(where: { $0.id == messageID }), outbox[i].status == .pending else { return }
        outbox[i].confirmed = true
        guard InterventionRules.sendWindow.contains(now) else { return }
        outbox[i].status = .sent
        if simulateReply { outbox[i].simulatedReply = MessageTemplates.simulatedReply(outbox[i].kind) }
    }

    nonisolated mutating func cancel(messageID: String) {
        guard let i = outbox.firstIndex(where: { $0.id == messageID }), outbox[i].status != .replied else { return }
        outbox[i].status = .cancelled
    }

    /// The (simulated) contact answered. Ties a gold knot.
    nonisolated mutating func markReplied(messageID: String) {
        guard let i = outbox.firstIndex(where: { $0.id == messageID }), outbox[i].status == .sent else { return }
        outbox[i].status = .replied
        if outbox[i].simulatedReply == nil { outbox[i].simulatedReply = MessageTemplates.simulatedReply(outbox[i].kind) }
    }

    nonisolated mutating func acceptSocial(_ s: SocialSuggestion, today: Day) {
        socialOfferedDays.insert(today.jdn)
        guard !socialPlans.contains(where: { $0.id == s.id }) else { return }
        socialPlans.append(SocialPlan(id: s.id, day: s.suggestedDay, contactName: s.contact?.name, activity: s.activity))
    }

    nonisolated mutating func answerSocial(planID: String, met: Bool) {
        guard let i = socialPlans.firstIndex(where: { $0.id == planID }) else { return }
        socialPlans[i].met = met
    }

    /// Confirmed waiting messages go out once the window opens. A message still waiting the day
    /// after it was written is stale and is dropped rather than sent late.
    nonisolated mutating func releasePending(day: Day, now: Int, simulateReply: Bool) {
        for i in outbox.indices where outbox[i].status == .pending {
            if day - outbox[i].day > 1 { outbox[i].status = .cancelled; continue }
            guard outbox[i].confirmed == true, InterventionRules.sendWindow.contains(now) else { continue }
            outbox[i].status = .sent
            if simulateReply { outbox[i].simulatedReply = MessageTemplates.simulatedReply(outbox[i].kind) }
        }
    }

    /// Keeps the day's reward as it grows: threads and knots are only ever added.
    nonisolated mutating func keep(_ r: DayReward) {
        guard let old = rewards[r.day.jdn] else { rewards[r.day.jdn] = r; return }
        let star = old.star || r.star
        let knots = max(old.goldKnots, r.goldKnots)
        rewards[r.day.jdn] = DayReward(day: r.day, threads: old.threads.union(r.threads), checkedIn: old.checkedIn || r.checkedIn,
                                       star: star, goldKnots: knots, message: r.message ?? old.message)
    }
}
