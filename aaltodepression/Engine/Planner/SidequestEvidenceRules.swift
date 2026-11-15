import Foundation

/// Daily aggregate changes are supporting clues, never proof of a particular action.
nonisolated enum SidequestEvidenceRules {
    static func description(offer: SidequestDay?, on day: Day, readings: FeatureTable) -> String {
        guard let offer, let quest = offer.selected, let selectedAt = offer.startedAt,
              Day(selectedAt) == day else { return "No activity evidence available." }
        let key: String
        if quest.id == "morning-light", !offer.useSmaller { key = F.daylightMin }
        else if quest.category == .movement { key = F.steps }
        else if quest.category == .nutrition { key = F.dietaryEnergy }
        else { return "This task cannot be verified from the available Health readings." }
        guard let before = offer.selectionReadings?[key], before.isFinite,
              let after = readings.value(key, day), after > before else {
            return "No additional related activity recorded yet. Completion remains unverified."
        }
        switch key {
        case F.steps: return "The recorded step total increased since selection. This supports movement, not completion of this exact task."
        case F.daylightMin: return "The recorded daylight total increased since selection. The task remains unverified."
        default: return "More nutrition was logged for this day since selection. This does not confirm the task or when food was eaten."
        }
    }
}
