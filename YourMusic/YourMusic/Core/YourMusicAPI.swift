import Foundation

enum YourMusicAPI {
    private static let client = APIClient.shared

    static func search(_ query: String, kinds: [CatalogKind], limit: Int = 20) async throws -> [CatalogSearchItem] {
        try await client.get("yourmusic/search", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "types", value: kinds.map(\.rawValue).joined(separator: ",")),
            URLQueryItem(name: "limit", value: String(limit))
        ])
    }

    static func artist(_ id: Int) async throws -> ArtistDetailsPayload { try await client.get("yourmusic/artists/\(id)") }
    static func album(_ id: Int) async throws -> AlbumDetailsPayload { try await client.get("yourmusic/albums/\(id)") }
    static func track(_ id: Int) async throws -> Track { try await client.get("yourmusic/tracks/\(id)") }

    static func library(kind: CatalogKind? = nil) async throws -> [LibraryItem] {
        let query = kind.map { [URLQueryItem(name: "type", value: $0.rawValue)] } ?? []
        return try await client.get("yourmusic/library", query: query)
    }

    static func save(kind: CatalogKind, id: Int) async throws {
        struct Body: Encodable { let itemType: String; let itemId: Int }
        let _: MutationResult = try await client.send("yourmusic/library", body: Body(itemType: kind.rawValue, itemId: id))
    }

    static func unsave(kind: CatalogKind, id: Int) async throws {
        let _: MutationResult = try await client.delete("yourmusic/library/\(kind.rawValue)/\(id)")
    }

    static func favorites() async throws -> [FavoriteArtist] { try await client.get("profiles/me/favorite-artists") }
    static func favoriteArtist(_ id: Int) async throws -> [FavoriteArtist] {
        struct Empty: Encodable {}
        return try await client.send("profiles/me/favorite-artists/\(id)", body: Empty())
    }
    static func unfavoriteArtist(_ id: Int) async throws -> [FavoriteArtist] {
        try await client.delete("profiles/me/favorite-artists/\(id)")
    }

    static func playlists() async throws -> [MusicPlaylist] { try await client.get("yourmusic/playlists") }
    static func createPlaylist(name: String, description: String?) async throws -> MusicPlaylist {
        struct Body: Encodable { let name: String; let description: String?; let isPublic = false }
        return try await client.send("yourmusic/playlists", body: Body(name: name, description: description))
    }
    static func playlistItems(_ id: Int) async throws -> [PlaylistItem] { try await client.get("yourmusic/playlists/\(id)/items") }
    static func add(trackID: Int, to playlistID: Int) async throws {
        struct Body: Encodable { let trackId: Int }
        let _: MutationResult = try await client.send("yourmusic/playlists/\(playlistID)/items", body: Body(trackId: trackID))
    }
    static func add(albumID: Int, to playlistID: Int) async throws -> AlbumPlaylistAddResult {
        struct Empty: Encodable {}
        return try await client.send(
            "yourmusic/playlists/\(playlistID)/albums/\(albumID)",
            body: Empty()
        )
    }
    static func removePlaylistItem(_ itemID: Int, playlistID: Int) async throws {
        let _: MutationResult = try await client.delete("yourmusic/playlists/\(playlistID)/items/\(itemID)")
    }

    static func ownership(albumID: Int? = nil) async throws -> [AlbumOwnership] {
        let query = albumID.map { [URLQueryItem(name: "albumId", value: String($0))] } ?? []
        return try await client.get("yourmusic/ownership/albums", query: query)
    }
    static func saveOwnership(albumID: Int, format: MediaFormat, note: String? = nil) async throws {
        struct Body: Encodable { let albumId: Int; let mediaFormat: String; let note: String? }
        let _: MutationResult = try await client.send("yourmusic/ownership/albums", body: Body(albumId: albumID, mediaFormat: format.rawValue, note: note))
    }
    static func removeOwnership(_ id: Int) async throws {
        let _: MutationResult = try await client.delete("yourmusic/ownership/albums/\(id)")
    }

    static func checklists() async throws -> [MusicChecklist] { try await client.get("yourmusic/checklists") }
    static func createChecklist(name: String, description: String?) async throws -> MusicChecklist {
        struct Body: Encodable { let name: String; let description: String? }
        return try await client.send("yourmusic/checklists", body: Body(name: name, description: description))
    }
    static func checklist(_ id: Int) async throws -> ChecklistPayload { try await client.get("yourmusic/checklists/\(id)") }
    static func deleteChecklist(_ id: Int) async throws {
        let _: MutationResult = try await client.delete("yourmusic/checklists/\(id)")
    }
    static func addChecklistItem(checklistID: Int, title: String, note: String? = nil) async throws {
        struct Body: Encodable { let itemType = "CUSTOM"; let title: String; let note: String? }
        let _: ChecklistCreateResult = try await client.send("yourmusic/checklists/\(checklistID)/items", body: Body(title: title, note: note))
    }
    static func setChecklistItem(checklistID: Int, itemID: Int, complete: Bool) async throws {
        struct Body: Encodable { let isComplete: Bool }
        let _: MutationResult = try await client.send("yourmusic/checklists/\(checklistID)/items/\(itemID)", method: "PATCH", body: Body(isComplete: complete))
    }

    static func playback(trackID: Int) async throws -> PlaybackResponse {
        struct Body: Encodable { let songId: Int; let mode = "VIDEO" }
        return try await client.send("music/playback/song", body: Body(songId: trackID))
    }

    static func playback(playlistID: Int, shuffled: Bool) async throws -> PlaylistPlaybackResponse {
        struct Body: Encodable {
            let mode = "VIDEO"
            let autoplay = true
            let shuffle: Bool
        }
        return try await client.send(
            "yourmusic/playlists/\(playlistID)/playback",
            body: Body(shuffle: shuffled)
        )
    }

    static func advancePlayback(sessionID: Int) async throws -> PlaylistPlaybackResponse {
        struct Empty: Encodable {}
        return try await client.send(
            "yourmusic/playback/\(sessionID)/advance",
            body: Empty()
        )
    }

    static func account() async throws -> AccountPayload {
        try await client.get("profiles/me/account")
    }

    static func requestEmailVerification(_ email: String) async throws {
        struct Body: Encodable { let email: String }
        let _: BasicResponse = try await client.raw(
            "profiles/me/account/email/request",
            body: Body(email: email),
            authenticated: true
        )
    }

    static func verifyEmail(_ email: String, code: String) async throws {
        struct Body: Encodable { let email: String; let code: String }
        let _: BasicResponse = try await client.raw(
            "profiles/me/account/email/verify",
            body: Body(email: email, code: code),
            authenticated: true
        )
    }

    static func setPassword(_ newPassword: String, currentPassword: String?) async throws {
        struct Body: Encodable { let newPassword: String; let currentPassword: String? }
        let _: BasicResponse = try await client.raw(
            "profiles/me/account/password",
            body: Body(newPassword: newPassword, currentPassword: currentPassword),
            authenticated: true
        )
    }
}

private struct ChecklistCreateResult: Decodable { let id: Int; let checklistId: Int }
