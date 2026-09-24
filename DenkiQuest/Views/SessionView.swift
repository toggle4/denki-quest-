import SwiftUI
import SwiftData

/// 1 セッションの画面。問題 → 解説 → 次へ を繰り返し、最後に結果を表示する。
struct SessionView: View {
    @State private var session: QuizSession
    @State private var timer = StudyTimer()
    @State private var savedThisRun = false
    @State private var savedSeconds: Double = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// 復習待ちの問題（先頭に混ぜる）
    private let priority: [Question]

    init(unit: LearningUnit, priority: [Question] = []) {
        self.priority = priority
        _session = State(initialValue: QuizSession(unit: unit, priority: priority))
    }

    private func attachScheduler() {
        let scheduler = ReviewScheduler(context: modelContext)
        let unitId = session.unit.id
        session.onAnswered = { question, correct in
            scheduler.record(question: question, unitId: unitId, correct: correct)
        }
    }

    var body: some View {
        ZStack {
            GameBackground()
            if session.isFinished {
                ResultView(
                    session: session,
                    studySeconds: savedSeconds,
                    retry: {
                        GameFeedback.tap()
                        savedThisRun = false
                        savedSeconds = 0
                        timer.reset()
                        session = QuizSession(unit: session.unit, priority: priority)
                        attachScheduler()
                    },
                    finish: {
                        GameFeedback.tap()
                        dismiss()
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if let item = session.current {
                QuestionView(session: session, item: item, timer: timer)
                    .id(item.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                ContentUnavailableView("問題がありません", systemImage: "questionmark.circle")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: session.currentIndex)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: session.isFinished)
        .navigationTitle(session.unit.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            timer.start()
            attachScheduler()
        }
        .onDisappear { saveIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timer.start()
            } else {
                timer.pause()
            }
        }
        .onChange(of: session.isFinished) { _, finished in
            if finished { saveIfNeeded() }
        }
    }

    /// 学習時間を SwiftData に記録する。1 回の挑戦につき 1 回だけ。
    private func saveIfNeeded() {
        guard !savedThisRun else { return }
        timer.pause()
        let seconds = min(timer.elapsed, StudyGoal.maxSecondsPerRecord)
        let answered = session.currentIndex + (session.hasAnswered || session.isFinished ? 1 : 0)
        guard session.isFinished || seconds >= StudyGoal.minSecondsToRecord else { return }

        let record = StudyRecord(
            startedAt: timer.createdAt,
            durationSeconds: seconds,
            unitId: session.unit.id,
            answeredCount: min(answered, session.items.count),
            correctCount: session.correctCount,
            completed: session.isFinished
        )
        modelContext.insert(record)
        savedThisRun = true
        savedSeconds = seconds
    }
}

/// セッション終了時の結果。
private struct ResultView: View {
    let session: QuizSession
    let studySeconds: Double
    let retry: () -> Void
    let finish: () -> Void

    @State private var shownStars = 0
    @State private var mascotScale: CGFloat = 0.6

    private var ratio: Double {
        session.items.isEmpty ? 0 : Double(session.correctCount) / Double(session.items.count)
    }

    private var stars: Int {
        switch ratio {
        case 1.0: return 3
        case 0.8...: return 2
        case 0.5...: return 1
        default: return 0
        }
    }

    private var rank: (label: String, color: Color) {
        switch ratio {
        case 1.0: return ("S", Theme.volt)
        case 0.8...: return ("A", Theme.correct)
        case 0.5...: return ("B", Color(red: 0.40, green: 0.75, blue: 1.0))
        default: return ("C", Theme.textSecondary)
        }
    }

    /// ボスの名前が分かっている（＝一度倒した）ときは名前を出す。
    private var bossButtonTitle: String {
        let cleared = BossRecordStore.isCleared(session.unit.id)
        if let boss = BossRoster.boss(forUnit: session.unit.id),
           BossCollection.record(for: boss.id).isDefeated {
            return cleared ? "\(boss.name)にもう一度挑む" : "\(boss.name)に挑む"
        }
        return cleared ? "ボス戦にもう一度挑む" : "ボス戦に挑む"
    }

    private var message: String {
        switch ratio {
        case 1.0: return "パーフェクト！この単元はばっちり。"
        case 0.8...: return "あと少し。間違えた問題の解説を読み返そう。"
        case 0.5...: return "半分以上正解。もう 1 クエストやってみよう。"
        default: return "まずは用語に慣れるところから。繰り返せば必ず覚えられる。"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .shadow(color: rank.color.opacity(0.6), radius: 24)
                .scaleEffect(mascotScale)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < shownStars ? "star.fill" : "star")
                        .font(.system(size: 34))
                        .foregroundStyle(i < shownStars ? Theme.volt : Theme.textSecondary.opacity(0.4))
                        .scaleEffect(i < shownStars ? 1.0 : 0.8)
                }
            }

            VStack(spacing: 6) {
                Text("クエスト クリア")
                    .font(.title.bold())
                    .foregroundStyle(Theme.textPrimary)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("RANK")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.textSecondary)
                    Text(rank.label)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(rank.color)
                }
            }

            HStack(spacing: 8) {
                statBlock(title: "正解", value: "\(session.correctCount) / \(session.items.count)")
                statBlock(title: "最大コンボ", value: "\(session.maxCombo)")
                statBlock(title: "ヒント", value: "\(session.hintCount) 回")
                statBlock(title: "学習時間", value: "+" + StudyFormat.duration(studySeconds))
            }
            .padding(16)
            .gameCard()

            Text(message)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                if session.unit.boss != nil {
                    NavigationLink(value: BossRoute(unit: session.unit)) {
                        Label(bossButtonTitle, systemImage: "bolt.trianglebadge.exclamationmark.fill")
                    }
                    .buttonStyle(VoltButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })
                }
                Button("もう一度", action: retry)
                    .buttonStyle(VoltButtonStyle(prominent: session.unit.boss == nil))
                Button("クエスト一覧に戻る", action: finish)
                    .buttonStyle(VoltButtonStyle(prominent: false))
            }
        }
        .padding()
        .onAppear {
            GameFeedback.sessionCleared(perfect: session.isPerfect)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                mascotScale = 1.0
            }
            for i in 0..<stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.3) {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        shownStars = i + 1
                    }
                }
            }
        }
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}
