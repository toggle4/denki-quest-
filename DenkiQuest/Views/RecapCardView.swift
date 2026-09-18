import SwiftUI

/// 前日（なければ直近）に読了したセッションの「まとめ」を並べるカード。
struct RecapCardView: View {
    let lessons: [Lesson]
    let stats: StudyStats

    private struct Entry: Identifiable {
        let lesson: Lesson
        let session: LessonSession
        let completedAt: Date
        var id: String { "\(lesson.unitId)-\(session.number)" }
    }

    private var entries: (title: String, items: [Entry]) {
        _ = LessonProgressStore.changes.version
        let calendar = Calendar.current
        var all: [Entry] = []
        for lesson in lessons {
            for session in lesson.sessions {
                if let at = LessonProgressStore.completedAt(lesson.unitId, session: session.number) {
                    all.append(Entry(lesson: lesson, session: session, completedAt: at))
                }
            }
        }
        guard !all.isEmpty else { return ("", []) }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!
        let fromYesterday = all.filter { calendar.isDate($0.completedAt, inSameDayAs: yesterday) }
        if !fromYesterday.isEmpty {
            return ("昨日の学び", Array(fromYesterday.sorted { $0.completedAt < $1.completedAt }.suffix(3)))
        }
        let latest = all.sorted { $0.completedAt > $1.completedAt }.prefix(2)
        let label = calendar.isDateInToday(latest.first!.completedAt) ? "今日の学び" : "前回の学び"
        return (label, Array(latest.reversed()))
    }

    var body: some View {
        let data = entries
        if data.items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(data.title, systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(data.items.count) セッション読了")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(data.items) { entry in
                    NavigationLink(value: entry.lesson) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(entry.lesson.unitId)
                                    .font(.caption2.weight(.bold).monospaced())
                                    .foregroundStyle(Theme.backgroundBottom)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.volt, in: RoundedRectangle(cornerRadius: 6))
                                Text("セッション \(entry.session.number)　\(entry.session.title)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            let points = entry.session.summaryPoints
                            if points.isEmpty {
                                Text("この単元の目標: " + (entry.lesson.goal ?? entry.lesson.title))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(2)
                            } else {
                                ForEach(Array(points.prefix(3).enumerated()), id: \.offset) { _, point in
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text("•").foregroundStyle(Theme.volt)
                                        Text(InlineMarkdown.attributed(point))
                                            .font(.caption)
                                            .foregroundStyle(Theme.textPrimary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .gameCard(tint: Theme.volt.opacity(0.04), border: Theme.volt.opacity(0.35))
        }
    }
}
