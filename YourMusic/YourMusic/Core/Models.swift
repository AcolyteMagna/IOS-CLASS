import Foundation

struct DataEnvelope<Value: Decodable>: Decodable {
    let ok: Bool
    let data: Value
}

struct ErrorEnvelope: Decodable {
    let ok: Bool?
    let error: String?
    let details: JSONValue?
}

enum JSONValue: Decodable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let result = try? value.decode(Bool.self) { self = .bool(result) }
        else if let result = try? value.decode(Double.self) { self = .number(result) }
        else if let result = try? value.decode(String.self) { self = .string(result) }
        else if let result = try? value.decode([String: JSONValue].self) { self = .object(result) }
        else { self = .array(try value.decode([JSONValue].self)) }
    }
}

struct OvertureUser: Codable, Identifiable {
    let id: Int
    let lastfmUsername: String
    let overtureUsername: String?

    enum CodingKeys: String, CodingKey {
        case id
        case lastfmUsername = "lastfm_username"
        case overtureUsername = "overture_username"
    }

    var displayName: String { overtureUsername ?? lastfmUsername }
}

struct AuthSessionResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: OvertureUser?
    let requiresTwoFactor: Bool?
    let challengeToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken, refreshToken, user, challengeToken, requiresTwoFactor
    }
}

struct LastFmStartResponse: Decodable {
    let ok: Bool
    let authURL: String

    enum CodingKeys: String, CodingKey {
        case ok
        case authURL = "auth_url"
    }
}

struct AccountPayload: Decodable {
    let security: AccountSecurity
}

struct AccountSecurity: Decodable {
    let email: String?
    let emailVerifiedAt: String?
    let hasPassword: Bool
    let emailDeliveryConfigured: Bool
}

struct BasicResponse: Decodable {
    let ok: Bool
}

enum CatalogKind: String, Codable, CaseIterable, Identifiable {
    case artist = "ARTIST"
    case album = "ALBUM"
    case track = "TRACK"

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .artist: "person.wave.2"
        case .album: "square.stack"
        case .track: "music.note"
        }
    }
}

struct CatalogSearchItem: Codable, Identifiable, Hashable {
    let kind: CatalogKind
    let id: Int
    let title: String
    let subtitle: String?
    let imageUrl: String?
    let artistId: Int?
    let artistName: String?
    let albumId: Int?
    let albumName: String?
    let durationMs: Int?
    let releaseDate: String?
}

struct ArtistDetailsPayload: Decodable {
    let artist: Artist
    let albums: [AlbumSummary]
}

struct Artist: Codable, Identifiable {
    let id: Int
    let mbArtistId: String
    let name: String
    let genre: String?
    let imageUrl: String?
    let bio: String?
    let formedYear: Int?
    let originCountry: String?
    let spotifyUrl: String?
    let lastfmUrl: String?
}

struct AlbumSummary: Codable, Identifiable, Hashable {
    let id: Int
    let mbReleaseGroupId: String
    let name: String
    let releaseDate: String?
    let albumType: String?
    let coverUrl: String?
    let trackCount: Int
}

struct AlbumDetailsPayload: Decodable {
    let album: AlbumDetails
    let tracks: [Track]
}

struct AlbumDetails: Codable, Identifiable {
    let id: Int
    let mbReleaseGroupId: String
    let name: String
    let releaseDate: String?
    let albumType: String?
    let coverUrl: String?
    let artistId: Int?
    let artistName: String?
}

struct Track: Codable, Identifiable, Hashable {
    let id: Int
    let mbRecordingId: String
    let name: String
    let durationMs: Int?
    let discNumber: Int?
    let trackNumber: Int?
    let isLive: Bool?
    let isRemix: Bool?
    let artistId: Int
    let artistName: String
    var albumId: Int?
    var albumName: String?
    var coverUrl: String?
}

struct LibraryItem: Codable, Identifiable {
    let id: Int
    let kind: CatalogKind
    let catalogItemId: Int
    let savedAt: String
    let title: String
    let subtitle: String?
    let imageUrl: String?
}

struct MusicPlaylist: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let isPublic: Bool
    let itemCount: Int
    let createdAt: String?
    let updatedAt: String?
}

struct PlaylistItem: Codable, Identifiable {
    let id: Int
    let trackId: Int
    let position: Int
    let trackName: String
    let durationMs: Int?
    let artistId: Int
    let artistName: String
    let albumId: Int
    let albumName: String
    let coverUrl: String?
}

enum MediaFormat: String, Codable, CaseIterable, Identifiable {
    case vinyl = "VINYL"
    case cd = "CD"
    case cassette = "CASSETTE"
    case digital = "DIGITAL"
    case streaming = "STREAMING"
    case other = "OTHER"

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .vinyl: "record.circle"
        case .cd: "opticaldisc"
        case .cassette: "radio"
        case .digital: "arrow.down.circle"
        case .streaming: "dot.radiowaves.left.and.right"
        case .other: "archivebox"
        }
    }
}

struct AlbumOwnership: Codable, Identifiable {
    let id: Int
    let albumId: Int
    let mediaFormat: MediaFormat
    let note: String?
    let createdAt: String
    let albumName: String
    let coverUrl: String?
    let artistId: Int?
    let artistName: String?
}

struct MusicChecklist: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let itemCount: Int
    let completedCount: Int
    var progress: Double { itemCount == 0 ? 0 : Double(completedCount) / Double(itemCount) }
}

struct ChecklistPayload: Decodable {
    let checklist: ChecklistHeader
    let items: [ChecklistItem]
}

struct ChecklistHeader: Decodable, Identifiable {
    let id: Int
    let name: String
    let description: String?
}

struct ChecklistItem: Codable, Identifiable {
    let id: Int
    let itemType: String
    let catalogItemId: Int?
    let title: String
    let note: String?
    let isComplete: Bool
    let position: Int
    let completedAt: String?
}

struct FavoriteArtist: Decodable, Identifiable {
    let artistId: Int
    let artistName: String
    var id: Int { artistId }
}

struct MutationResult: Decodable {
    let saved: Bool?
    let added: Bool?
    let removed: Bool?
    let deleted: Bool?
    let updated: Bool?
}

struct AlbumPlaylistAddResult: Decodable {
    let added: Bool
    let playlistId: Int
    let albumId: Int
    let addedCount: Int
    let skippedCount: Int
    let trackCount: Int
}

struct PlaybackResponse: Decodable {
    let playbackSessionId: Int
    let songId: Int?
    let youtubeVideoId: String?
    let youtubeUrl: String?
    let embedUrl: String?
    let title: String?
    let channelName: String?
    let status: String
}

struct PlaybackQueueItem: Decodable {
    let songId: Int
    let trackTitle: String?
    let artistName: String?
    let status: String
    let youtubeVideoId: String?
    let youtubeUrl: String?
    let embedUrl: String?
    let channelName: String?
}

struct PlaylistPlaybackResponse: Decodable {
    let playbackSessionId: Int
    let sourceType: String
    let sourceRefId: Int?
    let mode: String
    let status: String
    let autoplay: Bool
    let currentSongId: Int?
    let currentIndex: Int?
    let currentYoutubeVideoId: String?
    let queue: [PlaybackQueueItem]

    var currentItem: PlaybackQueueItem? {
        guard let currentIndex, queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }
}
