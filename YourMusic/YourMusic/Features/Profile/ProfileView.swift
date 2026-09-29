import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var favorites: [FavoriteArtist] = []
    @State private var accountSecurity: AccountSecurity?

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    EditorialTitle(eyebrow: "Account", title: session.user?.displayName ?? "Listener", subtitle: "Your Overture identity")

                    VStack(alignment: .leading, spacing: 14) {
                        Label("Favorite artists", systemImage: "heart.fill")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        if favorites.isEmpty {
                            Text("Favorite artists from Discover will appear here.")
                                .foregroundStyle(YMColor.ink.opacity(0.58))
                        } else {
                            ForEach(favorites) { favorite in
                                NavigationLink(favorite.artistName) {
                                    ArtistDetailView(artistID: favorite.artistId)
                                }
                            }
                        }
                    }
                    .ymCard()

                    NavigationLink {
                        EmailLoginSetupView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email + password login").font(.headline)
                                Text(accountSecurity?.hasPassword == true ? "Configured" : "Add a second way to sign in")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: accountSecurity?.hasPassword == true ? "checkmark.shield.fill" : "chevron.right")
                                .foregroundStyle(YMColor.cobalt)
                        }
                        .foregroundStyle(YMColor.ink)
                        .ymCard()
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        Task { await session.logout() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
            }
        }
        .task {
            favorites = (try? await YourMusicAPI.favorites()) ?? []
            accountSecurity = (try? await YourMusicAPI.account())?.security
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EmailLoginSetupView: View {
    @State private var security: AccountSecurity?
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmedPassword = ""
    @State private var codeWasSent = false
    @State private var isWorking = false
    @State private var message: String?

    private var emailIsVerified: Bool {
        security?.emailVerifiedAt != nil && security?.email?.caseInsensitiveCompare(email) == .orderedSame
    }

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    EditorialTitle(
                        eyebrow: "Account security",
                        title: "Add email login",
                        subtitle: "Verify an email, then choose a password. Your Last.fm sign-in will keep working too."
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Verify your email").font(.headline)
                        TextField("Email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .textFieldStyle(.roundedBorder)
                        Button(emailIsVerified ? "Email verified" : "Send verification code") {
                            run {
                                try await YourMusicAPI.requestEmailVerification(email)
                                codeWasSent = true
                                message = "Verification code sent."
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isWorking || email.isEmpty || emailIsVerified)

                        if codeWasSent && !emailIsVerified {
                            TextField("6-digit code", text: $verificationCode)
                                .textContentType(.oneTimeCode)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                            Button("Verify email") {
                                run {
                                    try await YourMusicAPI.verifyEmail(email, code: verificationCode)
                                    await reload()
                                    message = "Email verified. You can now set a password."
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isWorking || verificationCode.count != 6)
                        }
                    }
                    .ymCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("2. Choose a password").font(.headline)
                        if security?.hasPassword == true {
                            SecureField("Current password", text: $currentPassword)
                                .textContentType(.password)
                                .textFieldStyle(.roundedBorder)
                        }
                        SecureField("New password", text: $newPassword)
                            .textContentType(.newPassword)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Confirm new password", text: $confirmedPassword)
                            .textContentType(.newPassword)
                            .textFieldStyle(.roundedBorder)
                        Button(security?.hasPassword == true ? "Change password" : "Create email login") {
                            run {
                                guard newPassword == confirmedPassword else {
                                    throw APIError.server("Passwords do not match.")
                                }
                                try await YourMusicAPI.setPassword(
                                    newPassword,
                                    currentPassword: security?.hasPassword == true ? currentPassword : nil
                                )
                                await reload()
                                newPassword = ""
                                confirmedPassword = ""
                                currentPassword = ""
                                message = "Email and password login is ready."
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(
                            isWorking || !emailIsVerified || newPassword.count < 8 ||
                            confirmedPassword.isEmpty ||
                            (security?.hasPassword == true && currentPassword.isEmpty)
                        )
                    }
                    .ymCard()

                    if let message {
                        Text(message).font(.footnote.weight(.semibold)).foregroundStyle(YMColor.cobalt)
                    }
                }
                .padding(20)
            }
        }
        .task { await reload() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reload() async {
        if let account = try? await YourMusicAPI.account() {
            security = account.security
            if email.isEmpty { email = account.security.email ?? "" }
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        isWorking = true
        message = nil
        Task {
            do { try await operation() }
            catch { message = error.localizedDescription }
            isWorking = false
        }
    }
}
