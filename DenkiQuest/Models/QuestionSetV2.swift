import Foundation

/// content/schema.md の新形式（schemaVersion 2）。1 ファイル 1 単元。
struct UnitFileV2: Decodable {
    struct UnitMeta: Decodable {
        let id: String
        let stage: Int?
        let order: Int?
        let title: String
        let lessonFile: String?
        let prerequisites: [String]?
        let masteryThreshold: Double?
    }

    struct Boss: Decodable {
        let id: String?
        let title: String?
        let description: String?
        let questionIds: [String]
        let pick: Int?
        let timeLimitSeconds: Int
    }

    let schemaVersion: Int
    let unit: UnitMeta
    let questions: [QuestionV2]
    let boss: Boss?
}

/// template 問題の変数の範囲。
struct VariableSpec: Decodable {
    let min: Double
    let max: Double
    let step: Double?
}

/// 新形式の 1 問。type ごとに使うフィールドが違うので、すべて optional で持つ。
struct QuestionV2: Decodable, Identifiable {
    let id: String
    let type: String
    let difficulty: Int
    let prompt: String
    let explanation: String
    let tags: [String]
    let srsWeight: Double
    let figure: String?
    let hint: String?
    /// 英語の語源・略語の意味
    let origin: String?
    /// 現場での豆知識
    let tip: String?

    // multipleChoice / imageChoice
    let choices: [String]?
    let answerIndex: Int?
    // trueFalse
    let answerBool: Bool?
    // numericInput
    let answerNumber: Double?
    let unitLabel: String?
    let tolerance: Double?
    // template
    let variables: [String: VariableSpec]?
    let constraints: [String]?
    let answerFormula: String?
    let answerType: String?
    let roundTo: Int?
    let distractors: [String]?

    private enum CodingKeys: String, CodingKey {
        case id, type, difficulty, prompt, explanation, tags, srsWeight, figure, hint, origin, tip
        case choices, answerIndex, answer, unitLabel, tolerance
        case variables, constraints, answerFormula, answerType, roundTo, distractors
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(String.self, forKey: .type)
        difficulty = try c.decodeIfPresent(Int.self, forKey: .difficulty) ?? 1
        prompt = try c.decode(String.self, forKey: .prompt)
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        srsWeight = try c.decodeIfPresent(Double.self, forKey: .srsWeight) ?? 1.0
        figure = try c.decodeIfPresent(String.self, forKey: .figure)
        hint = try c.decodeIfPresent(String.self, forKey: .hint)
        origin = try c.decodeIfPresent(String.self, forKey: .origin)
        tip = try c.decodeIfPresent(String.self, forKey: .tip)

        choices = try c.decodeIfPresent([String].self, forKey: .choices)
        answerIndex = try c.decodeIfPresent(Int.self, forKey: .answerIndex)
        unitLabel = try c.decodeIfPresent(String.self, forKey: .unitLabel)
        tolerance = try c.decodeIfPresent(Double.self, forKey: .tolerance)

        // answer は type によって bool か number
        if let flag = try? c.decodeIfPresent(Bool.self, forKey: .answer) {
            answerBool = flag
            answerNumber = nil
        } else if let number = try? c.decodeIfPresent(Double.self, forKey: .answer) {
            answerBool = nil
            answerNumber = number
        } else {
            answerBool = nil
            answerNumber = nil
        }

        variables = try c.decodeIfPresent([String: VariableSpec].self, forKey: .variables)
        constraints = try c.decodeIfPresent([String].self, forKey: .constraints)
        answerFormula = try c.decodeIfPresent(String.self, forKey: .answerFormula)
        answerType = try c.decodeIfPresent(String.self, forKey: .answerType)
        roundTo = try c.decodeIfPresent(Int.self, forKey: .roundTo)
        distractors = try c.decodeIfPresent([String].self, forKey: .distractors)
    }
}
