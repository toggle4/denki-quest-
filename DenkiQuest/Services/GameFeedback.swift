import Foundation

/// 効果音と触覚をまとめて鳴らす。画面側はこれだけ呼べばよい。
enum GameFeedback {
    static func tap() {
        Haptics.tap()
        SoundPlayer.shared.play(.tap)
    }

    static func correct(combo: Int) {
        Haptics.correct()
        if combo >= 3 {
            SoundPlayer.shared.play(.combo)
        } else {
            SoundPlayer.shared.play(.correct)
        }
    }

    static func wrong() {
        Haptics.wrong()
        SoundPlayer.shared.play(.wrong)
    }

    /// ボス登場。重い振動と低い雷鳴で「出てきた」感を出す。
    static func bossAppear() {
        Haptics.heavy()
        SoundPlayer.shared.play(.short)
    }

    static func sessionCleared(perfect: Bool) {
        Haptics.heavy()
        SoundPlayer.shared.play(perfect ? .perfect : .clear)
    }
}
