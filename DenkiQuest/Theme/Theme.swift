import SwiftUI

/// ゲーム全体の配色。ダークネイビーの背景に電気っぽい黄色をアクセントにする。
enum Theme {
    static let backgroundTop = Color(red: 0.11, green: 0.15, blue: 0.32)
    static let backgroundBottom = Color(red: 0.05, green: 0.06, blue: 0.16)
    static let card = Color.white.opacity(0.08)
    static let cardBorder = Color.white.opacity(0.14)
    static let volt = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let voltDark = Color(red: 0.79, green: 0.59, blue: 0.0)
    static let correct = Color(red: 0.24, green: 0.90, blue: 0.56)
    static let wrong = Color(red: 1.0, green: 0.36, blue: 0.42)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)

    static func stageColor(_ stage: LearningUnit.Stage) -> Color {
        switch stage {
        case .review: return Color(red: 0.40, green: 0.75, blue: 1.0)
        case .memorize: return Color(red: 0.75, green: 0.55, blue: 1.0)
        case .calculate: return Color(red: 1.0, green: 0.62, blue: 0.30)
        case .practical: return Color(red: 0.35, green: 0.90, blue: 0.70)
        }
    }
}

/// 全画面共通のグラデーション背景。
struct GameBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Theme.backgroundTop, Theme.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// カード風の枠。
struct GameCard: ViewModifier {
    var tint: Color = .clear
    var border: Color = Theme.cardBorder

    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .background(tint, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(border, lineWidth: 1.5)
            )
    }
}

extension View {
    func gameCard(tint: Color = .clear, border: Color = Theme.cardBorder) -> some View {
        modifier(GameCard(tint: tint, border: border))
    }
}

/// 黄色いメインボタン。
struct VoltButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(prominent ? Theme.backgroundBottom : Theme.textPrimary)
            .background(
                prominent ? Theme.volt : Color.white.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(prominent ? Theme.voltDark : Theme.cardBorder, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
