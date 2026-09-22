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
    @State private var showSurrender = false
    @State private var showBossDex = false
    @State private var timerPulse: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    init(route: BossRoute) {
        self.route = route
        _engine = State(initialValue: BossEngine(unit: route.unit))
    }

    var body: some View {
        GeometryReader { geo in
            // 画像は画面いちばん上まで敷く。セーフエリアぶんも使う。
            // 横幅はここで数値に決めて、以降すべて frame(width:) で固定する。
            // 提案幅の伝わり方に任せると、scaledToFill の絵に押し広げられる。
            let topInset = geo.safeAreaInsets.top
            let screenWidth = geo.size.width
            let stageHeight = max((geo.size.height + topInset) * 0.46, 200)
            ZStack {
                GameBackground()
                VStack(spacing: 0) {
                    bossStage(width: screenWidth, height: stageHeight, topInset: topInset)
                    content
                        .frame(width: screenWidth)
                }
                .offset(screenShake)
                Color.red
                    .opacity(redFlash)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .frame(width: screenWidth)
            .frame(maxHeight: .infinity, alignment: .top)
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
        .onChange(of: engine.warnToken) { _, _ in timeWarningEffect() }
        .onChange(of: engine.phase) { _, phase in
            if phase == .won || phase == .lost { saveIfNeeded() }
        }
        .sheet(isPresented: $showBossDex) {
            BossCollectionView()
        }
        .confirmationDialog("降参しますか？", isPresented: $showSurrender, titleVisibility: .visible) {
            Button("降参する", role: .destructive) {
                GameFeedback.wrong()
                engine.surrender()
            }
            Button("続ける", role: .cancel) {}
        } message: {
            Text("ここまでの学習時間と、間違えた問題の復習予約は残ります。")
        }
    }

    private var isInBattle: Bool {
        engine.phase == .fighting || engine.phase == .countdown
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
    ///
    /// 絵は background に置く。scaledToFill した画像は提案された幅より大きい寸法を
    /// 返すため、ZStack の子として並べると土台の横幅ごと広がり、重ねたバーや
    /// ハートが画面外へはみ出す。background なら親の大きさに従うので広がらない。
    private func bossStage(width: CGFloat, height: CGFloat, topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            statusBar
                // 幅を数値で決め打ちする。これで何が来ても画面外へ出ない
                .frame(width: max(width - 28, 120))
                .padding(.bottom, 8)
        }
        .frame(width: width, height: height)
        .background(alignment: .center) {
            ZStack {
                BossMonsterView(engine: engine, imageName: bossImageName)
                LinearGradient(
                    colors: [.clear,
                             Theme.backgroundBottom.opacity(0.45),
                             Theme.backgroundBottom.opacity(0.92)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
        }
        .clipped()
        .overlay(alignment: .topLeading) { backButton(topInset: topInset) }
        .overlay(alignment: .topTrailing) { surrenderButton(topInset: topInset) }
    }

    /// 戦いの途中で抜けるためのボタン。閉じ込めない。
    private func surrenderButton(topInset: CGFloat) -> some View {
        Button {
            GameFeedback.tap()
            showSurrender = true
        } label: {
            Image(systemName: "flag.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.45), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        }
        .padding(.trailing, 14)
        .padding(.top, topInset + 6)
        .opacity(isInBattle ? 1 : 0)
        .allowsHitTesting(isInBattle)
        .animation(.easeOut(duration: 0.25), value: engine.phase)
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

    /// 名前を中央に大きく、その下に BOSS バッジ・HP バー・数値と時間・ハート。
    private var statusBar: some View {
        VStack(spacing: 6) {
            nameLine
            badgeLine
            hpBar
            numbersLine
            timeBar
        }
    }

    private var nameLine: some View {
        Text(displayName)
            .font(.system(size: 26, weight: .black, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .shadow(color: .black.opacity(0.9), radius: 6)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity)
            .scaleEffect(nameReveal ? 1 : 1.25)
            .opacity(nameReveal ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.15), value: nameReveal)
    }

    private var badgeLine: some View {
        HStack(spacing: 6) {
            Label("BOSS", systemImage: "bolt.trianglebadge.exclamationmark.fill")
                .font(.caption2.bold())
                .foregroundStyle(Theme.wrong)
                .shadow(color: .black.opacity(0.9), radius: 3)
            if engine.isEnraged {
                Text("ENRAGED")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Theme.backgroundBottom)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.wrong, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: engine.isEnraged)
    }

    private var hpBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.45))
                Capsule()
                    .fill(LinearGradient(colors: [Theme.wrong, Color(red: 1.0, green: 0.6, blue: 0.3)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(engine.bossHP) / CGFloat(max(engine.maxHP, 1)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: engine.bossHP)
            }
        }
        .frame(height: 13)
    }

    private var numbersLine: some View {
        HStack(spacing: 10) {
            Text("HP \(engine.bossHP) / \(engine.maxHP)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                .shadow(color: .black.opacity(0.9), radius: 3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            if engine.combo >= 2 {
                Text("\(engine.combo) COMBO")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.backgroundBottom)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.volt, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            Label(StudyFormat.clock(engine.remaining), systemImage: "timer")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(engine.remaining < 15 ? Theme.wrong : Theme.textPrimary)
                .shadow(color: .black.opacity(0.9), radius: 3)
                .scaleEffect(timerPulse)
                .fixedSize()
                .layoutPriority(1)
            hearts
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: engine.combo)
    }

    private var hearts: some View {
        HStack(spacing: 4) {
            ForEach(0..<BossEngine.maxHearts, id: \.self) { index in
                Image(systemName: index < engine.hearts ? "heart.fill" : "heart")
                    .foregroundStyle(index < engine.hearts ? Theme.wrong : Color.white.opacity(0.35))
            }
        }
        .font(.subheadline)
        .shadow(color: .black.opacity(0.9), radius: 3)
        .fixedSize()
        .layoutPriority(2)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: engine.hearts)
    }

    private var timeBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.4))
                Capsule()
                    .fill(engine.remaining < 15 ? Theme.wrong : Theme.volt)
                    .frame(width: geo.size.width * CGFloat(engine.remaining / max(engine.timeLimit, 1)))
            }
        }
        .frame(height: 5)
    }

    // MARK: - 下部

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .intro:
            introView
        case .countdown:
            countdownView
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

    /// 3・2・1・GO!。ここではまだ制限時間は減らない。
    private var countdownView: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Text(engine.countdown > 0 ? "\(engine.countdown)" : "GO!")
                .font(.system(size: engine.countdown > 0 ? 104 : 72, weight: .black, design: .rounded))
                .foregroundStyle(engine.countdown > 0 ? Theme.textPrimary : Theme.volt)
                .shadow(color: Theme.volt.opacity(0.7), radius: 18)
                .id(engine.countdown)
                .transition(.scale(scale: 1.7).combined(with: .opacity))
            Text("速く答えるほど大ダメージ。3 秒以内でクリティカル")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.6),
                   value: engine.countdown)
    }

    /// 登場演出。名前（intro のあいだは二つ名つき）は画像の上に重ねて出す。
    private var introView: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("ボスが現れた！")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.wrong)
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
                    Label("答えたあとの解説を読んでいる間は、時間が止まる", systemImage: "pause.circle.fill")
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
        let surrendered = engine.loseReason == .surrender
        return ScrollView {
            VStack(spacing: 14) {
                if let name = engine.boss?.name {
                    Text(name)
                        .font(.headline.bold())
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(won ? "撃破！" : (surrendered ? "撤退" : "敗北…"))
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(won ? Theme.volt : Theme.wrong)
                    .shadow(color: (won ? Theme.volt : Theme.wrong).opacity(0.6), radius: 12)
                rankBadge(won: won)
                if !won {
                    Text(loseMessage)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    stat("タイム", StudyFormat.clock(engine.elapsed))
                    stat("正解", "\(engine.correctCount) / \(engine.answered)")
                    stat("最大ヒット", "\(engine.maxHit)")
                    stat("最大コンボ", "\(engine.maxCombo)")
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .gameCard()
                recordLine(won: won)
                if !engine.missed.isEmpty {
                    missedCard
                }
                VStack(spacing: 10) {
                    Button(won ? "もう一度挑む" : "リベンジ", action: restart)
                        .buttonStyle(VoltButtonStyle())
                    if won, engine.boss != nil {
                        Button {
                            GameFeedback.tap()
                            showBossDex = true
                        } label: {
                            Label("ボス図鑑で見る", systemImage: "books.vertical.fill")
                        }
                        .buttonStyle(VoltButtonStyle(prominent: false))
                    }
                    Button("戻る") {
                        GameFeedback.tap()
                        dismiss()
                    }
                    .buttonStyle(VoltButtonStyle(prominent: false))
                }
                .padding(.top, 4)
            }
            .padding()
        }
    }

    private func restart() {
        GameFeedback.tap()
        engine.stop()
        saved = false
        timer.reset()
        engine = BossEngine(unit: route.unit)
        nameReveal = false
        attachScheduler()
        timer.start()
    }

    private var loseMessage: String {
        guard let reason = engine.loseReason else { return "" }
        switch reason {
        case .timeout: return "時間切れ。1 問 3 秒を目標にすると、ダメージが 2 倍になる。"
        case .hearts: return "ハートがなくなった。下の見直しを読んでから、もう一度挑もう。"
        case .surrender: return "ここまでの学習時間は記録した。間違えた問題は復習に回してある。"
        }
    }

    /// 勝ったときだけランクを出す。無傷と速さで決まる。
    @ViewBuilder
    private func rankBadge(won: Bool) -> some View {
        if won {
            let info = rankInfo
            HStack(spacing: 10) {
                Text(info.label)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(info.color)
                    .frame(width: 54, height: 54)
                    .background(info.color.opacity(0.15), in: Circle())
                    .overlay(Circle().strokeBorder(info.color, lineWidth: 2))
                Text(info.note)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .gameCard(tint: info.color.opacity(0.06), border: info.color.opacity(0.4))
        }
    }

    private var rankInfo: (label: String, color: Color, note: String) {
        let noDamage = engine.hearts == BossEngine.maxHearts
        let ratio = engine.elapsed / max(engine.timeLimit, 1)
        if noDamage && ratio <= 0.4 {
            return ("S", Theme.volt, "無傷で圧勝。この単元は仕上がっている。")
        }
        if noDamage {
            return ("A", Theme.correct, "無傷で撃破。あとは速さだけ。")
        }
        if ratio <= 0.7 {
            return ("B", Color(red: 0.40, green: 0.75, blue: 1.0), "速さは十分。あとは取りこぼしを減らそう。")
        }
        return ("C", Theme.textSecondary, "撃破はできた。下の見直しで取りこぼしをつぶそう。")
    }

    @ViewBuilder
    private func recordLine(won: Bool) -> some View {
        if won {
            let defeats = engine.boss.map { BossCollection.record(for: $0.id).defeats } ?? 0
            HStack(spacing: 12) {
                if let best = BossRecordStore.bestTime(route.unit.id) {
                    Label("最速 \(StudyFormat.clock(best))", systemImage: "stopwatch")
                }
                if defeats > 0 {
                    Label("通算 \(defeats) 回", systemImage: "crown.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.volt)
        }
    }

    /// 間違えた問題の見直し。ここが一番の学習ポイント。
    private var missedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("取りこぼした \(engine.missed.count) 問", systemImage: "arrow.uturn.left.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.wrong)
            ForEach(engine.missed, id: \.id) { question in
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.prompt)
                        .font(.footnote.bold())
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(question.explanation)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("この問題は明日もう一度出る。")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameCard(tint: Theme.wrong.opacity(0.06), border: Theme.wrong.opacity(0.4))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(Theme.textSecondary)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 残り 10 秒・5 秒でタイマーを脈打たせる。
    private func timeWarningEffect() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) { timerPulse = 1.45 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { timerPulse = 1 }
        }
    }

    // MARK: - 反撃の演出（画面全体）

    private func counterEffect() {
        redFlash = reduceMotion ? 0.25 : 0.45
        withAnimation(.easeOut(duration: 0.5)) { redFlash = 0 }
        guard !reduceMotion else { return }
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flash: Double = 0
    @State private var punch: CGFloat = 1.0
    @State private var shake: CGSize = .zero
    @State private var tint: Double = 0

    var body: some View {
        TimelineView(.animation(paused: engine.phase == .won || engine.phase == .lost)) { context in
            let t: Double = context.date.timeIntervalSinceReferenceDate
            let enraged: Bool = engine.isEnraged
            let breathDepth: Double = enraged ? 0.05 : 0.025
            let breathSpeed: Double = enraged ? 3.4 : 1.6
            let breath: Double = 1.0 + breathDepth * sin(t * breathSpeed)
            let swaySpeed: Double = enraged ? 1.6 : 0.7
            let swayDepth: Double = enraged ? 2.4 : 1.2
            let sway: Double = sin(t * swaySpeed) * swayDepth
            let rage: Double = enraged ? 0.10 + 0.06 * abs(sin(t * 4.0)) : 0.0
            let defeated: Bool = engine.phase == .won

            ZStack {
                // 画面上部いっぱいに敷く。
                // scaledToFill した画像は提案より大きい寸法を返すので、
                // Color.clear の overlay に入れて親の大きさを超えないようにする
                Color.clear
                    .overlay {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(defeated ? 0.94 : breath * punch)
                            .rotationEffect(.degrees(defeated ? 6 : sway))
                            .offset(shake)
                            .saturation(defeated ? 0.1 : 1.0)
                            .brightness(defeated ? -0.4 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: defeated)
                    }
                    .overlay(Color.red.opacity(tint + rage))
                    .overlay(Color.white.opacity(flash))
                    .clipped()

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
            let intensity: Int = engine.isEnraged ? 4 : (engine.combo >= 3 ? 3 : 1)
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
        guard !reduceMotion else { return }
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

/// 速く答えるほど倍率が高いことを見せるゲージ。減っていくのが目で分かる。
private struct SpeedGauge: View {
    let engine: BossEngine

    var body: some View {
        TimelineView(.animation(paused: engine.isBusy)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(engine.questionShownAt))
            let multiplier = BossEngine.speedMultiplier(elapsed)
            let progress = max(0, min(1, 1 - elapsed / 10))
            HStack(spacing: 8) {
                Text("ダメージ ×\(String(format: "%.1f", multiplier))")
                    .font(.caption.monospacedDigit().weight(.black))
                    .foregroundStyle(Self.color(multiplier))
                    .frame(width: 96, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(Self.color(multiplier))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 6)
                Text("あと \(engine.estimatedHitsLeft) 発")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(height: 18)
    }

    private static func color(_ multiplier: Double) -> Color {
        switch multiplier {
        case 2.0...: return Theme.volt
        case 1.5...: return Theme.correct
        case 1.2...: return Color(red: 0.40, green: 0.75, blue: 1.0)
        default: return Theme.textSecondary
        }
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

// MARK: - 問題（テンポ重視。外したらその場で解説を読ませる）

private struct BossQuestionView: View {
    let engine: BossEngine
    let item: QuizSession.Item

    @State private var numberText = ""
    @FocusState private var focused: Bool
    private let labels = ["ア", "イ", "ウ", "エ", "オ", "カ"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SpeedGauge(engine: engine)
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
                            .submitLabel(.go)
                            .onSubmit(attack)
                            .focused($focused)
                            .font(.title2.bold())
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .disabled(engine.isBusy)
                        if let unit = item.question.unit {
                            Text(unit).foregroundStyle(Theme.textSecondary)
                        }
                        Button("攻撃", action: attack)
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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(correct
                                  ? "ヒット！ \(String(format: "%.1f", engine.lastAnswerSeconds)) 秒　×\(String(format: "%.1f", BossEngine.speedMultiplier(engine.lastAnswerSeconds)))"
                                  : "ミス… 正解は緑の選択肢",
                                  systemImage: correct ? "bolt.fill" : "xmark.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(correct ? Theme.correct : Theme.wrong)
                            Spacer(minLength: 0)
                        }
                        // 外したときはその場で理由を読ませる（この間は時間が止まる）
                        if !correct {
                            Text(item.question.explanation)
                                .font(.footnote)
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gameCard(tint: (correct ? Theme.correct : Theme.wrong).opacity(0.10),
                              border: (correct ? Theme.correct : Theme.wrong).opacity(0.5))
                    .transition(.opacity)
                }
            }
            .padding()
        }
        .animation(.easeOut(duration: 0.2), value: engine.lastCorrect)
    }

    private func attack() {
        guard let value = Double(numberText.replacingOccurrences(of: ",", with: "")) else { return }
        focused = false
        engine.answerNumber(value)
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
