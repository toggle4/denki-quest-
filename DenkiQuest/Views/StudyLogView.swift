import SwiftUI

/// 学習時間のくわしい画面。直近 7 日のグラフと履歴。
struct StudyLogView: View {
    let stats: StudyStats
    let records: [StudyRecord]
    let units: [LearningUnit]

    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    private var unitTitles: [String: String] {
        Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0.title) })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GameBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        summary
                        weekChart
                        history
                    }
                    .padding()
                }
            }
            .navigationTitle("学習の記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Theme.volt)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            summaryTile(title: "合計", value: StudyFormat.hours(stats.totalSeconds) + " h")
            summaryTile(title: "今日", value: StudyFormat.duration(stats.todaySeconds))
            summaryTile(title: "連続", value: "\(stats.streakDays) 日")
        }
    }

    private func summaryTile(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .gameCard()
    }

    private var weekChart: some View {
        let maxSeconds = max(stats.last7Days.map(\.seconds).max() ?? 0, 60)
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ja_JP")
            f.dateFormat = "E"
            return f
        }()

        return VStack(alignment: .leading, spacing: 12) {
            Label("直近 7 日", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(stats.last7Days) { day in
                    let heightRatio = appeared ? day.seconds / maxSeconds : 0
                    VStack(spacing: 6) {
                        Text(day.seconds > 0 ? StudyFormat.duration(day.seconds) : "")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(colors: [Theme.volt, Theme.correct], startPoint: .bottom, endPoint: .top))
                                .frame(height: max(4, 110 * heightRatio))
                                .opacity(day.seconds > 0 ? 1 : 0)
                        }
                        .frame(height: 110)
                        Text(formatter.string(from: day.date))
                            .font(.caption2.bold())
                            .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Theme.volt : Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .gameCard()
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("履歴", systemImage: "list.bullet")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if records.isEmpty {
                Text("まだ記録がありません。最初のクエストに挑戦しよう。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(records.prefix(30)) { record in
                    HStack(spacing: 12) {
                        Image(systemName: record.completed ? "checkmark.seal.fill" : "pause.circle")
                            .foregroundStyle(record.completed ? Theme.correct : Theme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(unitTitles[record.unitId] ?? record.unitId)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(StudyFormat.duration(record.durationSeconds))
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.volt)
                            Text("\(record.correctCount) / \(record.answeredCount) 正解")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                    Divider().overlay(Theme.cardBorder)
                }
            }
        }
        .padding(16)
        .gameCard()
    }
}
