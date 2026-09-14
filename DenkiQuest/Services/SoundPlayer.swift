import AVFoundation

/// 効果音の再生。音源は `DenkiQuest/Sounds/*.wav`（`tools/gen_sounds.py` で自作生成）。
final class SoundPlayer {
    static let shared = SoundPlayer()
    static let enabledKey = "soundEnabled"

    enum Sound: String, CaseIterable {
        case tap
        case correct
        case wrong
        case combo
        case clear
        case perfect
        case charge
        case zap
        case short
    }

    private var players: [Sound: AVAudioPlayer] = [:]

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) == nil
            || UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    private init() {
        // マナーモードでは鳴らさず、他アプリの音楽も止めない
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[sound] = player
        }
    }

    func play(_ sound: Sound) {
        guard isEnabled, let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }

    func stop(_ sound: Sound) {
        guard let player = players[sound], player.isPlaying else { return }
        player.stop()
        player.currentTime = 0
    }
}
