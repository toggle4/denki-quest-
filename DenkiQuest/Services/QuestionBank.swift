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

    /// 教材（lessons）を持たない新形式ファイル = 試験型ドリル。ステージ・順番で並べる。
    func drillFiles(excludingLessonIds lessonIds: Set<String>) -> [UnitFileV2] {
        files.values
            .filter { !lessonIds.contains($0.unit.id) }
            .sorted {
                let a = ($0.unit.stage ?? 99, $0.unit.order ?? 99, $0.unit.id)
                let b = ($1.unit.stage ?? 99, $1.unit.order ?? 99, $1.unit.id)
                return a < b
            }
    }

    /// ドリル用に旧ゲームの LearningUnit を組み立てる。
    /// template 問題は数値を変えて 3 回ずつ生成し、セッションのたびに違う数値が出るようにする。
    func makeDrillUnit(from file: UnitFileV2) -> LearningUnit {
        var questions: [Question] = []
        for source in file.questions {
            let copies = source.type == "template" ? 3 : 1
            for k in 0..<copies {
                guard var q = QuestionFactory.make(from: source) else { continue }
                if copies > 1 {
                    q = Question(
                        id: "\(q.id)#\(k)", type: q.type, prompt: q.prompt, explanation: q.explanation,
                        hint: q.hint, image: q.image, origin: q.origin, tip: q.tip, choices: q.choices, answerIndex: q.answerIndex,
                        choiceImages: q.choiceImages,
                        answerBool: q.answerBool, answerNumber: q.answerNumber, tolerance: q.tolerance, unit: q.unit
                    )
                }
                questions.append(q)
            }
        }
        return LearningUnit(
            id: file.unit.id,
            title: file.unit.title,
            order: file.unit.order ?? 0,
            stage: Self.legacyStage(for: file.unit.stage ?? 0),
            description: file.boss?.description ?? "過去の出題パターンをもとにした試験型ドリル。",
            questions: questions,
            boss: file.boss.map { BossConfig(questionCount: $0.pick ?? 5, timeLimitSeconds: $0.timeLimitSeconds) }
        )
    }

    /// 教材つき単元（F02 など）のボス戦用。boss.questionIds を出題に変換する。
    func makeBossUnit(unitId: String, title: String) -> LearningUnit? {
        guard let file = files[unitId], let boss = file.boss else { return nil }
        let questions = boss.questionIds.compactMap { instantiate(id: $0) }
        guard !questions.isEmpty else { return nil }
        return LearningUnit(
            id: unitId,
            title: title,
            order: file.unit.order ?? 0,
            stage: Self.legacyStage(for: file.unit.stage ?? 0),
            description: boss.description ?? "",
            questions: questions,
            boss: BossConfig(questionCount: boss.pick ?? 5, timeLimitSeconds: boss.timeLimitSeconds)
        )
    }

    private static func legacyStage(for stage: Int) -> LearningUnit.Stage {
        switch stage {
        case 0: return .review
        case 4: return .calculate
        case 5: return .practical
        default: return .memorize
        }
    }

    static func stageTitle(_ stage: Int?) -> String {
        switch stage {
        case 0: return "ステージ 0　電気の基礎"
        case 1: return "ステージ 1　図記号・器具・材料・工具"
        case 2: return "ステージ 2　配線図"
        case 3: return "ステージ 3　施工方法・検査・法令"
        case 4: return "ステージ 4　配電理論と配線設計"
        case 5: return "ステージ 5　技能試験"
        default: return "その他"
        }
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
                hint: source.hint,
                image: source.figure,
                origin: source.origin,
                tip: source.tip,
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
                hint: source.hint,
                image: source.figure,
                origin: source.origin,
                tip: source.tip,
                answerBool: flag
            )

        case "numericInput":
            guard let answer = source.answerNumber else { return nil }
            return Question(
                id: source.id,
                type: .number,
                prompt: source.prompt,
                explanation: source.explanation,
                hint: source.hint,
                image: source.figure,
                origin: source.origin,
                tip: source.tip,
                answerNumber: answer,
                tolerance: source.tolerance ?? abs(answer) * 0.01,
                unit: source.unitLabel
            )

        case "template":
            return makeTemplate(source)

        case "imageChoice":
            return makeImageChoice(source)

        default:
            // matching は未対応（schema.md 参照）
            return nil
        }
    }

    /// imageChoice。choiceImages があれば図の中から選ぶ（名前 → 図）。
    /// なければ figure の図を見て、文字の choices から選ぶ（図 → 名前）。
    private static func makeImageChoice(_ source: QuestionV2) -> Question? {
        guard let index = source.answerIndex else { return nil }
        if let images = source.choiceImages, images.count >= 2 {
            guard images.indices.contains(index) else { return nil }
            let names = source.choices ?? []
            let captions = images.indices.map { names.indices.contains($0) ? names[$0] : "" }
            return Question(
                id: source.id,
                type: .choice,
                prompt: source.prompt,
                explanation: source.explanation,
                hint: source.hint,
                image: source.figure,
                origin: source.origin,
                tip: source.tip,
                choices: captions,
                answerIndex: index,
                choiceImages: images
            )
        }
        guard let choices = source.choices, choices.indices.contains(index), source.figure != nil else { return nil }
        return Question(
            id: source.id,
            type: .choice,
            prompt: source.prompt,
            explanation: source.explanation,
            hint: source.hint,
            image: source.figure,
            origin: source.origin,
            tip: source.tip,
            choices: choices,
            answerIndex: index
        )
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
                hint: source.hint,
                image: source.figure,
                origin: source.origin,
                tip: source.tip,
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
            hint: source.hint,
            image: source.figure,
            origin: source.origin,
            tip: source.tip,
            answerNumber: rounded,
            tolerance: tolerance,
            unit: unitLabel
        )
    }
}
