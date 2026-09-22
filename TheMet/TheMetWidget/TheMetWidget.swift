import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
  func readObjects() -> [Object] {
    let archiveURL =
      FileManager.sharedContainerURL()
        .appendingPathComponent(
          "objects.json"
        )

    guard let data =
      try? Data(contentsOf: archiveURL),
      let objects =
        try? JSONDecoder().decode(
          [Object].self,
          from: data
        ),
      !objects.isEmpty
    else {
      return [
        Object.sample(
          isPublicDomain: true
        ),
        Object.sample(
          isPublicDomain: false
        )
      ]
    }

    return objects
  }

  func placeholder(
    in context: Context
  ) -> SimpleEntry {
    SimpleEntry(
      date: Date(),
      object:
        Object.sample(
          isPublicDomain: true
        )
    )
  }

  func getSnapshot(
    in context: Context,
    completion:
      @escaping (SimpleEntry) -> Void
  ) {
    let entry = SimpleEntry(
      date: Date(),
      object:
        Object.sample(
          isPublicDomain: false
        )
    )

    completion(entry)
  }

  func getTimeline(
    in context: Context,
    completion:
      @escaping (
        Timeline<SimpleEntry>
      ) -> Void
  ) {
    var entries: [SimpleEntry] = []

    let currentDate = Date()
    let interval = 2
    let objects = readObjects()

    for index in objects.indices {
      let entryDate =
        Calendar.current.date(
          byAdding: .second,
          value: index * interval,
          to: currentDate
        ) ?? currentDate

      let entry = SimpleEntry(
        date: entryDate,
        object: objects[index]
      )

      entries.append(entry)
    }

    let timeline = Timeline(
      entries: entries,
      policy: .atEnd
    )

    completion(timeline)
  }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let object: Object
}

struct DetailIndicatorView: View {
  let title: String

  var body: some View {
    HStack(
      alignment: .firstTextBaseline
    ) {
      Text(title)
      Spacer()

      Image(
        systemName:
          "doc.text.image.fill"
      )
    }
  }
}

struct TheMetWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    VStack {
      Text("The Met")
        .font(.headline)

      Divider()

      if !entry.object.isPublicDomain {
        WebIndicatorView(
          title: entry.object.title
        )
        .padding()
        .background(
          Color.metBackground
        )
        .foregroundStyle(.white)
      } else {
        DetailIndicatorView(
          title: entry.object.title
        )
        .padding()
        .background(
          Color.metForeground
        )
      }
    }
    .truncationMode(.middle)
    .fontWeight(.semibold)
    .widgetURL(
      URL(
        string:
          "themet://\(entry.object.objectID)"
      )
    )
  }
}

struct TheMetWidget: Widget {
  let kind = "TheMetWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: Provider()
    ) { entry in
      TheMetWidgetEntryView(
        entry: entry
      )
      .containerBackground(
        .fill.tertiary,
        for: .widget
      )
    }
    .configurationDisplayName(
      "The Met"
    )
    .description(
      """
      View objects from the \
      Metropolitan Museum.
      """
    )
    .supportedFamilies([
      .systemMedium,
      .systemLarge
    ])
  }
}

#Preview(as: .systemLarge) {
  TheMetWidget()
} timeline: {
  SimpleEntry(
    date: .now,
    object:
      Object.sample(
        isPublicDomain: true
      )
  )

  SimpleEntry(
    date: .now,
    object:
      Object.sample(
        isPublicDomain: false
      )
  )
}
