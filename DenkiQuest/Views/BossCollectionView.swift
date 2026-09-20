import SwiftUI

/// ボスの絵。未撃破のあいだは影だけ（シルエット）で見せる。
struct BossPortrait: View {
    let imageName: String
    let revealed: Bool
    var height: CGFloat = 96

    var body: some View {
        Group {
            if revealed {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(imageName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Color.black.opacity(0.85))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

/// ボス図鑑。撃破したボスだけ名前と二つ名が出る。
struct BossCollectionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Boss?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                GameBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        summary
                        ForEach(stages, id: \.self) { stage in
                            sectionHeader(stage)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(BossRoster.ordered.filter { $0.stage == stage }) { boss in
                                    Button {
                                        GameFeedback.tap()
                                        selected = boss
                                    } label: {
                                        cell(boss)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("ボス図鑑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Theme.volt)
                }
            }
            .sheet(item: $selected) { boss in
                BossDetailView(boss: boss)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var stages: [Int] {
        var seen: [Int] = []
        for boss in BossRoster.ordered where !seen.contains(boss.stage) {
            seen.append(boss.stage)
        }
        return seen
    }

    private var summary: some View {
        let found = BossCollection.defeatedCount
        let total = BossCollection.total
        return VStack(spacing: 8) {
            Text("撃破 \(found) / \(total) 体")
                .font(.title3.weight(.black))
                .foregroundStyle(Theme.textPrimary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.volt, Theme.correct], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(found) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 10)
            Text(found == total ? "全てのボスを撃破した。" : "単元の最後に現れるボスを倒すと、ここに記録される。")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .gameCard(tint: Theme.volt.opacity(0.06), border: Theme.volt.opacity(0.4))
    }

    private func sectionHeader(_ stage: Int) -> some View {
        HStack {
            Text(QuestionBank.stageTitle(stage))
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
        .padding(.top, 6)
    }

    private func cell(_ boss: Boss) -> some View {
        let record = BossCollection.record(for: boss.id)
        return VStack(spacing: 6) {
            BossPortrait(imageName: boss.imageName, revealed: record.isDefeated, height: 88)
            Text(record.isDefeated ? boss.epithet : "？？？")
                .font(.caption2.bold())
                .foregroundStyle(record.isDefeated ? Theme.volt : Theme.textSecondary)
                .lineLimit(1)
            Text(record.isDefeated ? boss.name : "未撃破")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if record.isDefeated {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill").font(.caption2)
                    Text("\(record.defeats) 回")
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(Theme.volt)
            } else {
                Text(boss.rank.label)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .gameCard(tint: record.isDefeated ? Theme.volt.opacity(0.05) : .clear,
                  border: record.isDefeated ? Theme.volt.opacity(0.35) : Theme.cardBorder)
    }
}

/// 図鑑の 1 体ぶんの詳細。ここでは二つ名も解説も出す。
struct BossDetailView: View {
    let boss: Boss

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let record = BossCollection.record(for: boss.id)
        ZStack {
            GameBackground()
            ScrollView {
                VStack(spacing: 14) {
                    BossPortrait(imageName: boss.imageName, revealed: record.isDefeated, height: 180)
                        .padding(.top, 8)
                    VStack(spacing: 4) {
                        Text(record.isDefeated ? boss.epithet : "？？？")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Theme.volt)
                            .tracking(6)
                        Text(record.isDefeated ? boss.name : "未撃破")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("\(QuestionBank.stageTitle(boss.stage))　\(boss.rank.label)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if record.isDefeated {
                        Text(boss.lore)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .gameCard()
                        HStack(spacing: 8) {
                            stat("撃破", "\(record.defeats)")
                            stat("最速", record.bestTime.map { StudyFormat.clock($0) } ?? "—")
                            stat("最大コンボ", "\(record.maxCombo)")
                            stat("最大ヒット", "\(record.maxHit)")
                        }
                        .padding(12)
                        .gameCard()
                        if let first = record.firstDefeatedAt {
                            Text("初撃破 \(first.formatted(date: .numeric, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } else {
                        Text("まだ出会っていない。単元の最後にあるボス戦で撃破すると、ここに記録が残る。")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .gameCard()
                    }
                    Button("閉じる") {
                        GameFeedback.tap()
                        dismiss()
                    }
                    .buttonStyle(VoltButtonStyle(prominent: false))
                    .padding(.top, 4)
                }
                .padding()
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(Theme.textSecondary)
            Text(value).font(.subheadline.monospacedDigit().bold()).foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BossCollectionView()
        .preferredColorScheme(.dark)
}
