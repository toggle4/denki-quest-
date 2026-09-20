import SwiftUI
import SwiftData

/// ボス戦へ遷移するときの値。
struct BossRoute: Hashable {
    let unit: LearningUnit
}

/// ボス戦画面。上にボスと HP・タイマー、下に問題。正解で攻撃、不正解で反撃。
struct BossBattleView: View {
    let route: BossRoute

    @State private var engine: BossEngine
    @State private var timer = StudyTimer()
    @State private var saved = false
    @State private var screenShake: CGSize = .zero
    @State private var redFlash: Double = 0
    @State private var nameReveal = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    init(route: BossRoute) {
        self.route = route
        _engine = State(initialValue: BossEngine(unit: route.unit))
    }

    var body: some View {
        GeometryReader { geo in
            // 画像は画面いちばん上まで敷く。セーフエリアぶんも使う
            let topInset = geo.safeAreaInsets.top
            ZStack {
                GameBackground()
                VStack(spacing: 0) {
                    bossStage(height: (geo.size.height + topInset) * 0.44, topInset: topInset)
                    content
                }
                .offset(screenShake)
                Color.red
                    .opacity(redFlash)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            timer.start()
            attachScheduler()
            nameReveal = true
        }
        .onDisappear {
            engine.stop()
            saveIfNeeded()
        }
        .onChange(of: engine.counterToken) { _, _ in counterEffect() }
        .onChange(of: engine.phase) { _, phase in
            if phase == .won || phase == .lost { saveIfNeeded() }
        }
    }

    /// 戦闘中は名前だけ。二つ名は登場演出と図鑑でしか出さない。
    private var displayName: String {
        guard let boss = engine.boss else { return route.unit.title }
        return engine.phase == .intro ? boss.fullName : boss.name
    }

    private var bossImageName: String {
        engine.boss?.imageName ?? "BossMonster"
    }

    // MARK: - 上部: 画像いっぱい + 重ねた HP・タイマー・ハート

    /// 画面上部いっぱいのボス画像。下端にステータスを重ねる。
    private func bossStage(height: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            BossMonsterView(engine: engine, imageName: bossImageName)
            LinearGradient(
                colors: [.clear, Theme.backgroundBottom.opacity(0.5), Theme.backgroundBottom.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            statusBar
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .frame(height: max(height, 200))
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .topLeading) { backButton(topInset: topInset) }
    }

    /// 画像に重ねる戻るボタン。戦闘中は出さない。
    private func backButton(topInset: CGFloat) -> some View {
        Button {
            GameFeedback.tap()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.headline.bold())
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.45), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        }
        .padding(.leading, 14)
        .padding(.top, topInset + 6)
        .opacity(engine.phase == .fighting ? 0 : 1)
        .allowsHitTesting(engine.phase != .fighting)
        .animation(.easeOut(duration: 0.25), value: engine.phase)
    }

