import Foundation
import Observation

/// ボス戦の記録（クリア・最速タイム）。
enum BossRecordStore {
    private static func key(_ unitId: String, _ name: String) -> String { "boss.\(unitId).\(name)" }

    static func isCleared(_ unitId: String) -> Bool {
        UserDefaults.standard.bool(forKey: key(unitId, "cleared"))
    }

    static func bestTime(_ unitId: String) -> Double? {
        let t = UserDefaults.standard.double(forKey: key(unitId, "bestTime"))
        return t > 0 ? t : nil
    }

    static func recordClear(_ unitId: String, time: Double) {
        UserDefaults.standard.set(true, forKey: key(unitId, "cleared"))
        if let best = bestTime(unitId), best <= time {
            // 更新なし
        } else {
            UserDefaults.standard.set(time, forKey: key(unitId, "bestTime"))
        }
        LessonProgressStore.changes.bump()
    }
}

/// ボス戦の進行。正解でダメージ（速いほど大きい）、不正解は反撃でコンボが途切れる。負けは時間切れと降参だけ。
@Observable
final class BossEngine {
    enum Phase {
        case intro
        /// 3・2・1・GO! のカウントダウン。ここではまだ時間が減らない
        case countdown
        case fighting
        case won
        case lost
    }

    enum LoseReason {
        case timeout
        case surrender
    }

    struct Event: Identifiable {
        enum Kind {
            case hit
            case counter
        }
        let id = UUID()
        let kind: Kind
        let amount: Int
        let critical: Bool
        let combo: Int
        let at: Date
    }

    let unit: LearningUnit
    /// この単元に割り当てられたボス。対応表にない単元では nil。
    let boss: Boss?
    let maxHP: Int
    let timeLimit: Double
    private let baseDamage: Int

    private(set) var phase: Phase = .intro
    private(set) var loseReason: LoseReason?
    private(set) var bossHP: Int
    private(set) var remaining: Double
    private(set) var combo = 0
    private(set) var maxCombo = 0
    private(set) var totalDamage = 0
    private(set) var maxHit = 0
    private(set) var answered = 0
    private(set) var correctCount = 0
    private(set) var events: [Event] = []
    /// 被弾・反撃の演出トリガー（増えるたびに View が反応する）
    private(set) var hitToken = 0
    private(set) var counterToken = 0
    /// 残り時間の警告（10 秒・5 秒）。増えるたびに View が反応する
    private(set) var warnToken = 0
    /// カウントダウンの表示（3 → 2 → 1 → 0 は GO!）
    private(set) var countdown = 3
    /// いまの問題が出た時刻。速度ゲージが使う
    private(set) var questionShownAt = Date()
    /// 間違えた問題（結果画面で見直す）
    private(set) var missed: [Question] = []

    private(set) var current: QuizSession.Item?
    /// 回答のたびに呼ばれる（間隔反復の記録用）
    var onAnswered: ((Question, Bool) -> Void)?
    /// 回答直後の表示用
    private(set) var selectedIndex: Int?
    private(set) var selectedBool: Bool?
    private(set) var lastCorrect: Bool?
    private(set) var lastAnswerSeconds: Double = 0

    private var queue: [Question] = []
    private var shownAt = Date()
    private var warned10 = false
    private var warned5 = false
    private var countdownTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?

    init(unit: LearningUnit) {
        self.unit = unit
        self.boss = BossRoster.boss(forUnit: unit.id)
        let pick = max(unit.boss?.questionCount ?? 5, 1)
        self.timeLimit = Double(unit.boss?.timeLimitSeconds ?? 90)
        self.remaining = timeLimit
        self.maxHP = pick * 100
        self.bossHP = pick * 100
        self.baseDamage = 100
    }

    var elapsed: Double { timeLimit - remaining }
    var isBusy: Bool { lastCorrect != nil }
    /// HP が 3 割を切ると本気を出す。
    var isEnraged: Bool { phase == .fighting && Double(bossHP) <= Double(maxHP) * 0.3 }
    /// いまの調子であと何発で倒せるか（目安）。
    var estimatedHitsLeft: Int {
        let perHit = max(Double(baseDamage), Double(totalDamage) / Double(max(correctCount, 1)))
        return max(1, Int(ceil(Double(bossHP) / perHit)))
    }

    // MARK: - 開始・タイマー

    func start() {
        guard phase == .intro else { return }
        phase = .countdown
        countdown = 3
        countdownTask = Task { @MainActor [weak self] in
            for value in stride(from: 3, through: 0, by: -1) {
                guard let self, self.phase == .countdown else { return }
                self.countdown = value
                Haptics.impact(intensity: value == 0 ? 1.0 : 0.5)
                SoundPlayer.shared.play(value == 0 ? .zap : .tap)
                try? await Task.sleep(nanoseconds: value == 0 ? 450_000_000 : 700_000_000)
            }
            guard let self, self.phase == .countdown else { return }
            self.beginFight()
        }
    }

