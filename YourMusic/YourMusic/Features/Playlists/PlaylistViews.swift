import SwiftUI

struct PlaylistsView: View {
    @State private var playlists: [MusicPlaylist] = []
    @State private var showingCreate = false

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom) {
                        EditorialTitle(eyebrow: "Mixtapes", title: "Playlists", subtitle: "Sequence a mood, a year, or a memory.")
                        Button { showingCreate = true } label: { Image(systemName: "plus") }
                            .buttonStyle(PrimaryButtonStyle())
                    }

                    if playlists.isEmpty {
                        ContentUnavailableView("No playlists", systemImage: "music.note.list", description: Text("Create your first playlist to begin."))
                    } else {
                        ForEach(playlists) { playlist in
                            NavigationLink {
                                PlaylistDetailView(playlist: playlist)
                            } label: {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16).fill(YMColor.cobalt)
                                        Image(systemName: "music.note.list").font(.title).foregroundStyle(.white)
                                    }
                                    .frame(width: 68, height: 68)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name).font(.system(.headline, design: .rounded, weight: .bold))
                                        Text("\(playlist.itemCount) songs").font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
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
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showingCreate, onDismiss: { Task { await load() } }) { CreatePlaylistSheet() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load() async { playlists = (try? await YourMusicAPI.playlists()) ?? [] }
}

struct PlaylistDetailView: View {
    @EnvironmentObject private var player: PlayerStore
    let playlist: MusicPlaylist
    @State private var items: [PlaylistItem] = []
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    EditorialTitle(eyebrow: "Playlist", title: playlist.name, subtitle: playlist.description)
                    HStack(spacing: 12) {
                        Button {
                            player.play(playlistID: playlist.id, shuffled: false)
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button {
                            player.play(playlistID: playlist.id, shuffled: true)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .disabled(items.isEmpty || player.isLoading)

                    if let displayedError = errorMessage ?? player.errorMessage {
                        Text(displayedError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if items.isEmpty {
                        ContentUnavailableView(
                            "Empty playlist",
                            systemImage: "music.note.list",
                            description: Text("Add songs or a complete album to start listening.")
                        )
                    }
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            ArtworkView(url: item.coverUrl, size: 58)
                            VStack(alignment: .leading) {
                                Text(item.trackName).font(.headline)
                                Text(item.artistName).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { player.play(trackID: item.trackId) } label: { Image(systemName: "play.circle.fill").font(.title2) }
                            Button(role: .destructive) {
                                Task {
                                    try? await YourMusicAPI.removePlaylistItem(item.id, playlistID: playlist.id)
                                    await load()
                                }
                            } label: { Image(systemName: "minus.circle") }
                        }
                        .ymCard()
                    }
                }
                .padding(20)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            items = try await YourMusicAPI.playlistItems(playlist.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AddToPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let trackID: Int
    let trackName: String
    @State private var playlists: [MusicPlaylist] = []

    var body: some View {
        NavigationStack {
            List(playlists) { playlist in
                Button {
                    Task {
                        try? await YourMusicAPI.add(trackID: trackID, to: playlist.id)
                        dismiss()
                    }
                } label: {
                    Label(playlist.name, systemImage: "music.note.list")
                }
            }
            .navigationTitle("Add \(trackName)")
            .navigationBarTitleDisplayMode(.inline)
            .task { playlists = (try? await YourMusicAPI.playlists()) ?? [] }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct AddAlbumToPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let albumID: Int
    let albumName: String
    let trackCount: Int
    @State private var playlists: [MusicPlaylist] = []
    @State private var submittingPlaylistID: Int?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                ForEach(playlists) { playlist in
                    Button {
                        submittingPlaylistID = playlist.id
                        errorMessage = nil
                        Task {
                            do {
                                _ = try await YourMusicAPI.add(albumID: albumID, to: playlist.id)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                submittingPlaylistID = nil
                            }
                        }
                    } label: {
                        HStack {
                            Label(playlist.name, systemImage: "music.note.list")
                            Spacer()
                            if submittingPlaylistID == playlist.id { ProgressView() }
                        }
                    }
                    .disabled(submittingPlaylistID != nil)
                }
            }
            .navigationTitle("Add \(albumName)")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("Adds up to \(trackCount) songs and skips songs already in the playlist.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
            .task { playlists = (try? await YourMusicAPI.playlists()) ?? [] }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct CreatePlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Playlist name", text: $name)
                TextField("Description (optional)", text: $description, axis: .vertical)
            }
            .navigationTitle("New playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            _ = try? await YourMusicAPI.createPlaylist(name: name, description: description.isEmpty ? nil : description)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