    private var statusBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label("BOSS", systemImage: "bolt.trianglebadge.exclamationmark.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.wrong)
                    .shadow(color: .black.opacity(0.9), radius: 3)
                Text(displayName)
                    .font(.title3.weight(.black))
                    .foregroundStyle(Theme.textPrimary)
                    .shadow(color: .black.opacity(0.9), radius: 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .scaleEffect(nameReveal ? 1 : 1.25, anchor: .leading)
                    .opacity(nameReveal ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.15), value: nameReveal)
                Spacer(minLength: 4)
                HStack(spacing: 3) {
                    ForEach(0..<BossEngine.maxHearts, id: \.self) { i in
                        Image(systemName: i < engine.hearts ? "heart.fill" : "heart")
                            .foregroundStyle(i < engine.hearts ? Theme.wrong : Color.white.opacity(0.35))
                    }
                }
                .font(.subheadline)
                .shadow(color: .black.opacity(0.9), radius: 3)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: engine.hearts)
            }
            // ボス HP
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.wrong, Color(red: 1.0, green: 0.6, blue: 0.3)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(engine.bossHP) / CGFloat(max(engine.maxHP, 1)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: engine.bossHP)
                }
            }
            .frame(height: 14)
            HStack {
                Text("HP \(engine.bossHP) / \(engine.maxHP)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    .shadow(color: .black.opacity(0.9), radius: 3)
                Spacer()
                if engine.combo >= 2 {
                    Text("\(engine.combo) COMBO")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.backgroundBottom)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.volt, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
                Label(StudyFormat.clock(engine.remaining), systemImage: "timer")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(engine.remaining < 15 ? Theme.wrong : Theme.textPrimary)
                    .shadow(color: .black.opacity(0.9), radius: 3)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: engine.combo)
            // 残り時間バー
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(engine.remaining < 15 ? Theme.wrong : Theme.volt)
                        .frame(width: geo.size.width * CGFloat(engine.remaining / max(engine.timeLimit, 1)))
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - 下部

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .intro:
            introView
        case .fighting:
            if let item = engine.current {
                BossQuestionView(engine: engine, item: item)
                    .id(item.id + "-\(engine.answered)")
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        case .won:
            resultView(won: true)
        case .lost:
            resultView(won: false)
        }
    }

    /// 登場演出。名前（intro のあいだは二つ名つき）は画像の上に重ねて出す。
    private var introView: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("ボスが現れた！")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.wrong)
                        .tracking(4)
                    if let boss = engine.boss {
                        Text(boss.rank.label)
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.backgroundBottom)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Theme.wrong, in: Capsule())
                    }
                }
                if let boss = engine.boss {
                    Text("「\(boss.cry)」")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                        .opacity(nameReveal ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.55), value: nameReveal)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label("正解すると攻撃。速く答えるほど大ダメージ（3 秒以内でクリティカル）", systemImage: "bolt.fill")
                    Label("不正解は反撃を受けてハートが 1 つ減る。3 回で敗北", systemImage: "heart.slash.fill")
                    Label("制限時間 \(Int(engine.timeLimit)) 秒以内に HP を 0 にすれば勝利", systemImage: "timer")
                    Label("連続正解でダメージが上がる", systemImage: "flame.fill")
                }
                .font(.footnote)
                .foregroundStyle(Theme.textPrimary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gameCard()
                Button {
                    GameFeedback.tap()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        engine.start()
                    }
                } label: {
                    Label("戦う", systemImage: "bolt.fill")
                }
                .buttonStyle(VoltButtonStyle())
                .padding(.top, 2)
            }
            .padding()
        }
        .onAppear {
            nameReveal = true
            GameFeedback.bossAppear()
        }
    }

    private func resultView(won: Bool) -> some View {
        VStack(spacing: 14) {
            Spacer()
            if let name = engine.boss?.name {
                Text(name)
                    .font(.headline.bold())
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(won ? "撃破！" : "敗北…")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(won ? Theme.volt : Theme.wrong)
                .shadow(color: (won ? Theme.volt : Theme.wrong).opacity(0.6), radius: 12)
            if !won, let reason = engine.loseReason {
                Text(reason == .timeout ? "時間切れ。もっと速く答えよう。" : "ハートがなくなった。落ち着いて正確に。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 8) {
                stat("タイム", StudyFormat.clock(engine.elapsed))
                stat("総ダメージ", "\(engine.totalDamage)")
                stat("最大ヒット", "\(engine.maxHit)")
                stat("最大コンボ", "\(engine.maxCombo)")
            }
            .padding(12)
            .gameCard()
            if won, let best = BossRecordStore.bestTime(route.unit.id) {
                Text("最速タイム \(StudyFormat.clock(best))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(spacing: 10) {
                Button(won ? "もう一度挑む" : "リベンジ") {
                    GameFeedback.tap()
                    engine.stop()
                    saved = false
                    timer.reset()
                    engine = BossEngine(unit: route.unit)
                    nameReveal = false
                    attachScheduler()
                    timer.start()
                }
                .buttonStyle(VoltButtonStyle())
                Button("戻る") {
                    GameFeedback.tap()
                    dismiss()
                }
                .buttonStyle(VoltButtonStyle(prominent: false))
            }
        }
        .padding()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(Theme.textSecondary)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 反撃の演出（画面全体）

    private func counterEffect() {
        redFlash = 0.45
        withAnimation(.easeOut(duration: 0.5)) { redFlash = 0 }
        let offsets: [CGSize] = [
            CGSize(width: 12, height: -4), CGSize(width: -10, height: 6), CGSize(width: 8, height: -3),
            CGSize(width: -5, height: 2), CGSize(width: 2, height: -1), .zero,
        ]
        for (i, offset) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.linear(duration: 0.05)) { screenShake = offset }
            }
        }
    }

    private func attachScheduler() {
        let scheduler = ReviewScheduler(context: modelContext)
        let unitId = route.unit.id
        engine.onAnswered = { question, correct in
            scheduler.record(question: question, unitId: unitId, correct: correct)
        }
    }

    private func saveIfNeeded() {
        guard !saved else { return }
        timer.pause()
        let seconds = min(timer.elapsed, StudyGoal.maxSecondsPerRecord)
        guard engine.answered > 0 else { return }
        modelContext.insert(StudyRecord(
            startedAt: timer.createdAt,
            durationSeconds: seconds,
            unitId: route.unit.id,
            answeredCount: engine.answered,
            correctCount: engine.correctCount,
            completed: engine.phase == .won
        ))
        saved = true
    }
}

