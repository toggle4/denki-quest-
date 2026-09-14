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
    let id: String
    let type: QuestionType
    let prompt: String
    let choices: [String]
    let answer: Int
    let explanation: String
    let image: String?

    enum QuestionType: String, Codable {
        /// 4 択（単一正解）
        case choice
    }
}
