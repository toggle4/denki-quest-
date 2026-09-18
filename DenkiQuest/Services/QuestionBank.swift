import Foundation

/// 新形式（schemaVersion 2）の問題データ。教材の差し込み問題はここから取り出す。
final class QuestionBank {
    static let shared = QuestionBank()

    private(set) var files: [String: UnitFileV2] = [:]
    private var questionsById: [String: QuestionV2] = [:]

    private init() {
        reload()
    }

    func reload() {
        let decoder = JSONDecoder()
        var loaded: [String: UnitFileV2] = [:]
        var byId: [String: QuestionV2] = [:]
        for url in ContentFiles.unitFileURLs() where ContentFiles.schemaVersion(of: url) == 2 {
            do {
                let data = try Data(contentsOf: url)
                let file = try decoder.decode(UnitFileV2.self, from: data)
                loaded[file.unit.id] = file
                for question in file.questions {
                    byId[question.id] = question
                }
            } catch {
                print("QuestionBank: \(url.lastPathComponent) を読めません: \(error)")
            }
        }
        files = loaded
        questionsById = byId
    }

    func hasQuestions(unitId: String) -> Bool {
        files[unitId] != nil
    }

    func hasQuestion(id: String) -> Bool {
        questionsById[id] != nil
    }

    func question(id: String) -> QuestionV2? {
        questionsById[id]
    }

    /// 出題用に旧ゲームの Question に変換する。template は呼ぶたびに数値が変わる。
    func instantiate(id: String) -> Question? {
        guard let source = questionsById[id] else { return nil }
        return QuestionFactory.make(from: source)
    }
}

/// 新形式の 1 問を、旧ゲームの出題 UI が扱う Question に変換する。
enum QuestionFactory {
    static func make(from source: QuestionV2) -> Question? {
        switch source.type {
        case "multipleChoice":
            guard let choices = source.choices,
                  let index = source.answerIndex,
                  choices.indices.contains(index) else { return nil }
            return Question(
                id: source.id,
                type: .choice,
                prompt: source.prompt,
                explanation: source.explanation,
                choices: choices,
                answerIndex: index
            )

        case "trueFalse":
            guard let flag = source.answerBool else { return nil }
            return Question(
                id: source.id,
                type: .truefalse,
                prompt: source.prompt,
                explanation: source.explanation,
                answerBool: flag
            )

        case "numericInput":
            guard let answer = source.answerNumber else { return nil }
            return Question(
                id: source.id,
                type: .number,
                prompt: source.prompt,
                explanation: source.explanation,
                answerNumber: answer,
                tolerance: source.tolerance ?? abs(answer) * 0.01,
                unit: source.unitLabel
            )

        case "template":
            return makeTemplate(source)

        default:
            // matching / imageChoice は未対応（schema.md 参照）
            return nil
        }
    }

    private static func makeTemplate(_ source: QuestionV2) -> Question? {
        guard let instance = TemplateEngine.generate(source) else { return nil }

        let roundTo = source.roundTo
        let scale = pow(10.0, Double(roundTo ?? 2))
        let rounded = (instance.answer * scale).rounded() / scale
        let answerText = TemplateEngine.format(rounded, roundTo: roundTo)
        let prompt = TemplateEngine.substitute(source.prompt, values: instance.values, answer: answerText)
        let explanation = TemplateEngine.substitute(source.explanation, values: instance.values, answer: answerText)
        let unitLabel = source.unitLabel

        if source.answerType == "choice" {
            let evaluator = ExpressionEvaluator(variables: instance.values)
            var seen: Set<String> = [answerText]
            var wrong: [String] = []

            for formula in source.distractors ?? [] {
                guard let value = try? evaluator.evaluate(formula), value.isFinite else { continue }
                let text = TemplateEngine.format((value * scale).rounded() / scale, roundTo: roundTo)
                if seen.insert(text).inserted {
                    wrong.append(text)
                }
            }
            // 誤答が正答と重なって足りないときの穴埋め
            let fallbacks = [rounded * 2, rounded / 2, rounded * 10, rounded + 1, rounded - 1, rounded * 3]
            for value in fallbacks where wrong.count < 3 {
                let text = TemplateEngine.format((value * scale).rounded() / scale, roundTo: roundTo)
                if seen.insert(text).inserted {
                    wrong.append(text)
                }
            }

            let label: (String) -> String = { text in
                if let unitLabel, !unitLabel.isEmpty {
                    return "\(text) \(unitLabel)"
                }
                return text
            }
            let choices = ([answerText] + wrong.prefix(3)).map(label)
            return Question(
                id: source.id,
                type: .choice,
                prompt: prompt,
                explanation: explanation,
                choices: choices,
                answerIndex: 0
            )
        }

        let tolerance = Swift.max(source.tolerance ?? abs(rounded) * 0.01, 0.5 / scale)
        return Question(
            id: source.id,
            type: .number,
            prompt: prompt,
            explanation: explanation,
            answerNumber: rounded,
            tolerance: tolerance,
            unit: unitLabel
        )
    }
}