// MARK: - モンスター

/// ボスの絵。呼吸・稲妻・被弾フラッシュ・ダメージ表示。
private struct BossMonsterView: View {
    let engine: BossEngine
    let imageName: String

    @State private var flash: Double = 0
    @State private var punch: CGFloat = 1.0
    @State private var shake: CGSize = .zero
    @State private var tint: Double = 0

    var body: some View {
        TimelineView(.animation(paused: engine.phase != .fighting && engine.phase != .intro)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let breath = 1.0 + 0.025 * sin(t * 1.6)
            let sway = sin(t * 0.7) * 1.2
            let defeated = engine.phase == .won

            ZStack {
                // 画面上部いっぱいに敷く。はみ出しは親（bossStage）が切る
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(defeated ? 0.94 : breath * punch)
                    .rotationEffect(.degrees(defeated ? 6 : sway))
                    .offset(shake)
                    .saturation(defeated ? 0.1 : 1.0)
                    .brightness(defeated ? -0.4 : 0)
                    .overlay(Color.red.opacity(tint))
                    .overlay(Color.white.opacity(flash))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: defeated)

                if !defeated {
                    lightning(time: t)
                        .allowsHitTesting(false)
                }

                if defeated {
                    Text("SHORT CIRCUIT!")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.volt)
                        .shadow(color: .black, radius: 6)
                        .rotationEffect(.degrees(-8))
                        .transition(.scale.combined(with: .opacity))
                }

                ForEach(engine.events) { event in
                    DamagePopup(event: event)
                }
            }
        }
        .onChange(of: engine.hitToken) { _, _ in hitEffect() }
        .onChange(of: engine.counterToken) { _, _ in counterEffect() }
    }

    /// 画面の端から中央へ走る稲妻。時間で種を変えてチラつかせる。
    private func lightning(time: Double) -> some View {
        Canvas { context, size in
            let intensity = engine.combo >= 3 ? 3 : 1
            let flicker = Int(time * 6) % 3 == 0
            guard flicker || intensity > 1 else { return }
            var rng = SeededGenerator(seed: UInt64(max(0, time) * 6))
            let w = Double(size.width)
            let h = Double(size.height)
            for _ in 0..<intensity {
                var path = Path()
                var x = Double.random(in: 0...w, using: &rng)
                var y = 0.0
                path.move(to: CGPoint(x: x, y: y))
                while y < h {
                    y += Double.random(in: 14...30, using: &rng)
                    x += Double.random(in: -22...22, using: &rng)
                    path.addLine(to: CGPoint(x: x, y: min(y, h)))
                }
                context.stroke(path, with: .color(Color.white.opacity(0.7)), lineWidth: 1.5)
                context.stroke(path, with: .color(Color(red: 0.55, green: 0.7, blue: 1.0).opacity(0.5)), lineWidth: 4)
            }
        }
    }

    private func hitEffect() {
        flash = 0.7
        punch = 0.94
        withAnimation(.easeOut(duration: 0.35)) { flash = 0 }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { punch = 1.0 }
        let offsets: [CGSize] = [CGSize(width: 9, height: -5), CGSize(width: -8, height: 4), CGSize(width: 5, height: -2), .zero]
        for (i, offset) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.linear(duration: 0.05)) { shake = offset }
            }
        }
    }

    private func counterEffect() {
        tint = 0.35
        punch = 1.08
        withAnimation(.easeOut(duration: 0.6)) { tint = 0 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { punch = 1.0 }
    }
}

/// 飛び出すダメージ数字。
private struct DamagePopup: View {
    let event: BossEngine.Event
    @State private var rise: CGFloat = 0
    @State private var fade: Double = 1
    @State private var pop: CGFloat = 0.4

    private var seedX: CGFloat {
        CGFloat(abs(event.id.hashValue % 120)) - 60
    }

