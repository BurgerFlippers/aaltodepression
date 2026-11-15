import Foundation
import WidgetKit

extension BesidePresentation {
    /// Only the live day's chosen task is exported; demo overrides never enter the widget.
    func syncSidequestWidget() {
        let today = Day(Date())
        let planner = liveBackend.planner
        guard planner.currentDay == today else { return }
        // Retire legacy manual-completion receipts without applying them.
        BesideWidgetStore.clearCompletion()
        let snapshot: BesideWidgetTask?
        if let offer = planner.state.sidequests[today.jdn], let selected = offer.selected {
            snapshot = BesideWidgetTask(date: today.start(), day: today.jdn, taskID: selected.id,
                title: BesideQuestStyle.brief(selected, smaller: offer.useSmaller), category: selected.category.rawValue, minutes: (offer.useSmaller ? selected.smaller : selected.regular).minutes,
                smaller: offer.useSmaller, completed: offer.completedAt != nil)
        } else { snapshot = nil }
        if BesideWidgetStore.task() != snapshot, BesideWidgetStore.publish(snapshot) {
            WidgetCenter.shared.reloadTimelines(ofKind: "BesideSidequest")
        }
    }
}
