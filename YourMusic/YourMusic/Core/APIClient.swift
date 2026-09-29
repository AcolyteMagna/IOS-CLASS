import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The API address is invalid."
        case .invalidResponse: "The server returned an invalid response."
        case .unauthorized: "Your session expired. Please sign in again."
        case .server(let message): message
        case .decoding: "The app could not read the server response."
        }
    }
}

private struct RefreshBody: Encodable { let refreshToken: String }

actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private var accessToken: String?
    private var refreshToken: String?
    private var refreshTask: Task<Void, Error>?

    let deviceID: String

    init() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "OVERTURE_API_BASE_URL") as? String
        self.baseURL = URL(string: configured ?? "https://api.overturegame.com/api")!
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
        if let existing = UserDefaults.standard.string(forKey: "yourmusic.device-id") {
            self.deviceID = existing
        } else {
            let generated = UUID().uuidString
            UserDefaults.standard.set(generated, forKey: "yourmusic.device-id")
            self.deviceID = generated
        }
    }

    func restoreTokens() -> Bool {
        accessToken = KeychainStore.get("access-token")
        refreshToken = KeychainStore.get("refresh-token")
        return accessToken != nil && refreshToken != nil
    }

    func setSession(accessToken: String, refreshToken: String) throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        try KeychainStore.set(accessToken, for: "access-token")
        try KeychainStore.set(refreshToken, for: "refresh-token")
    }

    func clearSession() {
        accessToken = nil
        refreshToken = nil
        KeychainStore.remove("access-token")
        KeychainStore.remove("refresh-token")
    }

    func raw<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String = "POST",
        body: Body,
        authenticated: Bool = false
    ) async throws -> Response {
        let data = try JSONEncoder().encode(body)
        return try await perform(path, method: method, query: [], body: data, authenticated: authenticated, retrying: false)
    }

    func rawGet<Response: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Response {
        try await perform(path, method: "GET", query: query, body: nil, authenticated: false, retrying: false)
    }

    func get<Value: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Value {
        let envelope: DataEnvelope<Value> = try await perform(path, method: "GET", query: query, body: nil, authenticated: true, retrying: false)
        return envelope.data
    }

    func send<Value: Decodable, Body: Encodable>(
        _ path: String,
        method: String = "POST",
        body: Body
    ) async throws -> Value {
        let bodyData = try JSONEncoder().encode(body)
        let envelope: DataEnvelope<Value> = try await perform(path, method: method, query: [], body: bodyData, authenticated: true, retrying: false)
        return envelope.data
    }

    func delete<Value: Decodable>(_ path: String) async throws -> Value {
        let envelope: DataEnvelope<Value> = try await perform(path, method: "DELETE", query: [], body: nil, authenticated: true, retrying: false)
        return envelope.data
    }

    private func perform<Response: Decodable>(
        _ path: String,
        method: String,
        query: [URLQueryItem],
        body: Data?,
        authenticated: Bool,
        retrying: Bool
    ) async throws -> Response {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        request.setValue("yourmusic-ios", forHTTPHeaderField: "X-Overture-Client")
        if authenticated, let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401, authenticated, !retrying {
            try await refreshSession()
            return try await perform(path, method: method, query: query, body: body, authenticated: true, retrying: true)
        }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw http.statusCode == 401 ? APIError.unauthorized : APIError.server(error?.error ?? "Request failed (\(http.statusCode)).")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func refreshSession() async throws {
        if let refreshTask {
            try await refreshTask.value
            return
        }
        guard let refreshToken else { throw APIError.unauthorized }
        let task = Task { [weak self] in
            guard let self else { throw APIError.unauthorized }
            let response: AuthSessionResponse = try await self.raw(
                "auth/refresh",
                body: RefreshBody(refreshToken: refreshToken),
                authenticated: false
            )
            guard let access = response.accessToken, let refresh = response.refreshToken else {
                throw APIError.unauthorized
            }
            try await self.setSession(accessToken: access, refreshToken: refresh)
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            try await task.value
        } catch {
            clearSession()
            throw error
        }
    }
}
