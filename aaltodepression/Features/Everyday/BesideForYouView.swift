import SwiftUI

struct BesideForYouView: View {
    @State private var checkIn = false
    @State private var reachOut = false
    @State private var support = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    action("Check in", detail: "A moment to notice how you feel.", symbol: "heart.text.clipboard", color: BesideQuestStyle.cardColor(0)) { checkIn = true }
                    action("Reach out", detail: "A little company, in your own words.", symbol: "bubble.left.and.bubble.right", color: BesideQuestStyle.cardColor(0)) { reachOut = true }
                    action("Get support", detail: "Call someone you know, or find urgent help.", symbol: "person.2", color: BesideQuestStyle.cardColor(0)) { support = true }
                }.padding(20)
            }
            .background(EverydayStyle.paper).mindHeader("For you")
            .sheet(isPresented: $checkIn) { BesideCheckInView() }
            .sheet(isPresented: $reachOut) { EverydaySocialView() }
            .sheet(isPresented: $support) { EverydayHelpView() }
        }
    }
    private func action(_ title: String, detail: String, symbol: String, color: Color, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 18) {
                Image(systemName: symbol).font(.title).foregroundStyle(EverydayStyle.accent).frame(width: 42)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.title3.bold())
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
            }.padding(22).frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
                .background(color, in: RoundedRectangle(cornerRadius: EverydayStyle.cardRadius, style: .continuous))
        }.buttonStyle(.plain).accessibilityIdentifier(title == "Check in" ? "for-you-check-in" : title == "Reach out" ? "for-you-reach-out" : "for-you-support")
    }
}
