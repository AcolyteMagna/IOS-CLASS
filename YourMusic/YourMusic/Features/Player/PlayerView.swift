import SwiftUI
import WebKit
import AVFoundation

@MainActor
final class PlayerStore: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    @Published var playback: PlaybackResponse?
    @Published var isPlayerPresented = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    let webView: WKWebView
    private var loadedVideoID: String?
    private var playlistSessionID: Int?
    private var isAdvancingPlaylist = false
    private var webProcessRecoveryAttempts = 0
    private var lastWebProcessRecoveryAt: Date?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        configuration.userContentController.add(self, name: "playerEvent")
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
    }

    func play(trackID: Int) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response = try await YourMusicAPI.playback(trackID: trackID)
                playlistSessionID = nil
                activatePlaybackAudioSession()
                preparePlayer(for: response.embedUrl)
                playback = response
                isPlayerPresented = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func play(playlistID: Int, shuffled: Bool) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let session = try await YourMusicAPI.playback(
                    playlistID: playlistID,
                    shuffled: shuffled
                )
                try applyPlaylistSession(session)
                isPlayerPresented = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func presentPlayer() {
        isPlayerPresented = true
    }

    func minimizePlayer() {
        isPlayerPresented = false
    }

    func closePlayer() {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: YouTubePlayerDocument.documentURL)
        loadedVideoID = nil
        playlistSessionID = nil
        isAdvancingPlaylist = false
        webProcessRecoveryAttempts = 0
        lastWebProcessRecoveryAt = nil
        playback = nil
        isPlayerPresented = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        MainActor.assumeIsolated { [weak self] in
            guard message.name == "playerEvent",
                  (message.body as? String) == "ended" else { return }
            Task {
                await self?.advancePlaylist()
            }
        }
    }

    nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        MainActor.assumeIsolated { [weak self] in
            self?.recoverTerminatedWebContentProcess()
        }
    }

    private func applyPlaylistSession(_ session: PlaylistPlaybackResponse) throws {
        guard let item = session.currentItem,
              item.status == "READY",
              item.embedUrl != nil else {
            throw APIError.server("No playable songs remain in this playlist.")
        }
        playlistSessionID = session.playbackSessionId
        activatePlaybackAudioSession()
        let next = PlaybackResponse(
            playbackSessionId: session.playbackSessionId,
            songId: item.songId,
            youtubeVideoId: item.youtubeVideoId,
            youtubeUrl: item.youtubeUrl,
            embedUrl: item.embedUrl,
            title: item.trackTitle,
            channelName: item.artistName ?? item.channelName,
            status: item.status
        )
        preparePlayer(for: next.embedUrl)
        playback = next
    }

    private func advancePlaylist() async {
        guard let playlistSessionID, !isAdvancingPlaylist else { return }
        isAdvancingPlaylist = true
        defer { isAdvancingPlaylist = false }
        do {
            let session = try await YourMusicAPI.advancePlayback(sessionID: playlistSessionID)
            if session.currentItem == nil {
                closePlayer()
                return
            }
            try applyPlaylistSession(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preparePlayer(
        for embedURL: String?,
        resetRecoveryState: Bool = true
    ) {
        guard let embedURL,
              let videoID = YouTubePlayerDocument.videoID(from: embedURL) else {
            loadedVideoID = nil
            webView.loadHTMLString("", baseURL: YouTubePlayerDocument.documentURL)
            return
        }
        guard videoID != loadedVideoID else { return }

        if resetRecoveryState {
            webProcessRecoveryAttempts = 0
            lastWebProcessRecoveryAt = nil
        }
        loadedVideoID = videoID
        webView.loadHTMLString(
            YouTubePlayerDocument.html(videoID: videoID),
            baseURL: YouTubePlayerDocument.documentURL
        )
    }

    private func activatePlaybackAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    private func recoverTerminatedWebContentProcess() {
        guard let embedURL = playback?.embedUrl,
              YouTubePlayerDocument.videoID(from: embedURL) != nil else { return }

        let now = Date()
        if let lastWebProcessRecoveryAt,
           now.timeIntervalSince(lastWebProcessRecoveryAt) <= 30 {
            webProcessRecoveryAttempts += 1
        } else {
            webProcessRecoveryAttempts = 1
        }
        self.lastWebProcessRecoveryAt = now

        guard webProcessRecoveryAttempts <= 2 else {
            errorMessage = "The embedded video process stopped repeatedly. Close and reopen the player to retry."
            return
        }

        loadedVideoID = nil
        preparePlayer(for: embedURL, resetRecoveryState: false)
    }
}

struct PlayerView: View {
    @EnvironmentObject private var player: PlayerStore
    @State private var compactOffset: CGSize = .zero
    @GestureState private var activeDrag: CGSize = .zero

    private let compactWidth: CGFloat = 250
    private let compactVideoHeight: CGFloat = 200
    private let compactHeaderHeight: CGFloat = 52

    var body: some View {
        GeometryReader { proxy in
            let expanded = player.isPlayerPresented
            let compactHeight = compactHeaderHeight + compactVideoHeight
            let fullVideoWidth = max(proxy.size.width - 40, 200)
            let fullVideoHeight = max(200, min(fullVideoWidth * 9 / 16, proxy.size.height * 0.52))
            let proposedOffset = CGSize(
                width: compactOffset.width + activeDrag.width,
                height: compactOffset.height + activeDrag.height
            )
            let visibleOffset = clampedCompactOffset(proposedOffset, in: proxy, height: compactHeight)

            VStack(spacing: 0) {
                if expanded {
                    expandedHeader
                        .frame(height: 58)
                        .padding(.horizontal, 20)
                } else {
                    compactHeader
                        .frame(height: compactHeaderHeight)
                        .contentShape(Rectangle())
                        .simultaneousGesture(compactDragGesture(in: proxy, height: compactHeight))
                }

                if let playback = player.playback, playback.embedUrl != nil {
                    YouTubeWebView(webView: player.webView)
                        .frame(
                            width: expanded ? fullVideoWidth : compactWidth,
                            height: expanded ? fullVideoHeight : compactVideoHeight
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: expanded ? 22 : 0,
                                style: .continuous
                            )
                        )
                        .padding(.horizontal, expanded ? 20 : 0)

                    if expanded {
                        VStack(spacing: 6) {
                            Text(playback.title ?? "Unknown title")
                                .font(.system(.title2, design: .serif, weight: .bold))
                                .multilineTextAlignment(.center)
                            Text(playback.channelName ?? "YouTube")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                        .foregroundStyle(.white)
                        .padding(.top, 18)

                        Spacer(minLength: 0)
                    }
                } else {
                    ContentUnavailableView(
                        "Playback unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Overture could not find an embeddable YouTube match.")
                    )
                    .foregroundStyle(.white)
                    .frame(
                        width: expanded ? fullVideoWidth : compactWidth,
                        height: expanded ? fullVideoHeight : compactVideoHeight
                    )

                    if expanded {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(
                width: expanded ? proxy.size.width : compactWidth,
                height: expanded ? proxy.size.height : compactHeight
            )
            .background(YMColor.ink)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: expanded ? 0 : 18,
                    style: .continuous
                )
            )
            .shadow(color: .black.opacity(expanded ? 0 : 0.28), radius: 18, y: 8)
            .position(
                x: expanded
                    ? proxy.size.width / 2
                    : compactBaseCenter(in: proxy, height: compactHeight).x + visibleOffset.width,
                y: expanded
                    ? proxy.size.height / 2
                    : compactBaseCenter(in: proxy, height: compactHeight).y + visibleOffset.height
            )
            .animation(.snappy(duration: 0.32), value: expanded)
        }
    }

    private var expandedHeader: some View {
        HStack {
            Button { player.minimizePlayer() } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 32, height: 32)
            }
            Spacer()
            Text("NOW PLAYING")
                .font(.system(.caption, design: .rounded, weight: .black))
                .tracking(2.2)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .foregroundStyle(.white)
    }

    private var compactHeader: some View {
        HStack(spacing: 9) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.white.opacity(0.52))
            VStack(alignment: .leading, spacing: 1) {
                Text(player.playback?.title ?? "Now playing")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .lineLimit(1)
                Text("Drag to move")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.52))
            }
            Spacer(minLength: 4)
            Button { player.presentPlayer() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
            Button { player.closePlayer() } label: {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close player")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
    }

    private func compactBaseCenter(in proxy: GeometryProxy, height: CGFloat) -> CGPoint {
        CGPoint(
            x: proxy.size.width - compactWidth / 2 - 12,
            y: proxy.size.height - proxy.safeAreaInsets.bottom - 84 - height / 2
        )
    }

    private func clampedCompactOffset(
        _ proposed: CGSize,
        in proxy: GeometryProxy,
        height: CGFloat
    ) -> CGSize {
        let base = compactBaseCenter(in: proxy, height: height)
        let horizontalInset: CGFloat = 8
        let topInset = proxy.safeAreaInsets.top + 8
        let bottomInset = proxy.safeAreaInsets.bottom + 76
        let minX = compactWidth / 2 + horizontalInset
        let maxX = max(minX, proxy.size.width - compactWidth / 2 - horizontalInset)
        let minY = height / 2 + topInset
        let maxY = max(minY, proxy.size.height - height / 2 - bottomInset)
        let centerX = min(max(base.x + proposed.width, minX), maxX)
        let centerY = min(max(base.y + proposed.height, minY), maxY)
        return CGSize(width: centerX - base.x, height: centerY - base.y)
    }

    private func compactDragGesture(in proxy: GeometryProxy, height: CGFloat) -> some Gesture {
        DragGesture()
            .updating($activeDrag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                compactOffset = clampedCompactOffset(
                    CGSize(
                        width: compactOffset.width + value.translation.width,
                        height: compactOffset.height + value.translation.height
                    ),
                    in: proxy,
                    height: height
                )
            }
    }
}

