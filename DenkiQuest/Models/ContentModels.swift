import Foundation

/// 1 単元分の教材。`content/units/*.json` の形式は `content/schema.md` を参照。
struct LearningUnit: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let order: Int
    let stage: Stage
    let description: String
    let questions: [Question]
    let boss: BossConfig?

    init(
        id: String,
        title: String,
        order: Int,
        stage: Stage,
        description: String,
        questions: [Question],
        boss: BossConfig?
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.stage = stage
        self.description = description
        self.questions = questions
        self.boss = boss
    }

    enum Stage: String, Codable {
        case review
        case memorize
        case calculate
        case practical

        var label: String {
            switch self {
            case .review: return "復習"
            case .memorize: return "暗記"
            case .calculate: return "計算"
            case .practical: return "技能"
            }
        }
    }
}

/// 単元末のボス戦の設定。
struct BossConfig: Codable, Hashable {
    let questionCount: Int
    let timeLimitSeconds: Int
}

/// 1 問分のデータ。出題形式ごとの追加キーは `content/schema.md` を参照。
struct Question: Codable, Identifiable, Hashable {
    enum QuestionType: String, Codable {
        /// 4 択（単一正解）
        case choice
        /// ○×
        case truefalse
        /// 数値入力
        case number
    }

    let id: String
    let type: QuestionType
    let prompt: String
    let explanation: String
    let hint: String?
    let image: String?

    // choice
    let choices: [String]
    let answerIndex: Int
    // truefalse
    let answerBool: Bool
    // number
    let answerNumber: Double
    let tolerance: Double
    let unit: String?

    private enum CodingKeys: String, CodingKey {
        case id, type, prompt, explanation, hint, image, choices, answer, tolerance, unit
    }

    /// コードから組み立てるとき（新形式・template 問題の変換など）に使う。
    init(
        id: String,
        type: QuestionType,
        prompt: String,
        explanation: String,
        hint: String? = nil,
        image: String? = nil,
        choices: [String] = [],
        answerIndex: Int = 0,
        answerBool: Bool = false,
        answerNumber: Double = 0,
        tolerance: Double = 0,
        unit: String? = nil
    ) {
        self.id = id
        self.type = type
        self.prompt = prompt
        self.explanation = explanation
        self.hint = hint
        self.image = image
        self.choices = choices
        self.answerIndex = answerIndex
        self.answerBool = answerBool
        self.answerNumber = answerNumber
        self.tolerance = tolerance
        self.unit = unit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(QuestionType.self, forKey: .type)
        prompt = try c.decode(String.self, forKey: .prompt)
        explanation = try c.decode(String.self, forKey: .explanation)
        hint = try c.decodeIfPresent(String.self, forKey: .hint)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        tolerance = try c.decodeIfPresent(Double.self, forKey: .tolerance) ?? 0

        switch type {
        case .choice:
            choices = try c.decode([String].self, forKey: .choices)
            answerIndex = try c.decode(Int.self, forKey: .answer)
            answerBool = false
            answerNumber = 0
        case .truefalse:
            choices = []
            answerIndex = 0
            answerBool = try c.decode(Bool.self, forKey: .answer)
            answerNumber = 0
        case .number:
            choices = []
            answerIndex = 0
            answerBool = false
            answerNumber = try c.decode(Double.self, forKey: .answer)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(prompt, forKey: .prompt)
        try c.encode(explanation, forKey: .explanation)
        try c.encodeIfPresent(hint, forKey: .hint)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encodeIfPresent(unit, forKey: .unit)
        switch type {
        case .choice:
            try c.encode(choices, forKey: .choices)
            try c.encode(answerIndex, forKey: .answer)
        case .truefalse:
            try c.encode(answerBool, forKey: .answer)
        case .number:
            try c.encode(answerNumber, forKey: .answer)
            try c.encode(tolerance, forKey: .tolerance)
        }
    }

    /// 数値入力の正誤判定。許容誤差込み。
    func isCorrectNumber(_ value: Double) -> Bool {
        abs(value - answerNumber) <= tolerance + 1e-9
    }
}
