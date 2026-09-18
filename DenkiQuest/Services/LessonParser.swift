import Foundation

/// content/lessons/*.md を Lesson に変換する。
///
/// 対応する記法（content/lessons/README.md）:
/// - `# F02 タイトル`               単元見出し
/// - `> 目標：…`                    単元の目標（最初の `##` より前にあるもの）
/// - `## セッションN：タイトル`      セッション
/// - `---`                          セッション内の画面区切り
/// - `<!-- quiz: id, id -->`        差し込み問題（直前の画面のあと）
/// - `<!-- session-quiz: id, … -->` セッション末のまとめ問題
/// - `<!-- figure: 名前 -->`         図
/// - `> …`（連続行は1つにまとめる）   注意・実務メモ
/// - 表 / `- ` / `1. ` / `**…**` / 段落
enum LessonParser {

    static func parse(_ markdown: String, fallbackUnitId: String) -> Lesson {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        var unitId = fallbackUnitId
        var title = fallbackUnitId
        var goal: String?
        var sessions: [LessonSession] = []

        var sessionNumber: Int?
        var sessionTitle = ""
        var sessionBody: [String] = []

        func flushSession() {
            guard let number = sessionNumber else { return }
            sessions.append(
                LessonSession(number: number, title: sessionTitle, steps: makeSteps(from: sessionBody))
            )
            sessionNumber = nil
            sessionTitle = ""
            sessionBody = []
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("# ") {
                let (id, name) = parseUnitHeading(String(line.dropFirst(2)))
                if let id { unitId = id }
                title = name
                continue
            }

            if line.hasPrefix("## ") {
                flushSession()
                let (number, name) = parseSessionHeading(String(line.dropFirst(3)),
                                                         defaultNumber: sessions.count + 1)
                sessionNumber = number
                sessionTitle = name
                continue
            }

            if sessionNumber == nil {
                // 単元見出しと最初のセッションの間。目標だけ拾う。
                if goal == nil, line.hasPrefix(">") {
                    let body = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                    goal = body.hasPrefix("目標：") ? String(body.dropFirst(3)) : body
                }
                continue
            }

            sessionBody.append(raw)
        }
        flushSession()

        return Lesson(unitId: unitId, title: title, goal: goal, sessions: sessions)
    }

    // MARK: - 見出し

    /// `F02 電流・電圧・抵抗とオームの法則` → ("F02", "電流・電圧・抵抗とオームの法則")
    private static func parseUnitHeading(_ text: String) -> (String?, String) {
        let body = text.trimmingCharacters(in: .whitespaces)
        let parts = body.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let head = parts.first, isUnitId(String(head)) else { return (nil, body) }
        let rest = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
        return (String(head), rest.isEmpty ? String(head) : rest)
    }

    /// 英大文字1〜2字 + 数字2字（F02, S01, W01, K01, D01, G01）
    private static func isUnitId(_ text: String) -> Bool {
        let letters = text.prefix { $0.isUppercase && $0.isLetter }
        let digits = text.dropFirst(letters.count)
        return (1...2).contains(letters.count)
            && digits.count == 2
            && digits.allSatisfy(\.isNumber)
    }

