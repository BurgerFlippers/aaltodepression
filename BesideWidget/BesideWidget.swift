import SwiftUI
import WidgetKit

struct SidequestEntry: TimelineEntry {
    let date: Date
    var task: BesideWidgetTask?
}

struct SidequestProvider: TimelineProvider {
    func placeholder(in context: Context) -> SidequestEntry { SidequestEntry(date: .now, task: nil) }
    func getSnapshot(in context: Context, completion: @escaping (SidequestEntry) -> Void) {
        completion(SidequestEntry(date: .now, task: BesideWidgetStore.task()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SidequestEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        let entry = SidequestEntry(date: now, task: BesideWidgetStore.task())
        completion(Timeline(entries: [entry, SidequestEntry(date: midnight, task: nil)], policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

struct SidequestWidgetView: View {
    let entry: SidequestEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mind").font(.headline)
                Spacer()
                Image("BesideMark").resizable().scaledToFit().saturation(0).colorMultiply(Color(red: 0.76, green: 0.65, blue: 0.97)).frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if let task = entry.task {
                Text(task.title).font(.headline).lineLimit(4).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Text("One small step is enough.").font(.caption)

            } else {
                Text("One small step for today.").font(.headline)
                Spacer(minLength: 0)
                Link("Choose your task", destination: URL(string: "beside://sidequest")!).font(.subheadline.bold())
            }
        }
        .foregroundStyle(.white)
        .tint(Color(red: 0.76, green: 0.65, blue: 0.97))
        .environment(\.colorScheme, .dark)
        .containerBackground(background, for: .widget)
        .widgetURL(URL(string: "beside://sidequest"))
        .privacySensitive()
    }
    private var background: Color { Color(red: 0.20, green: 0.15, blue: 0.28) }
}

@main
struct BesideSidequestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BesideSidequest", provider: SidequestProvider()) { SidequestWidgetView(entry: $0) }
            .configurationDisplayName("Your small step")
            .description("Keep your chosen task close. One choice is enough.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
