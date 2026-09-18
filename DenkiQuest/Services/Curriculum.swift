import Foundation

/// docs/curriculum.md のステージ構成。教材（lessons）の並び順はここを正とする。
enum Curriculum {
    struct Stage {
        let number: Int
        let title: String
        /// docs/curriculum.md に書かれている順序そのまま。
        let unitIds: [String]
    }

    /// 単元一覧に出すひとまとまり。教材が存在する単元だけを含む。
    struct Section: Identifiable {
        let title: String
        let lessons: [Lesson]

        var id: String { title }
    }

    /// 現在アプリに載せているステージ。ステージ1以降は教材ができ次第ここに足す。
    static let stages: [Stage] = [
        Stage(
            number: 0,
            title: "ステージ 0　電気の基礎",
            unitIds: ["F01", "F02", "F03", "F04", "F05", "F06",
                      "F07", "F08", "F09", "F10", "F11", "F12"]
        ),
        Stage(number: 1, title: "ステージ 1　図記号・器具・材料・工具",
              unitIds: ["S01", "S02", "S03", "S04", "S05", "S06", "S07", "S08"]),
        Stage(number: 2, title: "ステージ 2　配線図",
              unitIds: ["W01", "W02", "W03", "W04", "W05", "W06"]),
        Stage(number: 3, title: "ステージ 3　施工方法・検査・法令",
              unitIds: ["K01", "K02", "K03", "K04", "K05", "K06", "K07", "K08", "K09"]),
        Stage(number: 4, title: "ステージ 4　配電理論と配線設計",
              unitIds: ["D01", "D02", "D03", "D04", "D05", "D06"]),
        Stage(number: 5, title: "ステージ 5　技能試験",
              unitIds: ["G01", "G02", "G03", "G04", "G05"]),
    ]

    /// 読み込んだ教材をカリキュラム順に並べ替える。
    /// どのステージにも載っていない単元は末尾にまとめる（教材を隠さないため）。
    static func sections(for lessons: [Lesson]) -> [Section] {
        let byUnitId = Dictionary(lessons.map { ($0.unitId, $0) }, uniquingKeysWith: { first, _ in first })
        var placed: Set<String> = []
        var sections: [Section] = []

        for stage in stages {
            let ordered = stage.unitIds.compactMap { byUnitId[$0] }
            guard !ordered.isEmpty else { continue }
            placed.formUnion(ordered.map(\.unitId))
            sections.append(Section(title: stage.title, lessons: ordered))
        }

        let rest = lessons.filter { !placed.contains($0.unitId) }
        if !rest.isEmpty {
            sections.append(Section(title: "未分類", lessons: rest))
        }
        return sections
    }
}
