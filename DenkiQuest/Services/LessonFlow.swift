import Foundation
import Observation

/// 進捗が書き換わったことを画面に伝えるための観測点。
/// UserDefaults への書き込みは SwiftUI が検知しないので、書くたびに version を進める。
@Observable
final class LessonProgressChanges {
    private(set) var version = 0

    func bump() {
        version += 1
    }
}

/// 教材セッションの進捗（読了・要復習・再開位置）。SwiftData 化はタスク C-1 で行う。
/// 画面側は読み取り前に `LessonProgressStore.changes.version` に触れておくと、更新時に再描画される。
enum LessonProgressStore {
    static let changes = LessonProgressChanges()

    private static func key(_ unitId: String, _ session: Int, _ name: String) -> String {
        "lesson.\(unitId).\(session).\(name)"
    }

    static func isCompleted(_ unitId: String, session: Int) -> Bool {
        UserDefaults.standard.bool(forKey: key(unitId, session, "completed"))
    }

    static func setCompleted(_ unitId: String, session: Int, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key(unitId, session, "completed"))
        changes.bump()
    }

    static func needsReview(_ unitId: String, session: Int) -> Bool {
        UserDefaults.standard.bool(forKey: key(unitId, session, "needsReview"))
    }

    static func setNeedsReview(_ unitId: String, session: Int, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key(unitId, session, "needsReview"))
        changes.bump()
    }

    /// 途中で閉じたとき、次に開く位置（LessonFlow のブロック番号）
    static func resumeIndex(_ unitId: String, session: Int) -> Int {
        UserDefaults.standard.integer(forKey: key(unitId, session, "resume"))
    }

    static func setResumeIndex(_ unitId: String, session: Int, _ value: Int) {
        UserDefaults.standard.set(value, forKey: key(unitId, session, "resume"))
        changes.bump()
    }

    static func clearResume(_ unitId: String, session: Int) {
        UserDefaults.standard.removeObject(forKey: key(unitId, session, "resume"))
        changes.bump()
    }

    static func completedSessionCount(_ lesson: Lesson) -> Int {
        lesson.sessions.filter { isCompleted(lesson.unitId, session: $0.number) }.count
    }
}

/// 1 セッション分の「説明 → 差し込み問題 → 説明 → … → まとめ問題」の一本道を進める。
/// content/lessons/README.md「画面の流れ」「戻る・進むのルール」をここで守る。
@Observable
final class LessonFlow {
    /// 連続する説明画面はひとまとまり（この中は自由にスワイプできる）。問題はひとつずつ。
    enum Block {
        case reading([LessonPage])
        case quiz(ids: [String], isSessionQuiz: Bool)
    }

    enum Stage {
        case reading
        case quiz
        case finished
    }

    let lesson: Lesson
    let session: LessonSession
    let reviewMode: Bool
    let blocks: [Block]
    private let quizUnit: LearningUnit

    private(set) var blockIndex = 0
    /// 説明ブロック内のページ位置（TabView と双方向に結ぶ）
    var pageIndex = 0

    private(set) var quizSession: QuizSession?
    private(set) var questionIds: [String] = []
    private(set) var questionCursor = 0
    /// 1 = 初回、2 = 不正解後のやり直し
    private(set) var attempt = 1

    private(set) var blockCorrect = 0
    private(set) var blockAnswered = 0
    private(set) var totalCorrect = 0
    private(set) var totalAnswered = 0
    private(set) var sessionQuizCorrect = 0
    private(set) var sessionQuizTotal = 0
    private(set) var isFinished = false

    init(lesson: Lesson, session: LessonSession, reviewMode: Bool) {
        self.lesson = lesson
        self.session = session
        self.reviewMode = reviewMode

        var built: [Block] = []
        var pages: [LessonPage] = []
        func flushPages() {
            if !pages.isEmpty {
                built.append(.reading(pages))
                pages = []
            }
        }
        for step in session.steps {
            switch step {
            case .page(let page):
                pages.append(page)
            case .quiz(let ids):
                flushPages()
                if !reviewMode {
                    let available = ids.filter { QuestionBank.shared.hasQuestion(id: $0) }
                    if !available.isEmpty {
                        built.append(.quiz(ids: available, isSessionQuiz: false))
                    }
                }
            case .sessionQuiz(let ids):
                flushPages()
                if !reviewMode {
                    let available = ids.filter { QuestionBank.shared.hasQuestion(id: $0) }
                    if !available.isEmpty {
                        built.append(.quiz(ids: available, isSessionQuiz: true))
                    }
                }
            }
        }
        flushPages()
        self.blocks = built
        self.quizUnit = LearningUnit(
            id: lesson.unitId,
            title: lesson.title,
            order: 0,
            stage: .review,
            description: "",
            questions: [],
            boss: nil
        )

        if !reviewMode {
            let resume = LessonProgressStore.resumeIndex(lesson.unitId, session: session.number)
            if resume > 0, resume < built.count {
                blockIndex = resume
            }
        }
        enterBlock()
    }