    var body: some View {
        Group {
            switch event.kind {
            case .hit:
                VStack(spacing: 0) {
                    if event.critical {
                        Text("CRITICAL!")
                            .font(.caption.weight(.black))
                            .foregroundStyle(Theme.volt)
                    }
                    Text("-\(event.amount)")
                        .font(.system(size: event.critical ? 40 : 30, weight: .black, design: .rounded))
                        .foregroundStyle(event.critical ? Theme.volt : .white)
                }
                .shadow(color: .black.opacity(0.8), radius: 3)
            case .counter:
                Text("反撃！ -1 ♥")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.wrong)
                    .shadow(color: .black.opacity(0.8), radius: 3)
            }
        }
        .scaleEffect(pop)
        .offset(x: seedX, y: -20 - rise)
        .opacity(fade)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { pop = 1.0 }
            withAnimation(.easeOut(duration: 1.1)) { rise = 70 }
            withAnimation(.easeIn(duration: 0.5).delay(0.6)) { fade = 0 }
        }
    }
}

// MARK: - 問題（テンポ重視の簡易版）

private struct BossQuestionView: View {
    let engine: BossEngine
    let item: QuizSession.Item

    @State private var numberText = ""
    @FocusState private var focused: Bool
    private let labels = ["ア", "イ", "ウ", "エ", "オ", "カ"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.question.prompt)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gameCard()
                if let image = item.question.image {
                    QuestionFigureView(name: image)
                }
                switch item.question.type {
                case .choice:
                    ForEach(Array(item.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            engine.answerChoice(index)
                        } label: {
                            HStack(spacing: 10) {
                                Text(labels[index % labels.count])
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Theme.volt)
                                    .frame(width: 26, height: 26)
                                    .background(Theme.volt.opacity(0.18), in: Circle())
                                Text(choice)
                                    .foregroundStyle(Theme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .gameCard(tint: tint(isCorrect: index == item.correctIndex, isSelected: index == engine.selectedIndex),
                                      border: border(isCorrect: index == item.correctIndex, isSelected: index == engine.selectedIndex))
                        }
                        .buttonStyle(.plain)
                        .disabled(engine.isBusy)
                    }
                case .truefalse:
                    HStack(spacing: 12) {
                        tfButton(true, "circle", "正しい")
                        tfButton(false, "xmark", "誤り")
                    }
                case .number:
                    HStack(spacing: 10) {
                        TextField("数値", text: $numberText)
                            .keyboardType(.decimalPad)
                            .focused($focused)
                            .font(.title2.bold())
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .disabled(engine.isBusy)
                        if let unit = item.question.unit {
                            Text(unit).foregroundStyle(Theme.textSecondary)
                        }
                        Button("攻撃") {
                            if let v = Double(numberText.replacingOccurrences(of: ",", with: "")) {
                                focused = false
                                engine.answerNumber(v)
                            }
                        }
                        .buttonStyle(VoltButtonStyle())
                        .frame(width: 90)
                        .disabled(engine.isBusy || Double(numberText) == nil)
                    }
                    .padding(12)
                    .gameCard(tint: tint(isCorrect: engine.lastCorrect == true, isSelected: engine.lastCorrect != nil),
                              border: border(isCorrect: engine.lastCorrect == true, isSelected: engine.lastCorrect != nil))
                    .onAppear { focused = true }
                }
                if let correct = engine.lastCorrect {
                    HStack {
                        Label(correct ? "ヒット！ \(String(format: "%.1f", engine.lastAnswerSeconds)) 秒" : "ミス… 正解は上の緑",
                              systemImage: correct ? "bolt.fill" : "xmark.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(correct ? Theme.correct : Theme.wrong)
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            .padding()
        }
        .animation(.easeOut(duration: 0.2), value: engine.lastCorrect)
    }

    private func tfButton(_ value: Bool, _ symbol: String, _ title: String) -> some View {
        let isCorrect = item.question.answerBool == value
        let isSelected = engine.selectedBool == value
        return Button {
            engine.answerBool(value)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(value ? Theme.correct : Theme.wrong)
                Text(title).font(.subheadline.bold()).foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .gameCard(tint: tint(isCorrect: isCorrect, isSelected: isSelected), border: border(isCorrect: isCorrect, isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .disabled(engine.isBusy)
    }

    private func tint(isCorrect: Bool, isSelected: Bool) -> Color {
        guard engine.lastCorrect != nil else { return .clear }
        if isCorrect { return Theme.correct.opacity(0.2) }
        if isSelected { return Theme.wrong.opacity(0.2) }
        return .clear
    }

    private func border(isCorrect: Bool, isSelected: Bool) -> Color {
        guard engine.lastCorrect != nil else { return Theme.cardBorder }
        if isCorrect { return Theme.correct }
        if isSelected { return Theme.wrong }
        return Theme.cardBorder.opacity(0.5)
    }
}
