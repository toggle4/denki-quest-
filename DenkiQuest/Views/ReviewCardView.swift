import SwiftUI

/// ホームの「復習」カード。期限が来た問題をまとめて解く入口。
struct ReviewCardView: View {
    let items: [ReviewItem]
    let units: [LearningUnit]

    private var due: [ReviewItem] { items.filter { ReviewSessionBuilder.isDue($0) } }
    private var pending: [ReviewItem] { items.filter { !$0.graduated && $0.dueAt > .now } }
    private var graduatedCount: Int { items.filter(\.graduated).count }

    var body: some View {
        let _ = LessonProgressStore.changes.version
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("復習", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("1 → 3 → 7 → 14 日")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if !due.isEmpty, let unit = ReviewSessionBuilder.makeReviewUnit(items, units: units) {
                NavigationLink(value: unit) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Theme.wrong.opacity(0.2)).frame(width: 44, height: 44)
                            Text("\(due.count)")
                                .font(.headline.bold())
                                .foregroundStyle(Theme.wrong)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("復習待ちが \(due.count) 問")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("最大 10 問ずつ出します。正解すると次の間隔へ")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.wrong.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })
            } else if let next = pending.first {
                Text("復習待ちはありません。次は \(next.dueAt.formatted(date: .abbreviated, time: .omitted)) に \(pending.filter { Calendar.current.isDate($0.dueAt, inSameDayAs: next.dueAt) }.count) 問。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("間違えた問題がここに並びます。翌日・3 日後・7 日後・14 日後に出し直します。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            if graduatedCount > 0 {
                Label("卒業 \(graduatedCount) 問", systemImage: "graduationcap.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.correct)
            }
        }
        .padding(16)
        .gameCard()
    }
}
