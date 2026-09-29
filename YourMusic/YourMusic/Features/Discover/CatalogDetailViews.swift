import SwiftUI

struct ArtistDetailView: View {
    let artistID: Int
    @State private var payload: ArtistDetailsPayload?
    @State private var isFavorite = false
    @State private var isSaved = false
    @State private var albumQuery = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let payload {
                        HStack(alignment: .bottom, spacing: 18) {
                            ArtworkView(url: payload.artist.imageUrl, size: 132, cornerRadius: 26)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(payload.artist.genre?.uppercased() ?? "ARTIST")
                                    .font(.caption.weight(.black)).tracking(2)
                                    .foregroundStyle(YMColor.cobalt)
                                Text(payload.artist.name)
                                    .font(.system(size: 38, weight: .black, design: .serif))
                                if let origin = payload.artist.originCountry { Text(origin).foregroundStyle(.secondary) }
                            }
                        }

                        HStack {
                            Button { toggleFavorite() } label: {
                                Label(isFavorite ? "Favorited" : "Favorite", systemImage: isFavorite ? "heart.fill" : "heart")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            Button { toggleSaved() } label: {
                                Label(isSaved ? "In library" : "Save", systemImage: isSaved ? "checkmark" : "plus")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }

                        if let bio = payload.artist.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.system(.body, design: .rounded))
                                .lineSpacing(5)
                                .ymCard()
                        }

