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
        /// 教材のないファイル（試験型ドリル）を、ホームでこの旧単元の直後に並べる
        let legacyUnit: String?
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

/// template 問題の途中の値。変数から式で計算し、問題文・解説・答えの式で {名前} として使える。
/// 並べた順に計算するので、前の途中の値を後ろの式で使ってよい。
struct DerivedSpec: Decodable {
    let name: String
    let formula: String
    /// 丸める桁数。丸めた値を以降の計算にも使う（表示と計算を一致させる）
    let roundTo: Int?
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
    /// imageChoice で、選択肢を図（Assets の名前）にするとき。choices は回答後に出す名前
    let choiceImages: [String]?
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
    let derived: [DerivedSpec]?

    private enum CodingKeys: String, CodingKey {
        case id, type, difficulty, prompt, explanation, tags, srsWeight, figure, hint, origin, tip
        case choices, answerIndex, answer, unitLabel, tolerance, choiceImages
        case variables, constraints, answerFormula, answerType, roundTo, distractors, derived
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
        choiceImages = try c.decodeIfPresent([String].self, forKey: .choiceImages)
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
        derived = try c.decodeIfPresent([DerivedSpec].self, forKey: .derived)
    }
}
