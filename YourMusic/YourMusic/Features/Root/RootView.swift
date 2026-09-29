import SwiftUI

struct RootView: View {
    @EnvironmentObject private var player: PlayerStore

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                NavigationStack { DiscoverView() }
                    .tabItem { Label("Discover", systemImage: "sparkle.magnifyingglass") }
                NavigationStack { LibraryView() }
                    .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                NavigationStack { PlaylistsView() }
                    .tabItem { Label("Playlists", systemImage: "music.note.list") }
                NavigationStack { CollectionHubView() }
                    .tabItem { Label("Collection", systemImage: "record.circle") }
                NavigationStack { ProfileView() }
                    .tabItem { Label("You", systemImage: "person.crop.circle") }
            }
            .tint(YMColor.cobalt)

            if player.playback != nil {
                PlayerView()
                    .environmentObject(player)
                    .zIndex(100)
            }
        }
    }
}
