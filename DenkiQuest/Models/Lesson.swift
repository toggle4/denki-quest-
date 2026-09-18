import Foundation

/// content/lessons/<unitId>.md をパースした結果。
struct Lesson: Identifiable, Hashable {
    /// 単元ID（F02 など）
    let unitId: String
    /// 単元タイトル（見出し `# F02 …` の残り）
    let title: String
    /// `> 目標：…` の中身
    let goal: String?
    let sessions: [LessonSession]

    var id: String { unitId }
}

/// `## セッションN：…` ひとつ分。説明画面と差し込み問題が順に並ぶ。
struct LessonSession: Identifiable, Hashable {
    let number: Int
    let title: String
    /// 説明画面と問題（差し込み・まとめ）が教材の順に並ぶ
    let steps: [LessonStep]

    var id: Int { number }

    /// 説明画面だけ
    var pages: [LessonPage] {
        steps.compactMap { step in
            if case .page(let page) = step { return page }
            return nil
        }
    }

    /// このセッションで出す問題の ID（差し込み + まとめ）
    var quizQuestionIds: [String] {
        steps.flatMap { step -> [String] in
            switch step {
            case .quiz(let ids), .sessionQuiz(let ids): return ids
            case .page: return []
            }
        }
    }

    var hasQuiz: Bool { !quizQuestionIds.isEmpty }
}

/// セッション内の 1 ステップ。
enum LessonStep: Hashable {
    /// スワイプで送る 1 画面（1 画面 1 概念）
    case page(LessonPage)
    /// `<!-- quiz: id, id -->` 直前の説明画面のあとに出す問題
    case quiz([String])
    /// `<!-- session-quiz: id, … -->` セッション末のまとめ問題
    case sessionQuiz([String])
}

/// スワイプで送る1画面（1画面1概念）。
struct LessonPage: Identifiable, Hashable {
    let index: Int
    let blocks: [LessonBlock]

    var id: Int { index }
}

/// 画面を構成する要素。
enum LessonBlock: Hashable {
    case paragraph(String)
    /// 行全体が `**…**` のもの（**まとめ** / **例題** / 公式の強調）
    case strongLine(String)
    case bulletList([String])
    case orderedList([String])
    case table(LessonTable)
    case callout(LessonCallout)
    /// `<!-- figure: 名前 -->`。Assets の <名前> を指す。
    case figure(String)
}

struct LessonTable: Hashable {
    let headers: [String]
    let rows: [[String]]

    /// 全行のうち最も列数の多いものに合わせる。
    var columnCount: Int {
        max(headers.count, rows.map(\.count).max() ?? 0)
    }

    func cell(_ row: [String], _ column: Int) -> String {
        column < row.count ? row[column] : ""
    }
}

struct LessonCallout: Hashable {
    /// 行頭の絵文字（⚠️ / 🔌 など）。無ければ nil。
    let icon: String?
    let text: String
}

/// 教材のセッション画面へ遷移するときの値。
struct LessonSessionRoute: Hashable {
    let lesson: Lesson
    let session: LessonSession
    /// 読了済みセッションを説明だけで読み直す
    let reviewMode: Bool
}
