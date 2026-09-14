import UIKit

/// 触覚フィードバック。設定でオフにできる。
enum Haptics {
    static let enabledKey = "hapticsEnabled"

    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) == nil
            || UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func tap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func correct() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func wrong() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func heavy() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // MARK: - 連続的な振動（充電演出用）

    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)

    /// 強さ 0.0〜1.0 の単発振動。強さに応じて light / medium / heavy を使い分ける。
    static func impact(intensity: Double) {
        guard isEnabled else { return }
        let clamped = min(max(intensity, 0.05), 1.0)
        let generator: UIImpactFeedbackGenerator
        switch clamped {
        case ..<0.34: generator = lightGenerator
        case ..<0.67: generator = mediumGenerator
        default: generator = heavyGenerator
        }
        generator.impactOccurred(intensity: CGFloat(clamped))
        generator.prepare()
    }

    /// ショート演出: 強い振動を連打してから、エラー振動で締める。
    static func shortCircuit() {
        guard isEnabled else { return }
        heavyGenerator.prepare()
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.055) {
                heavyGenerator.impactOccurred(intensity: 1.0)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
