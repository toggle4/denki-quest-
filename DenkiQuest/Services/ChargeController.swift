import Foundation
import Observation

/// マスコット長押しの「充電」状態。振動の間隔と強さ、6 秒でのショートを管理する。
@Observable
final class ChargeController {
    enum Phase {
        case idle
        case charging
        case shorted
        case cooldown
    }

    /// ここまで押し続けるとショートする
    static let maxSeconds: Double = 6.0

    private(set) var phase: Phase = .idle
    /// 0.0〜1.0。押し続けた割合
    private(set) var charge: Double = 0
    private(set) var shortCount = 0
    private(set) var shortedAt: Date?

    private var task: Task<Void, Never>?
    private var startedAt: Date?
    private var lastHaptic: Date = .distantPast

    func pressBegan() {
        guard phase == .idle else { return }
        phase = .charging
        startedAt = Date()
        lastHaptic = .distantPast
        charge = 0
        SoundPlayer.shared.play(.charge)

        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.phase == .charging else { return }
                self.tick()
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    func pressEnded() {
        guard phase == .charging else { return }
        task?.cancel()
        task = nil
        SoundPlayer.shared.stop(.charge)

        let released = charge
        phase = .idle
        charge = 0

        if released < 0.06 {
            // ただのタップ
            GameFeedback.tap()
        } else {
            // 途中で離す: たまった分だけ強く放電
            Haptics.impact(intensity: 0.4 + released * 0.6)
            SoundPlayer.shared.play(.zap)
        }
    }

    private func tick() {
        guard let startedAt else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        charge = min(elapsed / Self.maxSeconds, 1.0)

        // 振動: 最初は 0.28 秒おきの弱い振動、最後は 0.05 秒おきの強い振動
        let interval = 0.28 - 0.23 * charge
        if Date().timeIntervalSince(lastHaptic) >= interval {
            lastHaptic = Date()
            Haptics.impact(intensity: 0.25 + 0.75 * charge)
        }

        if elapsed >= Self.maxSeconds {
            shortCircuit()
        }
    }

    private func shortCircuit() {
        task?.cancel()
        task = nil
        SoundPlayer.shared.stop(.charge)
        SoundPlayer.shared.play(.short)
        Haptics.shortCircuit()

        phase = .shorted
        shortedAt = Date()
        shortCount += 1

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard let self, self.phase == .shorted else { return }
            self.phase = .cooldown
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard self.phase == .cooldown else { return }
            self.phase = .idle
            self.charge = 0
        }
    }
}
