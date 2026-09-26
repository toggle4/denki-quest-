import SwiftUI
import SwiftData

/// 苦手マップ。カリキュラムの単元を色のタイルで並べ、直近 30 問の正答率と復習待ちの数を示す。
/// タイルを押すと、その単元の教材（なければドリル）へ進む。
struct WeaknessMapView: View {
    let lessons: [Lesson]
    /// 旧形式のドリル（u01〜u16）
    let units: [LearningUnit]
    /// 教材のない新形式のドリル（E01 など）
    let examDrills: [UnitFileV2]

    @Query(sort: \StudyRecord.startedAt, order: .reverse) private var records: [StudyRecord]
    @Query(sort: \ReviewItem.dueAt) private var reviewItems: [ReviewItem]
    @State private var groups: [TileGroup] = []

    fileprivate enum Target {
        case lesson(Lesson)
        case drill(LearningUnit)
    }

    fileprivate struct Tile: Identifiable {
        let unitId: String
        let label: String
        let title: String
        /// nil = 教材も問題もまだない（準備中）
        let target: Target?
        var id: String { unitId }
    }

    fileprivate struct Focus: Identifiable {
        let tile: Tile
        let entry: WeaknessAnalyzer.Entry
        var id: String { tile.id }
    }

    fileprivate struct TileGroup: Identifiable {
        let title: String
        let tiles: [Tile]
        var id: String { title }
    }

