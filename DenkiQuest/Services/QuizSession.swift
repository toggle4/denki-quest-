import Foundation
import Observation

/// 1 セッション（10 問）の進行状態。
@Observable
final class QuizSession {
    /// 選択肢をシャッフルした出題 1 件。
    struct Item: Identifiable {
        let id: String
        let question: Question
        let choices: [String]
        let correctIndex: Int
    }

    static let questionsPerSession = 10

    let unit: LearningUnit
    let items: [Item]

    private(set) var currentIndex = 0
    private(set) var selectedIndex: Int?
    private(set) var correctCount = 0
    private(set) var isFinished = false

    init(unit: LearningUnit, questionCount: Int = QuizSession.questionsPerSession) {
        self.unit = unit
        let picked = unit.questions.shuffled().prefix(questionCount)
        self.items = picked.map { question in
            let order = Array(question.choices.indices).shuffled()
            let shuffledChoices = order.map { question.choices[$0] }
            let correct = order.firstIndex(of: question.answer) ?? 0
            return Item(
                id: question.id,
                question: question,
                choices: shuffledChoices,
                correctIndex: correct
            )
        }
    }

    var current: Item? {
        items.indices.contains(currentIndex) ? items[currentIndex] : nil
    }

    var hasAnswered: Bool { selectedIndex != nil }

    /// 回答済みの問題数の割合（0.0〜1.0）。
    var progress: Double {
        guard !items.isEmpty else { return 0 }
        let answered = currentIndex + (hasAnswered ? 1 : 0)
        return Double(answered) / Double(items.count)
    }

    var isCurrentCorrect: Bool {
        guard let selectedIndex, let current else { return false }
        return selectedIndex == current.correctIndex
    }

    func select(_ index: Int) {
        guard !hasAnswered, let current else { return }
        selectedIndex = index
        if index == current.correctIndex {
            correctCount += 1
        }
    }

    func next() {
        guard hasAnswered else { return }
        selectedIndex = nil
        if currentIndex + 1 < items.count {
            currentIndex += 1
        } else {
            isFinished = true
        }
    }
}
