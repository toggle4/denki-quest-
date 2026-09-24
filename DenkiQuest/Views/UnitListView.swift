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
    @Query(sort: \ReviewItem.dueAt) private var reviewItems: [ReviewItem]
    @State private var showStudyLog = false
    @State private var showBossDex = false
    @State private var flash: Double = 0
    @State private var screenShake: CGSize = .zero
    /// マスコットがこげている間だけ true
    @State private var mascotBurnt = false
    @State private var sootVeil: Double = 0
    /// 充電中に画面のふちを光らせる量（0〜1。6 秒かけて上がる）
    @State private var chargeGlow: Double = 0
    /// 危険域で画面全体を震わせる位相（アニメーションで進める）
    @State private var buzzPhase: CGFloat = 0
    /// ショート時の停電（黒い幕の濃さ）
    @State private var blackout: Double = 0
    @State private var mascotCharging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                        RecapCardView(lessons: lessonSections.flatMap(\.lessons), stats: stats)
                        ReviewCardView(items: reviewItems, units: units)
                        bossDexCard

                        lessonList
                        drillList
                    }
                    .padding()
                }
                // 充電中に浮き上がったマスコットが上で切れないように
                .scrollClipDisabled()
                // 充電中に指を動かしても画面がスクロールしないように
                .scrollDisabled(mascotCharging)
            }
            .navigationTitle("でんきクエスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("効果音", isOn: $soundEnabled)
                        Toggle("振動", isOn: $hapticsEnabled)
                        Divider()
                        Button {
                            GameFeedback.tap()
                            showBossDex = true
                        } label: {
                            Label("ボス図鑑", systemImage: "books.vertical.fill")
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .navigationDestination(for: LearningUnit.self) { unit in
                SessionView(
                    unit: unit,
                    priority: unit.id == "review" ? [] : ReviewSessionBuilder.dueQuestions(reviewItems, units: units, unitId: unit.id, limit: 3)
                )
            }
            .navigationDestination(for: Lesson.self) { lesson in
                LessonUnitView(lesson: lesson)
            }
            .navigationDestination(for: LessonSessionRoute.self) { route in
                LessonSessionView(route: route)
            }
            .navigationDestination(for: BossRoute.self) { route in
                BossBattleView(route: route)
            }
            .sheet(isPresented: $showStudyLog) {
                StudyLogView(stats: stats, records: records, units: units)
            }
            .sheet(isPresented: $showBossDex) {
                BossCollectionView()
            }
            .offset(screenShake)
            .modifier(BuzzEffect(amount: 1.8, phase: buzzPhase))
            .overlay {
                // 充電中は画面のふちが電気の色に光っていく
                RadialGradient(
                    colors: [.clear, Theme.volt.opacity(0.28), Theme.volt.opacity(0.55)],
                    center: .top,
                    startRadius: 90,
                    endRadius: 640
                )
                .opacity(chargeGlow)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .overlay {
                // こげている間は画面のふちがすすけて暗くなる
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.85)],
                    center: .top,
                    startRadius: 120,
                    endRadius: 520
                )
                .opacity(sootVeil)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .overlay {
                Color.white
                    .opacity(flash)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .overlay {
                // ショートで一瞬停電し、蛍光灯のようにちらついて戻る
                Color.black
                    .opacity(blackout)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .task { load() }
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(spacing: 8) {
            ChargeMascotView(size: 96,
                             onShortCircuit: shortCircuitEffect,
                             onBurntChanged: burntChanged,
                             onChargingChanged: chargingChanged,
                             onDangerChanged: dangerChanged)
            Text(mascotBurnt ? "ショートした。少し待てば元に戻る" : "読んで、すぐ解く。1 セッション 5〜8 分")
                .font(.subheadline)
                .foregroundStyle(mascotBurnt ? Color(red: 1.0, green: 0.62, blue: 0.30) : Theme.textSecondary)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.3), value: mascotBurnt)
        }
        .padding(.top, 4)
    }

    // MARK: - ボス図鑑への入口

    private var bossDexCard: some View {
        // 撃破するたびに数字が変わるよう、進捗の観測点に触れておく
        let _ = LessonProgressStore.changes.version
        let found = BossCollection.defeatedCount
        let preview = Array(BossRoster.ordered.prefix(4))
        return Button {
            GameFeedback.tap()
            showBossDex = true
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: -10) {
                    ForEach(preview) { boss in
                        BossPortrait(imageName: boss.imageName,
                                     revealed: BossCollection.record(for: boss.id).isDefeated,
                                     height: 38)
                            .frame(width: 38)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("ボス図鑑")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("撃破 \(found) / \(BossCollection.total) 体")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gameCard(tint: Theme.wrong.opacity(0.05), border: Theme.wrong.opacity(0.35))
        }
        .buttonStyle(.plain)
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

    // MARK: - ドリル（旧単元 + その直後に対応する試験型ドリル）

    private var examDrillsByLegacy: [String: [UnitFileV2]] {
        Dictionary(grouping: examDrills, by: { $0.unit.legacyUnit ?? "" })
    }

    @ViewBuilder
    private var drillList: some View {
        if let drillError {
            errorCard(drillError)
        }
        let grouped = Dictionary(grouping: units, by: { $0.stage })
        let byLegacy = examDrillsByLegacy
        ForEach(drillStageOrder, id: \.self) { stage in
            if let group = grouped[stage] {
                sectionHeader("ドリル：\(stage.label)", subtitle: "10 問ランダム・試験型は数値が変わる")
                ForEach(group.sorted { $0.order < $1.order }) { unit in
                    NavigationLink(value: unit) {
                        UnitRow(unit: unit)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })

                    if let files = byLegacy[unit.id] {
                        ForEach(files, id: \.unit.id) { file in
                            examDrillLink(file)
                        }
                    }
                }
            }
        }
        // 旧単元に対応づけられていない試験型ドリル
        if let rest = byLegacy[""] {
            sectionHeader("試験型ドリル：その他", subtitle: "数値が毎回変わる")
            ForEach(rest, id: \.unit.id) { file in
                examDrillLink(file)
            }
        }
    }

    private func examDrillLink(_ file: UnitFileV2) -> some View {
        NavigationLink(value: QuestionBank.shared.makeDrillUnit(from: file)) {
            ExamDrillRow(file: file)
        }
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(Theme.wrong)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gameCard(tint: Theme.wrong.opacity(0.08), border: Theme.wrong.opacity(0.5))
    }

    /// マスコットがこげ始めた・元に戻った、を受け取る。
    private func burntChanged(_ burnt: Bool) {
        mascotBurnt = burnt
        withAnimation(.easeOut(duration: burnt ? 0.45 : 0.8)) {
            sootVeil = burnt ? 0.45 : 0
        }
    }

    /// 充電の始まりと終わり。ふちの光を 6 秒かけて強め、離したらすぐ消す。
    private func chargingChanged(_ charging: Bool) {
        mascotCharging = charging
        if charging {
            withAnimation(.linear(duration: ChargeController.maxSeconds)) { chargeGlow = 1 }
        } else {
            withAnimation(.easeOut(duration: 0.25)) { chargeGlow = 0 }
        }
    }

    /// 危険域に入ったら画面全体を細かく震わせ、抜けたら止める。
    private func dangerChanged(_ danger: Bool) {
        guard !reduceMotion else { return }
        if danger {
            withAnimation(.linear(duration: 1.7)) { buzzPhase += 42 }
        } else {
            // アニメーションなしで整数に飛ばすと、震えがその場で止まる
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { buzzPhase = buzzPhase.rounded() + 1 }
        }
    }

    /// ショート時: 画面全体を白くフラッシュさせ、ガタガタ揺らし、停電させる。
    private func shortCircuitEffect() {
        flash = 0.95
        withAnimation(.easeOut(duration: 0.6)) {
            flash = 0
        }
        if !reduceMotion {
            // 暗転 → ちらつき → 点灯
            let flicker: [(Double, Double)] = [(0.12, 0.9), (0.42, 0.25), (0.5, 0.85), (0.6, 0.15), (0.68, 0.7), (0.78, 0.3)]
            for (delay, value) in flicker {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { blackout = value }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.86) {
                Haptics.impact(intensity: 0.4)
                withAnimation(.easeOut(duration: 0.35)) { blackout = 0 }
            }
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
        do {
            let lessons = try LessonLibrary.loadAll()
            lessonSections = Curriculum.sections(for: lessons)
        } catch {
            lessonError = error.localizedDescription
        }
        examDrills = QuestionBank.shared.drillFiles(excludingLessonIds: [])
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
                HStack(spacing: 6) {
                    Text("試験型")
                        .font(.caption2.bold())
                        .foregroundStyle(Theme.backgroundBottom)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 1.0, green: 0.62, blue: 0.30), in: Capsule())
                    Text(file.unit.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                }
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
                HStack(spacing: 6) {
                    Text("\(unit.questions.count) 問")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                    if bossCleared {
                        Label("ボス撃破", systemImage: "crown.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.volt)
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

    private var bossCleared: Bool {
        _ = LessonProgressStore.changes.version
        return BossRecordStore.isCleared(unit.id)
    }
}

/// 画面全体の細かい震え。phase をアニメーションで進めるだけで震え、整数で止まる。
private struct BuzzEffect: GeometryEffect {
    var amount: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let angle = phase * .pi * 2
        return ProjectionTransform(CGAffineTransform(translationX: amount * sin(angle),
                                                     y: amount * 0.6 * sin(angle * 1.7)))
    }
}

#Preview {
    UnitListView()
        .preferredColorScheme(.dark)
}
