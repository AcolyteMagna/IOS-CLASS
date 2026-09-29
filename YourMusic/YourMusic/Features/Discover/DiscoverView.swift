import SwiftUI

private enum SearchScope: String, CaseIterable, Identifiable {
    case all = "All"
    case artists = "Artists"
    case albums = "Albums"
    case tracks = "Songs"

    var id: String { rawValue }
    var kinds: [CatalogKind] {
        switch self {
        case .all: CatalogKind.allCases
        case .artists: [.artist]
        case .albums: [.album]
        case .tracks: [.track]
        }
    }
}

struct DiscoverView: View {
    @State private var query = ""
    @State private var scope: SearchScope = .all
    @State private var results: [CatalogSearchItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    EditorialTitle(
                        eyebrow: "Overture catalog",
                        title: "Find your next obsession.",
                        subtitle: "Artists, albums, and songs from one living music archive."
                    )

                    Picker("Search category", selection: $scope) {
                        ForEach(SearchScope.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DiscoveryPrompt()
                    } else if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 50)
                    } else if let errorMessage {
                        ContentUnavailableView("Search failed", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                    } else if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                    } else {
                        ForEach(results) { item in
                            NavigationLink {
                                CatalogDestinationView(item: item)
                            } label: {
                                SearchResultRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .searchable(text: $query, prompt: "Search music")
        .task(id: "\(query)|\(scope.rawValue)") {
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    results = []
                    return
                }
                isLoading = true
                errorMessage = nil
                results = try await YourMusicAPI.search(trimmed, kinds: scope.kinds)
                isLoading = false
            } catch is CancellationError {
                return
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DiscoveryPrompt: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(YMColor.orange)
                Spacer()
                Text("01")
                    .font(.system(size: 48, weight: .black, design: .serif))
                    .foregroundStyle(YMColor.ink.opacity(0.12))
            }
            Text("Search Elton John, Honky Château, or Rocket Man.")
                .font(.system(.title2, design: .serif, weight: .bold))
            Text("Save anything to your library, collect an album in every format, or start a listening checklist.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(YMColor.ink.opacity(0.62))
        }
        .ymCard()
    }
}

struct SearchResultRow: View {
    let item: CatalogSearchItem

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(url: item.imageUrl, size: 66)
            VStack(alignment: .leading, spacing: 4) {
                Label(item.kind.label, systemImage: item.kind.icon)
                    .font(.system(.caption2, design: .rounded, weight: .black))
                    .textCase(.uppercase)
                    .foregroundStyle(YMColor.cobalt)
                Text(item.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(YMColor.ink)
                    .lineLimit(2)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(YMColor.ink.opacity(0.58))
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .foregroundStyle(YMColor.orange)
        }
        .ymCard()
    }
}

private struct CatalogDestinationView: View {
    let item: CatalogSearchItem

    @ViewBuilder
    var body: some View {
        switch item.kind {
        case .artist: ArtistDetailView(artistID: item.id)
        case .album: AlbumDetailView(albumID: item.id)
        case .track: TrackDetailView(trackID: item.id)
        }
    }
}
