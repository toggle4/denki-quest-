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
    /// ショートする電圧。高圧配電線と同じ 6.6kV にしてある
    static let shortVoltage: Double = 6600
    /// ここから先は危険表示（画面が震えだす）
    static let dangerLevel: Double = 0.75
    /// これ以上で離すと「ギリギリ」
    static let closeLevel: Double = 0.9
    static let bestKey = "mascot.bestVoltage"

    /// 途中で離したときの結果（ギリギリ放電の記録つき）
    struct Discharge: Equatable {
        let id = UUID()
        let voltage: Double
        let isRecord: Bool
        var isClose: Bool { voltage >= ChargeController.shortVoltage * ChargeController.closeLevel }
    }

    private(set) var phase: Phase = .idle
    /// 0.0〜1.0。押し続けた割合
    private(set) var charge: Double = 0
    private(set) var shortCount = 0
    private(set) var shortedAt: Date?
    /// 危険域に入っているか（画面全体の演出に使う）
    private(set) var isDanger = false
    /// 最後に離したときの結果
    private(set) var lastDischarge: Discharge?
    /// ショートさせずに離せた最高電圧
    private(set) var bestVoltage: Double = UserDefaults.standard.double(forKey: ChargeController.bestKey)

    /// いまの電圧 [V]
    var voltage: Double { charge * Self.shortVoltage }

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
        isDanger = false

        if released < 0.06 {
            // ただのタップ
            GameFeedback.tap()
        } else {
            // 途中で離す: たまった分だけ強く放電。ショート寸前ほど記録になる
            Haptics.impact(intensity: 0.4 + released * 0.6)
            SoundPlayer.shared.play(.zap)
            let volts = released * Self.shortVoltage
            let record = volts > bestVoltage
            if record {
                bestVoltage = volts
                UserDefaults.standard.set(volts, forKey: Self.bestKey)
            }
            lastDischarge = Discharge(voltage: volts, isRecord: record)
        }
    }

    private func tick() {
        guard let startedAt else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        charge = min(elapsed / Self.maxSeconds, 1.0)
        let danger = charge >= Self.dangerLevel
        if danger != isDanger { isDanger = danger }

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
        isDanger = false
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
