import SwiftUI

/// 教材単元のセッション一覧。ここから「読む → 解く」のセッションに入る。
struct LessonUnitView: View {
    let lesson: Lesson

    private var hasQuestions: Bool {
        QuestionBank.shared.hasQuestions(unitId: lesson.unitId)
    }

    var body: some View {
        // 進捗が更新されたら再描画されるように、観測点に触れておく
        let _ = LessonProgressStore.changes.version
        return ZStack {
            GameBackground()
            ScrollView {
                VStack(spacing: 14) {
                    if let goal = lesson.goal {
                        goalCard(goal)
                    }
                    infoCard
                    ForEach(lesson.sessions) { session in
                        sessionCard(session)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func goalCard(_ goal: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "target")
                .font(.title3)
                .foregroundStyle(Theme.volt)
            VStack(alignment: .leading, spacing: 4) {
                Text("この単元の目標")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.volt)
                Text(goal)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .gameCard(tint: Theme.volt.opacity(0.06), border: Theme.volt.opacity(0.4))
    }

    private var infoCard: some View {
        HStack(spacing: 10) {
            Image(systemName: hasQuestions ? "book.and.wrench.fill" : "book.fill")
                .foregroundStyle(Theme.textSecondary)
            Text(hasQuestions
                 ? "説明を読んだ直後に、いま読んだ内容の問題が出ます。"
                 : "この単元の問題データは準備中です。説明だけ読めます。")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func sessionCard(_ session: LessonSession) -> some View {
        let completed = LessonProgressStore.isCompleted(lesson.unitId, session: session.number)
        let needsReview = LessonProgressStore.needsReview(lesson.unitId, session: session.number)
        let inProgress = !completed && LessonProgressStore.resumeIndex(lesson.unitId, session: session.number) > 0
        let quizCount = session.quizQuestionIds.filter { QuestionBank.shared.hasQuestion(id: $0) }.count

        return VStack(spacing: 8) {
            NavigationLink(value: LessonSessionRoute(lesson: lesson, session: session, reviewMode: completed)) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(statusColor(completed: completed, needsReview: needsReview, inProgress: inProgress).opacity(0.2))
                            .frame(width: 44, height: 44)
                        Text("\(session.number)")
                            .font(.headline.bold())
                            .foregroundStyle(statusColor(completed: completed, needsReview: needsReview, inProgress: inProgress))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(session.pages.count) 画面" + (quizCount > 0 ? "・\(quizCount) 問" : ""))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    statusBadge(completed: completed, needsReview: needsReview, inProgress: inProgress)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gameCard()
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })

            if completed && quizCount > 0 {
                NavigationLink(value: LessonSessionRoute(lesson: lesson, session: session, reviewMode: false)) {
                    Label("問題つきでもう一度", systemImage: "arrow.counterclockwise")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.volt)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statusColor(completed: Bool, needsReview: Bool, inProgress: Bool) -> Color {
        if needsReview { return Color(red: 1.0, green: 0.62, blue: 0.30) }
        if completed { return Theme.correct }
        if inProgress { return Theme.volt }
        return Theme.textSecondary
    }

    private func statusBadge(completed: Bool, needsReview: Bool, inProgress: Bool) -> some View {
        let text: String
        if needsReview { text = "要復習" } else if completed { text = "読了" } else if inProgress { text = "途中" } else { text = "未読" }
        return Text(text)
            .font(.caption2.bold())
            .foregroundStyle(Theme.backgroundBottom)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor(completed: completed, needsReview: needsReview, inProgress: inProgress), in: Capsule())
    }
}
