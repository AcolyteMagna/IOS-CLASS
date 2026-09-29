import Combine
import Foundation
import AuthenticationServices
import UIKit

@MainActor
final class SessionStore: ObservableObject {
    enum State { case loading, signedOut, signedIn }

    @Published private(set) var state: State = .loading
    @Published private(set) var user: OvertureUser?
    @Published private(set) var pendingChallengeToken: String?
    @Published var errorMessage: String?

    private let client = APIClient.shared
    private let userDefaultsKey = "yourmusic.current-user"
    private let presentationContext = WebAuthenticationPresentationContext()
    private var webAuthenticationSession: ASWebAuthenticationSession?

    func restore() async {
        let hasTokens = await client.restoreTokens()
        guard hasTokens else {
            state = .signedOut
            return
        }
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let stored = try? JSONDecoder().decode(OvertureUser.self, from: data) {
            user = stored
            state = .signedIn
        } else {
            await client.clearSession()
            state = .signedOut
        }
    }

    func login(email: String, password: String) async {
        errorMessage = nil
        do {
            struct LoginBody: Encodable { let email: String; let password: String }
            let response: AuthSessionResponse = try await client.raw(
                "auth/email/login",
                body: LoginBody(email: email, password: password)
            )
            if response.requiresTwoFactor == true, let challenge = response.challengeToken {
                pendingChallengeToken = challenge
                state = .signedOut
                return
            }
            try await complete(response)
        } catch {
            errorMessage = error.localizedDescription
            state = .signedOut
        }
    }

    func verifyTwoFactor(code: String) async {
        guard let pendingChallengeToken else { return }
        errorMessage = nil
        do {
            struct VerifyBody: Encodable { let challengeToken: String; let code: String }
            let response: AuthSessionResponse = try await client.raw(
                "auth/email/login/verify-2fa",
                body: VerifyBody(challengeToken: pendingChallengeToken, code: code)
            )
            try await complete(response)
            self.pendingChallengeToken = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loginWithLastFm() async {
        errorMessage = nil
        do {
            let start: LastFmStartResponse = try await client.rawGet(
                "auth/lastfm/start",
                query: [URLQueryItem(name: "target", value: "yourmusic")]
            )
            guard let authorizationURL = URL(string: start.authURL) else {
                throw APIError.invalidURL
            }
            let callbackURL = try await openLastFmAuthorization(authorizationURL)
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                throw APIError.invalidResponse
            }
            struct ExchangeBody: Encodable { let code: String }
            let response: AuthSessionResponse = try await client.raw(
                "auth/lastfm/mobile/exchange",
                body: ExchangeBody(code: code)
            )
            try await complete(response)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch {
            errorMessage = error.localizedDescription
            state = .signedOut
        }
    }

    func logout() async {
        if let refresh = KeychainStore.get("refresh-token") {
            struct LogoutBody: Encodable { let refreshToken: String }
            let _: LogoutResponse? = try? await client.raw("auth/logout", body: LogoutBody(refreshToken: refresh))
        }
        await client.clearSession()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        user = nil
        pendingChallengeToken = nil
        state = .signedOut
    }

    private func complete(_ response: AuthSessionResponse) async throws {
        guard let access = response.accessToken,
              let refresh = response.refreshToken,
              let user = response.user else {
            throw APIError.invalidResponse
        }
        try await client.setSession(accessToken: access, refreshToken: refresh)
        self.user = user
        UserDefaults.standard.set(try JSONEncoder().encode(user), forKey: userDefaultsKey)
        state = .signedIn
    }

    private func openLastFmAuthorization(_ url: URL) async throws -> URL {
        defer { webAuthenticationSession = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let authenticationSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "yourmusic"
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: APIError.invalidResponse)
                }
            }
            authenticationSession.presentationContextProvider = presentationContext
            authenticationSession.prefersEphemeralWebBrowserSession = true
            webAuthenticationSession = authenticationSession
            guard authenticationSession.start() else {
                webAuthenticationSession = nil
                continuation.resume(throwing: APIError.invalidResponse)
                return
            }
        }
    }
}

private struct LogoutResponse: Decodable { let ok: Bool }

private final class WebAuthenticationPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