    // MARK: - 状態

    var stage: Stage {
        if isFinished { return .finished }
        return quizSession == nil ? .reading : .quiz
    }

    private var currentBlock: Block? {
        blockIndex < blocks.count ? blocks[blockIndex] : nil
    }

    var currentPages: [LessonPage] {
        guard let block = currentBlock, case .reading(let pages) = block else { return [] }
        return pages
    }

    var isSessionQuizBlock: Bool {
        guard let block = currentBlock, case .quiz(_, let isSession) = block else { return false }
        return isSession
    }

    /// ブロック単位の進み具合（0.0〜1.0）
    var progress: Double {
        blocks.isEmpty ? 1 : Double(blockIndex) / Double(blocks.count)
    }

    /// 説明ブロックの最後のページに出すボタンの文言
    var nextActionTitle: String {
        let next = blockIndex + 1
        guard next < blocks.count else { return "セッションを終える" }
        switch blocks[next] {
        case .reading: return "次へ"
        case .quiz(_, let isSession): return isSession ? "まとめ問題へ" : "問題に挑戦"
        }
    }

    var quizProgressLabel: String {
        let kind = isSessionQuizBlock ? "まとめ問題" : "チェック問題"
        let base = "\(kind) \(questionCursor + 1) / \(questionIds.count)"
        return attempt == 2 ? base + "　もう一度！" : base
    }

    // MARK: - 進行

    private func enterBlock() {
        guard let block = currentBlock else {
            finish()
            return
        }
        pageIndex = 0
        switch block {
        case .reading:
            quizSession = nil
        case .quiz(let ids, _):
            questionIds = ids
            questionCursor = 0
            attempt = 1
            blockCorrect = 0
            blockAnswered = 0
            startQuestion()
        }
    }

    private func startQuestion() {
        while questionCursor < questionIds.count {
            if let question = QuestionBank.shared.instantiate(id: questionIds[questionCursor]) {
                quizSession = QuizSession(unit: quizUnit, questions: [question])
                return
            }
            questionCursor += 1
        }
        completeQuizBlock()
    }

    /// 説明ブロックの最後のページで「次へ」
    func advanceFromReading() {
        guard stage == .reading else { return }
        blockIndex += 1
        enterBlock()
    }

    /// 問題の「次へ」で quizSession が終わったら呼ぶ。
    /// 正解 → 次の問題。不正解 → 同じ問題をもう一度（template は数値が変わる）。2 回目も不正解 → 先へ。
    func quizStepFinished() {
        guard let quizSession, quizSession.isFinished else { return }
        if quizSession.isPerfect {
            resolve(correct: true)
        } else if attempt == 1 {
            attempt = 2
            startQuestion()
        } else {
            resolve(correct: false)
        }
    }

    private func resolve(correct: Bool) {
        blockAnswered += 1
        totalAnswered += 1
        if correct {
            blockCorrect += 1
            totalCorrect += 1
        }
        questionCursor += 1
        attempt = 1
        startQuestion()
    }

    private func completeQuizBlock() {
        if isSessionQuizBlock {
            sessionQuizCorrect = blockCorrect
            sessionQuizTotal = blockAnswered
        }
        quizSession = nil
        blockIndex += 1
        if !reviewMode {
            // ルール: 途中で閉じたら「最後に終えた問題画面の直後」から再開
            LessonProgressStore.setResumeIndex(lesson.unitId, session: session.number, blockIndex)
        }
        enterBlock()
    }

    var needsReview: Bool {
        sessionQuizTotal > 0 && Double(sessionQuizCorrect) / Double(sessionQuizTotal) < 0.8
    }

    private func finish() {
        isFinished = true
        quizSession = nil
        guard !reviewMode else { return }
        LessonProgressStore.setCompleted(lesson.unitId, session: session.number, true)
        LessonProgressStore.clearResume(lesson.unitId, session: session.number)
        LessonProgressStore.setNeedsReview(lesson.unitId, session: session.number, needsReview)
    }
}
