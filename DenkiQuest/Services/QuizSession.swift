import Foundation
import Observation

/// 1 セッション（10 問）の進行状態。
@Observable
final class QuizSession {
    /// 選択肢をシャッフルした出題 1 件。
    struct Item: Identifiable {
        let id: String
        let question: Question
        /// choice のときだけ使う（シャッフル済み）
        let choices: [String]
        let correctIndex: Int
    }

    static let questionsPerSession = 10

    let unit: LearningUnit
    let items: [Item]

    private(set) var currentIndex = 0
    /// nil = 未回答、true/false = 正誤
    private(set) var lastResult: Bool?
    private(set) var selectedIndex: Int?
    private(set) var selectedBool: Bool?
    private(set) var enteredNumber: Double?
    private(set) var hintUsed = false

    private(set) var correctCount = 0
    private(set) var hintCount = 0
    private(set) var isFinished = false
    /// 現在の連続正解数。間違えると 0 に戻る。ヒント使用時は増えない。
    private(set) var combo = 0
    /// セッション中の最大連続正解数。
    private(set) var maxCombo = 0

    /// 単元からランダムに questionCount 問を選ぶ（ドリル用）。
    convenience init(unit: LearningUnit, questionCount: Int = QuizSession.questionsPerSession) {
        self.init(unit: unit, questions: Array(unit.questions.shuffled().prefix(questionCount)))
    }

    /// 指定した問題をその順で出す（教材の差し込み問題用）。
    init(unit: LearningUnit, questions: [Question]) {
        self.unit = unit
        self.items = questions.map(Self.makeItem)
    }

    static func makeItem(_ question: Question) -> Item {
        guard question.type == .choice else {
            return Item(id: question.id, question: question, choices: [], correctIndex: 0)
        }
        let order = Array(question.choices.indices).shuffled()
        let shuffledChoices = order.map { question.choices[$0] }
        let correct = order.firstIndex(of: question.answerIndex) ?? 0
        return Item(id: question.id, question: question, choices: shuffledChoices, correctIndex: correct)
    }

    var current: Item? {
        items.indices.contains(currentIndex) ? items[currentIndex] : nil
    }

    var hasAnswered: Bool { lastResult != nil }
    var isCurrentCorrect: Bool { lastResult == true }
    var isPerfect: Bool { !items.isEmpty && correctCount == items.count }

    /// 回答済みの問題数の割合（0.0〜1.0）。
    var progress: Double {
        guard !items.isEmpty else { return 0 }
        let answered = currentIndex + (hasAnswered ? 1 : 0)
        return Double(answered) / Double(items.count)
    }

    func useHint() {
        guard !hasAnswered, !hintUsed, current?.question.hint != nil else { return }
        hintUsed = true
        hintCount += 1
    }

    // MARK: - 回答

    func answerChoice(_ index: Int) {
        guard !hasAnswered, let current, current.question.type == .choice else { return }
        selectedIndex = index
        record(correct: index == current.correctIndex)
    }

    func answerBool(_ value: Bool) {
        guard !hasAnswered, let current, current.question.type == .truefalse else { return }
        selectedBool = value
        record(correct: value == current.question.answerBool)
    }

    func answerNumber(_ value: Double) {
        guard !hasAnswered, let current, current.question.type == .number else { return }
        enteredNumber = value
        record(correct: current.question.isCorrectNumber(value))
    }

    private func record(correct: Bool) {
        lastResult = correct
        if correct {
            correctCount += 1
            if !hintUsed {
                combo += 1
                maxCombo = max(maxCombo, combo)
            }
        } else {
            combo = 0
        }
    }

    func next() {
        guard hasAnswered else { return }
        lastResult = nil
        selectedIndex = nil
        selectedBool = nil
        enteredNumber = nil
        hintUsed = false
        if currentIndex + 1 < items.count {
            currentIndex += 1
        } else {
            isFinished = true
        }
    }
}