private struct YouTubeWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
    }
}

private enum YouTubePlayerDocument {
    static let documentURL = URL(string: "https://overturegame.com/yourmusic/player")!
    private static let clientOrigin = "https://overturegame.com"

    static func videoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let host = (components.host ?? "").lowercased()
        let candidate: String?
        if host == "youtu.be" {
            candidate = components.path.split(separator: "/").first.map(String.init)
        } else if host == "youtube.com" || host.hasSuffix(".youtube.com") {
            let pathParts = components.path.split(separator: "/").map(String.init)
            if let embedIndex = pathParts.firstIndex(of: "embed"), pathParts.indices.contains(embedIndex + 1) {
                candidate = pathParts[embedIndex + 1]
            } else {
                candidate = components.queryItems?.first(where: { $0.name == "v" })?.value
            }
        } else {
            candidate = nil
        }

        guard let candidate,
              candidate.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return candidate
    }

    static func html(videoID: String) -> String {
        return """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
            <meta name="referrer" content="strict-origin-when-cross-origin">
            <style>
              html, body, #player, iframe { width: 100%; height: 100%; margin: 0; border: 0; background: #232323; overflow: hidden; }
            </style>
          </head>
          <body>
            <div id="player"></div>
            <script src="https://www.youtube.com/iframe_api"></script>
            <script>
              function onYouTubeIframeAPIReady() {
                new YT.Player('player', {
                  videoId: '\(videoID)',
                  playerVars: {
                    autoplay: 1,
                    playsinline: 1,
                    enablejsapi: 1,
                    origin: '\(clientOrigin)',
                    widget_referrer: '\(documentURL.absoluteString)'
                  },
                  events: {
                    onStateChange: function(event) {
                      if (event.data === YT.PlayerState.ENDED) {
                        window.webkit.messageHandlers.playerEvent.postMessage('ended');
                      }
                    }
                  }
                });
              }
            </script>
          </body>
        </html>
        """
    }
}
