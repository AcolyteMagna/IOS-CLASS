import Foundation
import SwiftUI

enum YMColor {
    static let paper = Color(red: 0.96, green: 0.93, blue: 0.85)
    static let ink = Color(red: 0.08, green: 0.10, blue: 0.13)
    static let cobalt = Color(red: 0.08, green: 0.27, blue: 0.86)
    static let orange = Color(red: 0.96, green: 0.34, blue: 0.11)
    static let mint = Color(red: 0.55, green: 0.85, blue: 0.66)
    static let line = Color.black.opacity(0.14)
}

struct YourMusicBackground: View {
    var body: some View {
        ZStack {
            YMColor.paper.ignoresSafeArea()
            Circle()
                .fill(YMColor.orange.opacity(0.16))
                .frame(width: 340, height: 340)
                .blur(radius: 2)
                .offset(x: 170, y: -310)
            RoundedRectangle(cornerRadius: 72)
                .fill(YMColor.cobalt.opacity(0.09))
                .frame(width: 290, height: 520)
                .rotationEffect(.degrees(24))
                .offset(x: -210, y: 360)
        }
    }
}

struct EditorialTitle: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.system(.caption, design: .rounded, weight: .black))
                .tracking(2.6)
                .foregroundStyle(YMColor.cobalt)
            Text(title)
                .font(.system(size: 40, weight: .black, design: .serif))
                .foregroundStyle(YMColor.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(YMColor.ink.opacity(0.64))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ArtworkView: View {
    let url: String?
    var size: CGFloat = 64
    var cornerRadius: CGFloat = 12

    var body: some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    YMColor.ink.opacity(0.08)
                    Image(systemName: "waveform")
                        .font(.system(size: size * 0.28, weight: .bold))
                        .foregroundStyle(YMColor.cobalt)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(YMColor.ink.opacity(0.12), lineWidth: 1)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(configuration.isPressed ? YMColor.ink : YMColor.cobalt)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

extension View {
    func ymCard() -> some View {
        self
            .padding(16)
            .background(Color.white.opacity(0.64))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(YMColor.line, lineWidth: 1)
            }
    }
}

extension Int {
    var durationLabel: String {
        let seconds = self / 1000
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