    var body: some View {
        let _ = LessonProgressStore.changes.version
        let allTiles = groups.flatMap(\.tiles)
        let entries = WeaknessAnalyzer.entries(
            for: allTiles.map { (id: $0.unitId, title: $0.title) },
            records: records,
            reviews: reviewItems
        )
        ZStack {
            GameBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard(entries: Array(entries.values))
                    focusCard(tiles: allTiles, entries: entries)
                    tagsCard
                    ForEach(groups) { group in
                        section(group, entries: entries)
                    }
                    legend
                }
                .padding()
            }
        }
        .navigationTitle("苦手マップ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { groups = makeGroups() }
    }

    // MARK: - まとめ

    private func summaryCard(entries: [WeaknessAnalyzer.Entry]) -> some View {
        let levels: [WeaknessAnalyzer.Level] = [.weak, .almost, .strong, .few]
        return VStack(alignment: .leading, spacing: 10) {
            Label("単元ごとの手ごたえ", systemImage: "map.fill")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 8) {
                ForEach(levels, id: \.label) { level in
                    let count = entries.filter { $0.level == level }.count
                    VStack(spacing: 2) {
                        Text("\(count)")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(Self.color(level))
                        Text(level.label)
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Self.color(level).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            Text("色は各単元の直近 \(WeaknessAnalyzer.sampleSize) 問の正答率。\(WeaknessAnalyzer.minAnswers) 問未満はまだ判定しません。右上の赤い数字は復習待ちの問題数。")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .gameCard()
    }

    /// 苦手な単元のうち、見直す価値の大きいものを 3 つ。
    private func focusCard(tiles: [Tile], entries: [String: WeaknessAnalyzer.Entry]) -> some View {
        let focus: [Focus] = Array(tiles
            .compactMap { tile -> Focus? in
                guard tile.target != nil, let entry = entries[tile.unitId] else { return nil }
                let needsWork = entry.level == .weak || (entry.level == .almost && entry.pendingReviews > 0)
                return needsWork ? Focus(tile: tile, entry: entry) : nil
            }
            .sorted { $0.entry.priority < $1.entry.priority }
            .prefix(3))
        return VStack(alignment: .leading, spacing: 10) {
            Label("まず見直したい単元", systemImage: "scope")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if focus.isEmpty {
                Text("苦手な単元はまだありません。解いた問題が増えると、正答率の低い単元がここに出ます。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(focus) { item in
                    let tile = item.tile
                    let entry = item.entry
                    link(for: tile) {
                        HStack(spacing: 12) {
                            Text(tile.label)
                                .font(.subheadline.bold().monospaced())
                                .foregroundStyle(Theme.backgroundBottom)
                                .frame(width: 48, height: 36)
                                .background(Self.color(entry.level), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tile.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Text(detail(entry))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
                        }
                        .padding(10)
                        .background(Self.color(entry.level).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(16)
        .gameCard(tint: Theme.wrong.opacity(0.04), border: Theme.wrong.opacity(0.3))
    }

    @ViewBuilder
    private var tagsCard: some View {
        let tags = WeaknessAnalyzer.weakTags(reviewItems)
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("よく間違えるテーマ", systemImage: "exclamationmark.bubble.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(tags) { item in
                        HStack(spacing: 6) {
                            Text(item.tag)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text("×\(item.count)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(Theme.wrong)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.wrong.opacity(0.12), in: Capsule())
                    }
                }
                Text("復習待ちの問題を、間違えた回数で数えています。復習で正解して卒業すると消えます。")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .gameCard()
        }
    }

    // MARK: - タイル

    private func section(_ group: TileGroup, entries: [String: WeaknessAnalyzer.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                ForEach(group.tiles) { tile in
                    tileView(tile, entry: entries[tile.unitId])
                }
            }
        }
    }

    @ViewBuilder
    private func tileView(_ tile: Tile, entry: WeaknessAnalyzer.Entry?) -> some View {
        let level = entry?.level ?? .untried
        let color = Self.color(level)
        let content = VStack(spacing: 3) {
            Text(tile.label)
                .font(.subheadline.bold().monospaced())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(tile.target == nil ? "準備中" : percentText(entry))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(color.opacity(level == .untried ? 0.06 : 0.22), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(level == .untried ? 0.25 : 0.85), lineWidth: 1.5)
        )
        .overlay(alignment: .topTrailing) {
            if let pending = entry?.pendingReviews, pending > 0 {
                Text("\(pending)")
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.wrong, in: Capsule())
                    .offset(x: 4, y: -5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(tile.label) \(tile.title)、\(level.label)、\(percentText(entry))"))

        if tile.target != nil {
            link(for: tile) { content }
        } else {
            content.opacity(0.45)
        }
    }

    @ViewBuilder
    private func link<Content: View>(for tile: Tile, @ViewBuilder label: () -> Content) -> some View {
        switch tile.target {
        case .lesson(let lesson):
            NavigationLink(value: lesson, label: label)
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })
        case .drill(let unit):
            NavigationLink(value: unit, label: label)
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })
        case nil:
            label()
        }
    }

    private var legend: some View {
        let levels: [WeaknessAnalyzer.Level] = [.strong, .almost, .weak, .few, .untried]
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(levels, id: \.label) { level in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Self.color(level).opacity(level == .untried ? 0.25 : 0.8))
                        .frame(width: 16, height: 16)
                    Text("\(level.label)：\(legendText(level))")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 文言と色

    private func percentText(_ entry: WeaknessAnalyzer.Entry?) -> String {
        guard let entry, let accuracy = entry.accuracy else { return "—" }
        return "\(Int((accuracy * 100).rounded()))%"
    }

    private func detail(_ entry: WeaknessAnalyzer.Entry) -> String {
        var text = "正答率 \(percentText(entry))（直近 \(entry.answered) 問）"
        if entry.pendingReviews > 0 {
            text += "・復習待ち \(entry.pendingReviews) 問"
        }
        return text
    }

    private func legendText(_ level: WeaknessAnalyzer.Level) -> String {
        switch level {
        case .strong: return "正答率 90 % 以上（単元クリアの目安）"
        case .almost: return "70 % 以上 90 % 未満"
        case .weak: return "70 % 未満"
        case .few: return "解いた数が \(WeaknessAnalyzer.minAnswers) 問未満"
        case .untried: return "まだ解いていない"
        }
    }

    static func color(_ level: WeaknessAnalyzer.Level) -> Color {
        switch level {
        case .strong: return Theme.correct
        case .almost: return Theme.volt
        case .weak: return Theme.wrong
        case .few: return Color(red: 0.40, green: 0.75, blue: 1.0)
        case .untried: return Color.white
        }
    }

    // MARK: - タイルの組み立て

    private func makeGroups() -> [TileGroup] {
        let lessonById = Dictionary(lessons.map { ($0.unitId, $0) }, uniquingKeysWith: { first, _ in first })
        let files = QuestionBank.shared.files
        var placed: Set<String> = []
        var result: [TileGroup] = []

        for stage in Curriculum.stages {
            let tiles = stage.unitIds.map { id -> Tile in
                placed.insert(id)
                if let lesson = lessonById[id] {
                    return Tile(unitId: id, label: id, title: lesson.title, target: .lesson(lesson))
                }
                if let file = files[id] {
                    return Tile(unitId: id, label: id, title: file.unit.title,
                                target: .drill(QuestionBank.shared.makeDrillUnit(from: file)))
                }
                return Tile(unitId: id, label: id, title: "準備中", target: nil)
            }
            result.append(TileGroup(title: stage.title, tiles: tiles))
        }

        // カリキュラム外のドリル（旧単元・試験型）は、解いたことのあるものだけ並べる
        let touched = Set(WeaknessAnalyzer.touchedUnitIds(records: records, reviews: reviewItems))
        var drills: [Tile] = []
        for unit in units.sorted(by: { $0.order < $1.order }) where touched.contains(unit.id) && !placed.contains(unit.id) {
            let label = unit.id.split(separator: "_").first.map(String.init) ?? unit.id
            drills.append(Tile(unitId: unit.id, label: label, title: unit.title, target: .drill(unit)))
        }
        for file in examDrills where touched.contains(file.unit.id) && !placed.contains(file.unit.id) {
            drills.append(Tile(unitId: file.unit.id, label: file.unit.id, title: file.unit.title,
                               target: .drill(QuestionBank.shared.makeDrillUnit(from: file))))
        }
        if !drills.isEmpty {
            result.append(TileGroup(title: "ドリル（旧単元・試験型）", tiles: drills))
        }
        return result
    }
}

/// ホームの「苦手マップ」カード。解いたことのある単元を色の点で並べる。
struct WeaknessCardView: View {
    let records: [StudyRecord]
    let reviewItems: [ReviewItem]

    var body: some View {
        let ids = WeaknessAnalyzer.touchedUnitIds(records: records, reviews: reviewItems)
        let entries = WeaknessAnalyzer.entries(for: ids.map { (id: $0, title: $0) }, records: records, reviews: reviewItems)
        let judged = ids.compactMap { entries[$0] }
        let weak = judged.filter { $0.level == .weak }.count
        let almost = judged.filter { $0.level == .almost }.count
        let strong = judged.filter { $0.level == .strong }.count

        HStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundStyle(Theme.volt)
                .frame(width: 44, height: 44)
                .background(Theme.volt.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text("苦手マップ")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                if judged.isEmpty {
                    Text("問題を解くと、単元ごとの得意・苦手が色で分かる")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("苦手 \(weak)・もう少し \(almost)・得意 \(strong) 単元")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 3) {
                        ForEach(judged.prefix(18)) { entry in
                            Circle()
                                .fill(WeaknessMapView.color(entry.level).opacity(entry.level == .untried ? 0.3 : 0.9))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameCard(tint: Theme.volt.opacity(0.04), border: Theme.volt.opacity(0.3))
    }
}