    /// `セッション1：電流とは何か` → (1, "電流とは何か")
    private static func parseSessionHeading(_ text: String, defaultNumber: Int) -> (Int, String) {
        let body = text.trimmingCharacters(in: .whitespaces)
        let prefix = "セッション"
        guard body.hasPrefix(prefix), let separator = body.firstIndex(of: "：") else {
            return (defaultNumber, body)
        }
        let digits = body[body.index(body.startIndex, offsetBy: prefix.count)..<separator]
        let name = String(body[body.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        return (Int(digits) ?? defaultNumber, name)
    }

    // MARK: - 画面と問題の並び

    private static func makeSteps(from lines: [String]) -> [LessonStep] {
        var steps: [LessonStep] = []
        var pageCount = 0
        var current: [String] = []

        func flushPage() {
            let blocks = parseBlocks(current)
            if !blocks.isEmpty {
                steps.append(.page(LessonPage(index: pageCount, blocks: blocks)))
                pageCount += 1
            }
            current = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isPageBreak(trimmed) {
                flushPage()
            } else if let marker = quizMarker(trimmed) {
                flushPage()
                if !marker.ids.isEmpty {
                    steps.append(marker.isSessionQuiz ? .sessionQuiz(marker.ids) : .quiz(marker.ids))
                }
            } else {
                current.append(line)
            }
        }
        flushPage()
        return steps
    }

    /// 表の区切り行（`|---|`）と区別するため、`-` だけで構成された3文字以上の行のみ。
    private static func isPageBreak(_ line: String) -> Bool {
        line.count >= 3 && line.allSatisfy { $0 == "-" }
    }

    /// `<!-- quiz: F02-s1-q1, F02-s1-q2 -->` / `<!-- session-quiz: … -->`
    private static func quizMarker(_ line: String) -> (isSessionQuiz: Bool, ids: [String])? {
        guard let inner = commentBody(line) else { return nil }
        let isSession: Bool
        let rest: String
        if inner.hasPrefix("session-quiz:") {
            isSession = true
            rest = String(inner.dropFirst("session-quiz:".count))
        } else if inner.hasPrefix("quiz:") {
            isSession = false
            rest = String(inner.dropFirst("quiz:".count))
        } else {
            return nil
        }
        let ids = rest
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return (isSession, ids)
    }

    /// `<!-- … -->` の中身
    private static func commentBody(_ line: String) -> String? {
        guard line.hasPrefix("<!--"), line.hasSuffix("-->") else { return nil }
        return String(line.dropFirst(4).dropLast(3)).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - ブロック

    private static func parseBlocks(_ lines: [String]) -> [LessonBlock] {
        var blocks: [LessonBlock] = []
        var index = 0

        func trimmed(_ offset: Int) -> String {
            lines[offset].trimmingCharacters(in: .whitespaces)
        }

        while index < lines.count {
            let line = trimmed(index)

            if line.isEmpty {
                index += 1
                continue
            }

            if let name = figureName(line) {
                blocks.append(.figure(name))
                index += 1
                continue
            }

            // figure 以外のコメントは読み飛ばす
            if line.hasPrefix("<!--") {
                index += 1
                continue
            }

            if line.hasPrefix(">") {
                var quoted: [String] = []
                while index < lines.count, trimmed(index).hasPrefix(">") {
                    quoted.append(String(trimmed(index).dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(.callout(makeCallout(quoted.joined(separator: "\n"))))
                continue
            }

            if line.hasPrefix("|") {
                var rows: [[String]] = []
                while index < lines.count, trimmed(index).hasPrefix("|") {
                    rows.append(splitTableRow(trimmed(index)))
                    index += 1
                }
                if let table = makeTable(rows) {
                    blocks.append(.table(table))
                }
                continue
            }

            if isBulletItem(line) {
                var items: [String] = []
                while index < lines.count, isBulletItem(trimmed(index)) {
                    items.append(String(trimmed(index).dropFirst(2)).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(.bulletList(items))
                continue
            }

            if orderedItem(line) != nil {
                var items: [String] = []
                while index < lines.count, let item = orderedItem(trimmed(index)) {
                    items.append(item)
                    index += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            if let strong = strongOnlyText(line) {
                blocks.append(.strongLine(strong))
                index += 1
                continue
            }

            var paragraph: [String] = []
            while index < lines.count {
                let next = trimmed(index)
                if next.isEmpty || startsNewBlock(next) { break }
                paragraph.append(next)
                index += 1
            }
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            }
        }

        return blocks
    }

    private static func startsNewBlock(_ line: String) -> Bool {
        line.hasPrefix("#")
            || line.hasPrefix(">")
            || line.hasPrefix("|")
            || line.hasPrefix("<!--")
            || isBulletItem(line)
            || orderedItem(line) != nil
            || strongOnlyText(line) != nil
    }

    private static func isBulletItem(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ")
    }

    /// `1. 求めるのは電流 I。` → "求めるのは電流 I。"
    private static func orderedItem(_ line: String) -> String? {
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }
        return String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    /// 行全体がひと続きの `**…**` のときだけ中身を返す。
    private static func strongOnlyText(_ line: String) -> String? {
        guard line.hasPrefix("**"), line.hasSuffix("**"), line.count > 4 else { return nil }
        let inner = String(line.dropFirst(2).dropLast(2))
        guard !inner.contains("**") else { return nil }
        return inner
    }

    /// `<!-- figure: F02_ohm_triangle -->` → "F02_ohm_triangle"
    private static func figureName(_ line: String) -> String? {
        guard let inner = commentBody(line), inner.hasPrefix("figure:") else { return nil }
        let name = String(inner.dropFirst("figure:".count)).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private static func makeCallout(_ text: String) -> LessonCallout {
        // 数字や記号も isEmoji になるため、絵文字ブロック以降に限定する。
        guard let first = text.first,
              let scalar = first.unicodeScalars.first,
              scalar.properties.isEmoji,
              scalar.value > 0x238C
        else {
            return LessonCallout(icon: nil, text: text)
        }
        let body = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        return LessonCallout(icon: String(first), text: body)
    }

    private static func splitTableRow(_ line: String) -> [String] {
        var body = Substring(line)
        if body.hasPrefix("|") { body = body.dropFirst() }
        if body.hasSuffix("|") { body = body.dropLast() }
        return body.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func makeTable(_ rows: [[String]]) -> LessonTable? {
        guard let headers = rows.first else { return nil }
        var body = Array(rows.dropFirst())
        if let separator = body.first, isTableSeparator(separator) {
            body.removeFirst()
        }
        return LessonTable(headers: headers, rows: body)
    }

    /// `|---|---|` の行か。
    private static func isTableSeparator(_ row: [String]) -> Bool {
        !row.isEmpty && row.allSatisfy { cell in
            !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }
}
