import SwiftUI

struct LibraryView: View {
    @State private var selectedKind: CatalogKind = .artist
    @State private var items: [LibraryItem] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    EditorialTitle(eyebrow: "Saved", title: "Your library", subtitle: "Music worth returning to.")
                    Picker("Library section", selection: $selectedKind) {
                        ForEach(CatalogKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
                    } else if items.isEmpty {
                        ContentUnavailableView(
                            "Nothing saved yet",
                            systemImage: selectedKind.icon,
                            description: Text("Search the Overture catalog and add something you love.")
                        )
                    } else {
                        ForEach(items) { item in
                            NavigationLink {
                                LibraryDestination(item: item)
                            } label: {
                                HStack(spacing: 14) {
                                    ArtworkView(url: item.imageUrl, size: 62)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title).font(.headline)
                                        Text(item.subtitle ?? item.kind.label).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Menu {
                                        Button(role: .destructive) {
                                            Task {
                                                try? await YourMusicAPI.unsave(kind: item.kind, id: item.catalogItemId)
                                                await load()
                                            }
                                        } label: { Label("Remove", systemImage: "trash") }
                                    } label: { Image(systemName: "ellipsis") }
                                }
                                .foregroundStyle(YMColor.ink)
                                .ymCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .task(id: selectedKind) { await load() }
        .refreshable { await load() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load() async {
        isLoading = true
        items = (try? await YourMusicAPI.library(kind: selectedKind)) ?? []
        isLoading = false
    }
}

private struct LibraryDestination: View {
    let item: LibraryItem

    @ViewBuilder
    var body: some View {
        switch item.kind {
        case .artist: ArtistDetailView(artistID: item.catalogItemId)
        case .album: AlbumDetailView(albumID: item.catalogItemId)
        case .track: TrackDetailView(trackID: item.catalogItemId)
        }
    }
}
