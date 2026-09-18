import SwiftUI
import SwiftData

/// ホーム。マスコット・200 時間ゲージ・教材（読む→解く）・ドリル（10 問ランダム）。
struct UnitListView: View {
    @State private var units: [LearningUnit] = []
    @State private var lessonSections: [Curriculum.Section] = []
    @State private var examDrills: [UnitFileV2] = []
    @State private var lessonError: String?
    @State private var drillError: String?
    @AppStorage(SoundPlayer.enabledKey) private var soundEnabled = true
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @Query(sort: \StudyRecord.startedAt, order: .reverse) private var records: [StudyRecord]
    @State private var showStudyLog = false
    @State private var flash: Double = 0
    @State private var screenShake: CGSize = .zero

    private var stats: StudyStats { StudyStats(records: records) }

    private let drillStageOrder: [LearningUnit.Stage] = [.review, .memorize, .calculate, .practical]

    var body: some View {
        NavigationStack {
            ZStack {
                GameBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        Button {
                            GameFeedback.tap()
                            showStudyLog = true
                        } label: {
                            StudyGaugeView(stats: stats)
                        }
                        .buttonStyle(.plain)

                        lessonList
                        examDrillList
                        drillList
                    }
                    .padding()
                }
            }
            .navigationTitle("でんきクエスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("効果音", isOn: $soundEnabled)
                        Toggle("振動", isOn: $hapticsEnabled)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .navigationDestination(for: LearningUnit.self) { unit in
                SessionView(unit: unit)
            }
            .navigationDestination(for: Lesson.self) { lesson in
                LessonUnitView(lesson: lesson)
            }
            .navigationDestination(for: LessonSessionRoute.self) { route in
                LessonSessionView(route: route)
            }
            .sheet(isPresented: $showStudyLog) {
                StudyLogView(stats: stats, records: records, units: units)
            }
            .offset(screenShake)
            .overlay {
                Color.white
                    .opacity(flash)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .task { load() }
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(spacing: 8) {
            ChargeMascotView(size: 96, onShortCircuit: shortCircuitEffect)
            Text("読んで、すぐ解く。1 セッション 5〜8 分")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 4)
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - 教材（読む → 解く）

    @ViewBuilder
    private var lessonList: some View {
        if let lessonError {
            errorCard(lessonError)
        }
        ForEach(lessonSections) { section in
            sectionHeader(section.title, subtitle: "読む → 解く")
            ForEach(section.lessons) { lesson in
                NavigationLink(value: lesson) {
                    LessonRow(lesson: lesson)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })
            }
        }
    }

    // MARK: - 試験型ドリル（新形式・教材なし）

    @ViewBuilder
    private var examDrillList: some View {
        let grouped = Dictionary(grouping: examDrills, by: { $0.unit.stage ?? 99 })
        ForEach(grouped.keys.sorted(), id: \.self) { stage in
            if let files = grouped[stage] {
                sectionHeader("試験型ドリル：" + QuestionBank.stageTitle(stage), subtitle: "数値が毎回変わる")
                ForEach(files, id: \.unit.id) { file in
                    NavigationLink(value: QuestionBank.shared.makeDrillUnit(from: file)) {
                        ExamDrillRow(file: file)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })
                }
            }
        }
    }

    // MARK: - ドリル（旧単元）

    @ViewBuilder
    private var drillList: some View {
        if let drillError {
            errorCard(drillError)
        }
        let grouped = Dictionary(grouping: units, by: { $0.stage })
        ForEach(drillStageOrder, id: \.self) { stage in
            if let group = grouped[stage] {
                sectionHeader("ドリル：\(stage.label)", subtitle: "10 問ランダム")
                ForEach(group.sorted { $0.order < $1.order }) { unit in
                    NavigationLink(value: unit) {
                        UnitRow(unit: unit)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })
                }
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(Theme.wrong)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gameCard(tint: Theme.wrong.opacity(0.08), border: Theme.wrong.opacity(0.5))
    }

    /// ショート時: 画面全体を白くフラッシュさせ、ガタガタ揺らす。
    private func shortCircuitEffect() {
        flash = 0.95
        withAnimation(.easeOut(duration: 0.6)) {
            flash = 0
        }
        let offsets: [CGSize] = [
            CGSize(width: 10, height: -6), CGSize(width: -9, height: 7), CGSize(width: 7, height: 5),
            CGSize(width: -6, height: -4), CGSize(width: 4, height: 3), CGSize(width: -2, height: -2), .zero,
        ]
        for (i, offset) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.linear(duration: 0.05)) {
                    screenShake = offset
                }
            }
        }
    }

    private func load() {
        var lessonIds: Set<String> = []
        do {
            let lessons = try LessonLibrary.loadAll()
            lessonIds = Set(lessons.map(\.unitId))
            lessonSections = Curriculum.sections(for: lessons)
        } catch {
            lessonError = error.localizedDescription
        }
        examDrills = QuestionBank.shared.drillFiles(excludingLessonIds: lessonIds)
        do {
            units = try ContentLoader.loadUnits()
        } catch {
            drillError = error.localizedDescription
        }
    }
}

// MARK: - 行

private struct LessonRow: View {
    let lesson: Lesson

    private var completed: Int {
        _ = LessonProgressStore.changes.version
        return LessonProgressStore.completedSessionCount(lesson)
    }
    private var hasQuestions: Bool { QuestionBank.shared.hasQuestions(unitId: lesson.unitId) }

    var body: some View {
        HStack(spacing: 14) {
            Text(lesson.unitId)
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Theme.backgroundBottom)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.volt, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 8) {
                    Text("\(lesson.sessions.count) セッション・読了 \(completed)/\(lesson.sessions.count)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    if hasQuestions {
                        Text("問題つき")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.backgroundBottom)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.correct, in: Capsule())
                    }
                }
            }
            Spacer(minLength: 0)
            if completed == lesson.sessions.count && !lesson.sessions.isEmpty {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.correct)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameCard()
    }
}

private struct ExamDrillRow: View {
    let file: UnitFileV2

    private var templateCount: Int { file.questions.filter { $0.type == "template" }.count }

    var body: some View {
        HStack(spacing: 14) {
            Text(file.unit.id)
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Theme.backgroundBottom)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(red: 1.0, green: 0.62, blue: 0.30), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(file.unit.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 8) {
                    Text("\(file.questions.count) 型")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    if templateCount > 0 {
                        Text("計算 \(templateCount) 型は数値ランダム")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.backgroundBottom)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.volt, in: Capsule())
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameCard()
    }
}

private struct UnitRow: View {
    let unit: LearningUnit

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.stageColor(unit.stage).opacity(0.2))
                    .frame(width: 52, height: 52)
                Text("\(unit.order)")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.stageColor(unit.stage))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(unit.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(unit.description)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                Text("\(unit.questions.count) 問")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameCard()
    }
}

#Preview {
    UnitListView()
        .preferredColorScheme(.dark)
}