    private func beginFight() {
        phase = .fighting
        nextQuestion()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self, self.phase == .fighting else { return }
                self.events.removeAll { Date().timeIntervalSince($0.at) > 1.4 }
                // 正誤の演出を見せているあいだは時間を止める（読む時間を取られない）
                guard self.lastCorrect == nil else { continue }
                self.remaining = max(0, self.remaining - 0.1)
                self.checkTimeWarning()
                if self.remaining <= 0 {
                    self.lose(.timeout)
                }
            }
        }
    }

    /// 残り 10 秒・5 秒で一度ずつ警告を出す。
    private func checkTimeWarning() {
        if !warned10, remaining <= 10 {
            warned10 = true
            warnToken += 1
            Haptics.impact(intensity: 0.6)
        }
        if !warned5, remaining <= 5 {
            warned5 = true
            warnToken += 1
            Haptics.impact(intensity: 0.9)
        }
    }

    /// 降参して戦いを終える。
    func surrender() {
        guard phase == .fighting || phase == .countdown else { return }
        phase = .fighting
        lose(.surrender)
    }

    func stop() {
        timerTask?.cancel()
        advanceTask?.cancel()
        countdownTask?.cancel()
        SoundPlayer.shared.stop(.charge)
    }

    private func nextQuestion() {
        if queue.isEmpty {
            queue = unit.questions.shuffled()
        }
        guard !queue.isEmpty else {
            lose(.timeout)
            return
        }
        let question = queue.removeFirst()
        current = QuizSession.makeItem(question)
        selectedIndex = nil
        selectedBool = nil
        lastCorrect = nil
        shownAt = Date()
        questionShownAt = shownAt
    }

    // MARK: - 回答

    func answerChoice(_ index: Int) {
        guard let current, current.question.type == .choice, !isBusy else { return }
        selectedIndex = index
        resolve(correct: index == current.correctIndex)
    }

    func answerBool(_ value: Bool) {
        guard let current, current.question.type == .truefalse, !isBusy else { return }
        selectedBool = value
        resolve(correct: value == current.question.answerBool)
    }

    func answerNumber(_ value: Double) {
        guard let current, current.question.type == .number, !isBusy else { return }
        resolve(correct: current.question.isCorrectNumber(value))
    }

    private func resolve(correct: Bool) {
        guard phase == .fighting else { return }
        let seconds = Date().timeIntervalSince(shownAt)
        lastAnswerSeconds = seconds
        lastCorrect = correct
        answered += 1
        onAnswered?(current!.question, correct)

        if correct {
            correctCount += 1
            let speed = Self.speedMultiplier(seconds)
            let comboMultiplier = 1.0 + Double(min(combo, 5)) * 0.1
            let damage = Int((Double(baseDamage) * speed * comboMultiplier).rounded())
            let critical = speed >= 2.0
            combo += 1
            maxCombo = max(maxCombo, combo)
            totalDamage += damage
            maxHit = max(maxHit, damage)
            bossHP = max(0, bossHP - damage)
            events.append(Event(kind: .hit, amount: damage, critical: critical, combo: combo, at: Date()))
            hitToken += 1
            Haptics.impact(intensity: critical ? 1.0 : 0.7)
            SoundPlayer.shared.play(critical ? .combo : .zap)
            if bossHP <= 0 {
                win()
                return
            }
        } else {
            if !missed.contains(where: { $0.id == current!.question.id }) {
                missed.append(current!.question)
            }
            // 不正解は反撃を受けてコンボが途切れる。負けは時間切れだけ
            combo = 0
            events.append(Event(kind: .counter, amount: 0, critical: false, combo: 0, at: Date()))
            counterToken += 1
            Haptics.shortCircuit()
            SoundPlayer.shared.play(.wrong)
        }

        advanceTask?.cancel()
        advanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: correct ? 900_000_000 : 1_400_000_000)
            guard let self, self.phase == .fighting else { return }
            self.nextQuestion()
        }
    }

    /// 速いほど大きい。3 秒以内はクリティカル。
    static func speedMultiplier(_ seconds: Double) -> Double {
        switch seconds {
        case ..<3: return 2.0
        case ..<6: return 1.5
        case ..<10: return 1.2
        default: return 1.0
        }
    }

    private func win() {
        phase = .won
        timerTask?.cancel()
        // 図鑑の記録を先に書いてから、画面の更新通知（bump）を出す
        if let boss {
            BossCollection.registerDefeat(bossId: boss.id, time: elapsed, combo: maxCombo, hit: maxHit)
        }
        BossRecordStore.recordClear(unit.id, time: elapsed)
        Haptics.heavy()
        SoundPlayer.shared.play(.short)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            SoundPlayer.shared.play(.perfect)
        }
    }

    private func lose(_ reason: LoseReason) {
        guard phase == .fighting else { return }
        phase = .lost
        loseReason = reason
        timerTask?.cancel()
        advanceTask?.cancel()
        countdownTask?.cancel()
        if reason != .surrender {
            Haptics.shortCircuit()
            SoundPlayer.shared.play(.wrong)
        }
    }
}