                        Text("Discography")
                            .font(.system(.title, design: .serif, weight: .bold))
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search this discography", text: $albumQuery)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            if !albumQuery.isEmpty {
                                Button { albumQuery = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Clear album search")
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        if filteredAlbums.isEmpty {
                            ContentUnavailableView.search(text: albumQuery)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 16)], spacing: 20) {
                                ForEach(filteredAlbums) { album in
                                    NavigationLink { AlbumDetailView(albumID: album.id) } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ArtworkView(url: album.coverUrl, size: 150, cornerRadius: 18)
                                                .frame(maxWidth: .infinity)
                                            Text(album.name).font(.headline).lineLimit(2)
                                            Text("\(album.trackCount) tracks")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        .foregroundStyle(YMColor.ink)
                                    }
                                }
                            }
                        }
                    } else if let errorMessage {
                        ContentUnavailableView("Artist unavailable", systemImage: "person.crop.circle.badge.exclamationmark", description: Text(errorMessage))
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                    }
                }
                .padding(20)
            }
        }
        .task { await load() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredAlbums: [AlbumSummary] {
        let albums = payload?.albums.filter { $0.trackCount > 0 } ?? []
        let query = albumQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return albums }
        return albums.filter {
            $0.name.localizedStandardContains(query) ||
                ($0.releaseDate?.localizedStandardContains(query) ?? false)
        }
    }

    private func load() async {
        do {
            async let details = YourMusicAPI.artist(artistID)
            async let favorites = YourMusicAPI.favorites()
            async let library = YourMusicAPI.library(kind: .artist)
            payload = try await details
            let favoriteValues = try await favorites
            let libraryValues = try await library
            isFavorite = favoriteValues.contains { $0.artistId == artistID }
            isSaved = libraryValues.contains { $0.catalogItemId == artistID }
        } catch { errorMessage = error.localizedDescription }
    }

    private func toggleFavorite() {
        Task {
            do {
                if isFavorite {
                    _ = try await YourMusicAPI.unfavoriteArtist(artistID)
                } else {
                    _ = try await YourMusicAPI.favoriteArtist(artistID)
                }
                isFavorite.toggle()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func toggleSaved() {
        Task {
            do {
                if isSaved { try await YourMusicAPI.unsave(kind: .artist, id: artistID) }
                else { try await YourMusicAPI.save(kind: .artist, id: artistID) }
                isSaved.toggle()
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

struct AlbumDetailView: View {
    @EnvironmentObject private var player: PlayerStore
    let albumID: Int
    @State private var payload: AlbumDetailsPayload?
    @State private var ownedFormats: [AlbumOwnership] = []
    @State private var isSaved = false
    @State private var selectedFormat: MediaFormat = .vinyl
    @State private var showingPlaylistsForTrack: Track?
    @State private var showingPlaylistsForAlbum = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let payload {
                        HStack(alignment: .bottom, spacing: 18) {
                            ArtworkView(url: payload.album.coverUrl, size: 145, cornerRadius: 22)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(payload.album.albumType?.uppercased() ?? "ALBUM")
                                    .font(.caption.weight(.black)).tracking(2).foregroundStyle(YMColor.cobalt)
                                Text(payload.album.name)
                                    .font(.system(size: 34, weight: .black, design: .serif))
                                Text(payload.album.artistName ?? "Unknown artist").foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            Task {
                                if isSaved { try? await YourMusicAPI.unsave(kind: .album, id: albumID) }
                                else { try? await YourMusicAPI.save(kind: .album, id: albumID) }
                                isSaved.toggle()
                            }
                        } label: {
                            Label(isSaved ? "Saved to library" : "Save album", systemImage: isSaved ? "checkmark" : "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button {
                            showingPlaylistsForAlbum = true
                        } label: {
                            Label("Add album to playlist", systemImage: "text.badge.plus")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(payload.tracks.isEmpty)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("I own this on")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                            HStack {
                                Picker("Format", selection: $selectedFormat) {
                                    ForEach(MediaFormat.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                                }
                                Button("Add") {
                                    Task {
                                        try? await YourMusicAPI.saveOwnership(albumID: albumID, format: selectedFormat)
                                        ownedFormats = (try? await YourMusicAPI.ownership(albumID: albumID)) ?? []
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(ownedFormats) { entry in
                                        Label(entry.mediaFormat.label, systemImage: entry.mediaFormat.icon)
                                            .font(.caption.weight(.bold))
                                            .padding(9)
                                            .background(YMColor.mint.opacity(0.48))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .ymCard()

                        Text("Track list")
                            .font(.system(.title, design: .serif, weight: .bold))
                        ForEach(Array(payload.tracks.enumerated()), id: \.element.id) { index, track in
                            HStack(spacing: 12) {
                                Text(String(track.trackNumber ?? index + 1))
                                    .font(.system(.caption, design: .monospaced, weight: .bold))
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(track.name).font(.headline)
                                    if let duration = track.durationMs { Text(duration.durationLabel).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Menu {
                                    Button { player.play(trackID: track.id) } label: { Label("Play", systemImage: "play") }
                                    Button { showingPlaylistsForTrack = track } label: { Label("Add to playlist", systemImage: "text.badge.plus") }
                                    Button { Task { try? await YourMusicAPI.save(kind: .track, id: track.id) } } label: { Label("Save song", systemImage: "plus") }
                                } label: {
                                    Image(systemName: "ellipsis.circle").font(.title3)
                                }
                            }
                            .padding(.vertical, 8)
                            Divider()
                        }
                    } else if let errorMessage {
                        ContentUnavailableView("Album unavailable", systemImage: "opticaldisc", description: Text(errorMessage))
                    } else { ProgressView().frame(maxWidth: .infinity).padding(.top, 80) }
                }
                .padding(20)
            }
        }
        .task { await load() }
        .sheet(item: $showingPlaylistsForTrack) { track in
            AddToPlaylistSheet(trackID: track.id, trackName: track.name)
        }
        .sheet(isPresented: $showingPlaylistsForAlbum) {
            if let payload {
                AddAlbumToPlaylistSheet(
                    albumID: albumID,
                    albumName: payload.album.name,
                    trackCount: payload.tracks.count
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load() async {
        do {
            async let album = YourMusicAPI.album(albumID)
            async let formats = YourMusicAPI.ownership(albumID: albumID)
            async let library = YourMusicAPI.library(kind: .album)
            payload = try await album
            ownedFormats = try await formats
            let libraryValues = try await library
            isSaved = libraryValues.contains { $0.catalogItemId == albumID }
        } catch { errorMessage = error.localizedDescription }
    }
}

struct TrackDetailView: View {
    @EnvironmentObject private var player: PlayerStore
    let trackID: Int
    @State private var track: Track?
    @State private var showingPlaylists = false

    var body: some View {
        ZStack {
            YourMusicBackground()
            VStack(spacing: 24) {
                Spacer()
                ArtworkView(url: track?.coverUrl, size: 260, cornerRadius: 32)
                    .shadow(color: .black.opacity(0.18), radius: 22, y: 14)
                Text(track?.name ?? "Loading...")
                    .font(.system(size: 34, weight: .black, design: .serif))
                    .multilineTextAlignment(.center)
                Text(track?.artistName ?? "")
                    .font(.title3).foregroundStyle(.secondary)
                HStack {
                    Button { player.play(trackID: trackID) } label: { Label("Play", systemImage: "play.fill") }
                    Button { Task { try? await YourMusicAPI.save(kind: .track, id: trackID) } } label: { Label("Save", systemImage: "plus") }
                    Button { showingPlaylists = true } label: { Label("Playlist", systemImage: "music.note.list") }
                }
                .buttonStyle(PrimaryButtonStyle())
                Spacer()
            }
            .padding(24)
        }
        .task { track = try? await YourMusicAPI.track(trackID) }
        .sheet(isPresented: $showingPlaylists) {
            AddToPlaylistSheet(trackID: trackID, trackName: track?.name ?? "Song")
        }
    }
}
