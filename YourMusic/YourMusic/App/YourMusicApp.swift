import SwiftUI

@main
struct YourMusicApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var player = PlayerStore()

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading:
                    LaunchView()
                case .signedOut:
                    LoginView()
                case .signedIn:
                    RootView()
                }
            }
            .environmentObject(session)
            .environmentObject(player)
            .preferredColorScheme(.light)
            .task { await session.restore() }
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            YourMusicBackground()
            VStack(spacing: 16) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(YMColor.cobalt)
                    .symbolEffect(.pulse)
                Text("YOUR MUSIC")
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .tracking(4)
            }
        }
    }
}
