import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var verificationCode = ""
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    Spacer(minLength: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR")
                        Text("MUSIC")
                            .foregroundStyle(YMColor.cobalt)
                    }
                    .font(.system(size: 68, weight: .black, design: .serif))
                    .tracking(-3)

                    Text("A personal record shelf, listening room, and music notebook powered by Overture.")
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(YMColor.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 14) {
                        if session.pendingChallengeToken == nil {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                        } else {
                            Text("Two-factor verification")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            TextField("6-digit code", text: $verificationCode)
                                .textContentType(.oneTimeCode)
                                .keyboardType(.numberPad)
                        }
                    }
                    .font(.system(.body, design: .rounded))
                    .textFieldStyle(.plain)
                    .padding(18)
                    .background(Color.white.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(YMColor.line)
                    }

                    if let message = session.errorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    Button {
                        isSigningIn = true
                        Task {
                            if session.pendingChallengeToken == nil {
                                await session.login(email: email, password: password)
                            } else {
                                await session.verifyTwoFactor(code: verificationCode)
                            }
                            isSigningIn = false
                        }
                    } label: {
                        HStack {
                            if isSigningIn { ProgressView().tint(.white) }
                            Text(isSigningIn ? "Opening your library..." : session.pendingChallengeToken == nil ? "Sign in with Overture" : "Verify and continue")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(
                        isSigningIn ||
                        (session.pendingChallengeToken == nil && (email.isEmpty || password.isEmpty)) ||
                        (session.pendingChallengeToken != nil && verificationCode.isEmpty)
                    )

                    HStack {
                        Rectangle().fill(YMColor.line).frame(height: 1)
                        Text("OR").font(.caption.weight(.black)).foregroundStyle(.secondary)
                        Rectangle().fill(YMColor.line).frame(height: 1)
                    }

                    Button {
                        isSigningIn = true
                        Task {
                            await session.loginWithLastFm()
                            isSigningIn = false
                        }
                    } label: {
                        Label("Create account or sign in with Last.fm", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSigningIn)

                    Text("New accounts start with Last.fm. After signing in, add a verified email and password from your profile. Credentials go only to api.overturegame.com, and session tokens stay in Keychain.")
                        .font(.caption)
                        .foregroundStyle(YMColor.ink.opacity(0.52))
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 28)
            }
        }
    }
}
