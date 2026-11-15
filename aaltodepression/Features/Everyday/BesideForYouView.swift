import SwiftUI

struct BesideForYouView: View {
    @State private var reachOut = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    action("Reach out", detail: "A little company, in your own words.", symbol: "bubble.left.and.bubble.right", color: EverydayStyle.mint) { reachOut = true }
                }.padding(20)
            }
            .background(EverydayStyle.paper).navigationTitle("For you")
            .sheet(isPresented: $reachOut) { EverydaySocialView() }
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
                .background(color, in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain).accessibilityIdentifier("for-you-reach-out")
    }
}
