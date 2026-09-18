import SwiftUI
import SwiftData

/// 教材の 1 セッション。説明 → 差し込み問題 → 説明 → … → まとめ問題 → 完了。
struct LessonSessionView: View {
    let route: LessonSessionRoute

    @State private var flow: LessonFlow
    @State private var timer = StudyTimer()
    @State private var savedThisRun = false
    @State private var savedSeconds: Double = 0
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    init(route: LessonSessionRoute) {
        self.route = route
        _flow = State(initialValue: LessonFlow(lesson: route.lesson, session: route.session, reviewMode: route.reviewMode))
    }

    private var nextRoute: LessonSessionRoute? {
        guard let next = route.lesson.sessions
            .filter({ $0.number > route.session.number })
            .min(by: { $0.number < $1.number }) else { return nil }
        return LessonSessionRoute(lesson: route.lesson, session: next, reviewMode: false)
    }

    var body: some View {
        ZStack {
            GameBackground()
            content
        }
        .navigationTitle("\(route.lesson.unitId)　セッション \(route.session.number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        // ルール: 問題画面に入ったら前の説明には戻れない
        .navigationBarBackButtonHidden(flow.stage == .quiz)
        .onAppear {
            timer.start()
            if flow.isFinished { saveIfNeeded() }
        }
        .onDisappear { saveIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timer.start()
            } else {
                timer.pause()
            }
        }
        .onChange(of: flow.quizSession?.isFinished ?? false) { _, finished in
            if finished { flow.quizStepFinished() }
        }
        .onChange(of: flow.isFinished) { _, finished in
            if finished {
                GameFeedback.sessionCleared(perfect: flow.totalAnswered > 0 && flow.totalCorrect == flow.totalAnswered)
                saveIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch flow.stage {
        case .reading:
            ReadingBlockView(flow: flow, pages: flow.currentPages)
                .id(flow.blockIndex)
        case .quiz:
            if let quizSession = flow.quizSession, let item = quizSession.current {
                QuestionView(
                    session: quizSession,
                    item: item,
                    timer: timer,
                    progressLabel: flow.quizProgressLabel,
                    lastButtonTitle: "次へ"
                )
                .id("\(item.id)-\(flow.questionCursor)-\(flow.attempt)")
            }
        case .finished:
            LessonSummaryView(flow: flow, studySeconds: savedSeconds, nextRoute: nextRoute)
        }
    }

    private func saveIfNeeded() {
        guard !savedThisRun else { return }
        timer.pause()
        let seconds = min(timer.elapsed, StudyGoal.maxSecondsPerRecord)
        guard flow.isFinished || seconds >= StudyGoal.minSecondsToRecord else { return }
        let record = StudyRecord(
            startedAt: timer.createdAt,
            durationSeconds: seconds,
            unitId: route.lesson.unitId,
            answeredCount: flow.totalAnswered,
            correctCount: flow.totalCorrect,
            completed: flow.isFinished
        )
        modelContext.insert(record)
        savedThisRun = true
        savedSeconds = seconds
    }
}

// MARK: - 説明ブロック（連続する説明画面をスワイプで読む）

private struct ReadingBlockView: View {
    @Bindable var flow: LessonFlow
    let pages: [LessonPage]

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $flow.pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page, isLast: index == pages.count - 1)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Text(flow.reviewMode ? "復習モード（説明のみ）" : "画面 \(flow.pageIndex + 1) / \(max(pages.count, 1))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("セッション \(flow.session.number)：\(flow.session.title)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            ProgressView(value: flow.progress)
                .tint(Theme.volt)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func pageView(_ page: LessonPage, isLast: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(page.blocks.enumerated()), id: \.offset) { _, block in
                    LessonBlockView(block: block)
                }

                if isLast {
                    Button {
                        GameFeedback.tap()
                        flow.advanceFromReading()
                    } label: {
                        Text(flow.nextActionTitle)
                    }
                    .buttonStyle(VoltButtonStyle())
                    .padding(.top, 8)
                } else {
                    Label("スワイプで次へ", systemImage: "hand.draw")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            // ページインジケータに文章が隠れないように余白を取る
            .padding(.bottom, 48)
        }
    }
}

// MARK: - セッション完了

private struct LessonSummaryView: View {
    let flow: LessonFlow
    let studySeconds: Double
    let nextRoute: LessonSessionRoute?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(color: Theme.volt.opacity(0.5), radius: 20)

            Text(flow.reviewMode ? "読み直し完了" : "セッション完了")
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("\(flow.lesson.unitId)　セッション \(flow.session.number)：\(flow.session.title)")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            if flow.totalAnswered > 0 {
                HStack(spacing: 8) {
                    stat(title: "正解", value: "\(flow.totalCorrect) / \(flow.totalAnswered)")
                    stat(title: "学習時間", value: "+" + StudyFormat.duration(studySeconds))
                }
                .padding(16)
                .gameCard()
            }

            if flow.needsReview {
                Label("まとめ問題の正答率が 80 % 未満でした。次回はこのセッションを先に復習しましょう。", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.30))
                    .multilineTextAlignment(.leading)
                    .padding(12)
                    .gameCard(tint: Color.orange.opacity(0.08), border: Color.orange.opacity(0.5))
            }

            Spacer()

            VStack(spacing: 12) {
                if let nextRoute {
                    NavigationLink(value: nextRoute) {
                        Text("次へ　セッション \(nextRoute.session.number)：\(nextRoute.session.title)")
                            .lineLimit(1)
                    }
                    .buttonStyle(VoltButtonStyle())
                }
                Button("セッション一覧に戻る") { dismiss() }
                    .buttonStyle(VoltButtonStyle(prominent: nextRoute == nil))
            }
        }
        .padding()
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}
