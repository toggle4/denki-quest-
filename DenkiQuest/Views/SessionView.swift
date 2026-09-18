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

    init(unit: LearningUnit) {
        _session = State(initialValue: QuizSession(unit: unit))
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
                        session = QuizSession(unit: session.unit)
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
        .onAppear { timer.start() }
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

/// 出題と回答後のフィードバック。ドリル（SessionView）と教材の差し込み問題（LessonSessionView）で共用。
struct QuestionView: View {
    let session: QuizSession
    let item: QuizSession.Item
    let timer: StudyTimer
    /// 「第 n 問 / N 問」の代わりに出す文言（教材の差し込み問題用）
    var progressLabel: String? = nil
    /// 最後の問題の「次へ」ボタンの文言
    var lastButtonTitle: String = "結果を見る"

    @State private var shakeOffset: CGFloat = 0
    @State private var correctScale: CGFloat = 1.0
    @State private var comboScale: CGFloat = 1.0
    @State private var numberText = ""
    @FocusState private var numberFocused: Bool

    private let choiceLabels = ["ア", "イ", "ウ", "エ", "オ", "カ"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                promptCard

                switch item.question.type {
                case .choice:
                    VStack(spacing: 10) {
                        ForEach(Array(item.choices.enumerated()), id: \.offset) { index, choice in
                            choiceButton(index: index, choice: choice)
                        }
                    }
                case .truefalse:
                    trueFalseButtons
                case .number:
                    numberInput
                }

                if !session.hasAnswered && item.question.hint != nil {
                    hintArea
                }

                if session.hasAnswered {
                    feedback
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: session.hasAnswered)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: session.hintUsed)
        .safeAreaInset(edge: .bottom) {
            if session.hasAnswered {
                Button {
                    GameFeedback.tap()
                    session.next()
                } label: {
                    Text(session.currentIndex + 1 < session.items.count ? "次へ" : lastButtonTitle)
                }
                .buttonStyle(VoltButtonStyle())
                .padding()
                .background(.ultraThinMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progressLabel ?? "第 \(session.currentIndex + 1) 問 / \(session.items.count) 問")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Label(StudyFormat.clock(timer.elapsed), systemImage: "hourglass")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if session.combo >= 2 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(session.combo) COMBO")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.backgroundBottom)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.volt, in: Capsule())
                    .scaleEffect(comboScale)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            ProgressView(value: session.progress)
                .tint(Theme.volt)
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: session.combo)
    }

    private var typeBadge: (label: String, icon: String) {
        switch item.question.type {
        case .choice: return ("4 択", "list.bullet")
        case .truefalse: return ("○×", "circle.circle")
        case .number: return ("数値入力", "number")
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(typeBadge.label, systemImage: typeBadge.icon)
                .font(.caption.bold())
                .foregroundStyle(Theme.volt)
            Text(item.question.prompt)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let image = item.question.image {
                QuestionFigureView(name: image)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameCard()
    }

    // MARK: - 4 択

    private func choiceButton(index: Int, choice: String) -> some View {
        Button {
            session.answerChoice(index)
            reactToAnswer()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(choiceLabels[index % choiceLabels.count])
                    .font(.headline)
                    .foregroundStyle(labelColor(for: index))
                    .frame(width: 30, height: 30)
                    .background(labelBackground(for: index), in: Circle())
                Text(choice)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let icon = resultIcon(for: index) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(index == item.correctIndex ? Theme.correct : Theme.wrong)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gameCard(tint: tint(for: index), border: border(for: index))
        }
        .buttonStyle(.plain)
        .disabled(session.hasAnswered)
        .scaleEffect(session.hasAnswered && index == item.correctIndex ? correctScale : 1.0)
        .offset(x: session.hasAnswered && index == session.selectedIndex && !session.isCurrentCorrect ? shakeOffset : 0)
    }

    private func resultIcon(for index: Int) -> String? {
        guard session.hasAnswered else { return nil }
        if index == item.correctIndex { return "checkmark.circle.fill" }
        if index == session.selectedIndex { return "xmark.circle.fill" }
        return nil
    }

    private func tint(for index: Int) -> Color {
        guard session.hasAnswered else { return .clear }
        if index == item.correctIndex { return Theme.correct.opacity(0.18) }
        if index == session.selectedIndex { return Theme.wrong.opacity(0.18) }
        return .clear
    }

    private func border(for index: Int) -> Color {
        guard session.hasAnswered else { return Theme.cardBorder }
        if index == item.correctIndex { return Theme.correct }
        if index == session.selectedIndex { return Theme.wrong }
        return Theme.cardBorder.opacity(0.5)
    }

    private func labelColor(for index: Int) -> Color {
        guard session.hasAnswered else { return Theme.volt }
        if index == item.correctIndex || index == session.selectedIndex { return Theme.backgroundBottom }
        return Theme.textSecondary
    }

    private func labelBackground(for index: Int) -> Color {
        guard session.hasAnswered else { return Theme.volt.opacity(0.18) }
        if index == item.correctIndex { return Theme.correct }
        if index == session.selectedIndex { return Theme.wrong }
        return Color.white.opacity(0.08)
    }

    // MARK: - ○×

    private var trueFalseButtons: some View {
        HStack(spacing: 14) {
            trueFalseButton(value: true, symbol: "circle", title: "正しい")
            trueFalseButton(value: false, symbol: "xmark", title: "誤り")
        }
    }

    private func trueFalseButton(value: Bool, symbol: String, title: String) -> some View {
        let isCorrectAnswer = item.question.answerBool == value
        let isSelected = session.selectedBool == value
        let tintColor: Color = {
            guard session.hasAnswered else { return .clear }
            if isCorrectAnswer { return Theme.correct.opacity(0.18) }
            if isSelected { return Theme.wrong.opacity(0.18) }
            return .clear
        }()
        let borderColor: Color = {
            guard session.hasAnswered else { return Theme.cardBorder }
            if isCorrectAnswer { return Theme.correct }
            if isSelected { return Theme.wrong }
            return Theme.cardBorder.opacity(0.5)
        }()
        let symbolColor: Color = {
            guard session.hasAnswered else { return value ? Theme.correct : Theme.wrong }
            if isCorrectAnswer { return Theme.correct }
            if isSelected { return Theme.wrong }
            return Theme.textSecondary
        }()

        return Button {
            session.answerBool(value)
            reactToAnswer()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(symbolColor)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .gameCard(tint: tintColor, border: borderColor)
        }
        .buttonStyle(.plain)
        .disabled(session.hasAnswered)
        .scaleEffect(session.hasAnswered && isCorrectAnswer ? correctScale : 1.0)
        .offset(x: session.hasAnswered && isSelected && !session.isCurrentCorrect ? shakeOffset : 0)
    }

    // MARK: - 数値入力

    private var numberInput: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("数値を入力", text: $numberText)
                    .keyboardType(.decimalPad)
                    .focused($numberFocused)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .disabled(session.hasAnswered)
                    .submitLabel(.done)
                if let unit = item.question.unit {
                    Text(unit)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(16)
            .gameCard(
                tint: numberTint,
                border: numberBorder
            )
            .offset(x: session.hasAnswered && !session.isCurrentCorrect ? shakeOffset : 0)
            .scaleEffect(session.hasAnswered && session.isCurrentCorrect ? correctScale : 1.0)

            if !session.hasAnswered {
                Button {
                    submitNumber()
                } label: {
                    Text("回答する")
                }
                .buttonStyle(VoltButtonStyle())
                .disabled(parsedNumber == nil)
                .opacity(parsedNumber == nil ? 0.5 : 1)
            } else if !session.isCurrentCorrect {
                Text("正解: \(formatNumber(item.question.answerNumber)) \(item.question.unit ?? "")")
                    .font(.headline)
                    .foregroundStyle(Theme.correct)
            }
        }
        .onAppear { numberFocused = true }
        .onSubmit { submitNumber() }
    }

    private var parsedNumber: Double? {
        let normalized = numberText
            .replacingOccurrences(of: "，", with: ".")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(normalized)
    }

    private var numberTint: Color {
        guard session.hasAnswered else { return .clear }
        return (session.isCurrentCorrect ? Theme.correct : Theme.wrong).opacity(0.18)
    }

    private var numberBorder: Color {
        guard session.hasAnswered else { return numberFocused ? Theme.volt : Theme.cardBorder }
        return session.isCurrentCorrect ? Theme.correct : Theme.wrong
    }

    private func submitNumber() {
        guard !session.hasAnswered, let value = parsedNumber else { return }
        numberFocused = false
        session.answerNumber(value)
        reactToAnswer()
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }

    // MARK: - ヒント

    private var hintArea: some View {
        Group {
            if session.hintUsed, let hint = item.question.hint {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Theme.volt)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ヒント")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.volt)
                        Text(hint)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gameCard(tint: Theme.volt.opacity(0.08), border: Theme.volt.opacity(0.5))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                Button {
                    GameFeedback.tap()
                    session.useHint()
                } label: {
                    Label("ヒントを見る（コンボは増えません）", systemImage: "lightbulb")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.volt)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Theme.volt.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 回答後

    private func reactToAnswer() {
        if session.isCurrentCorrect {
            GameFeedback.correct(combo: session.combo)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                correctScale = 1.06
                comboScale = 1.25
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.15)) {
                correctScale = 1.0
                comboScale = 1.0
            }
        } else {
            GameFeedback.wrong()
            withAnimation(.linear(duration: 0.06).repeatCount(5, autoreverses: true)) {
                shakeOffset = 8
            }
            withAnimation(.linear(duration: 0.06).delay(0.36)) {
                shakeOffset = 0
            }
        }
    }

    private func extraRow(icon: String, label: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(color)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    session.isCurrentCorrect ? "正解！" : "ざんねん…",
                    systemImage: session.isCurrentCorrect ? "checkmark.seal.fill" : "xmark.seal.fill"
                )
                .font(.headline)
                .foregroundStyle(session.isCurrentCorrect ? Theme.correct : Theme.wrong)
                Spacer()
                if session.hintUsed {
                    Label("ヒント使用", systemImage: "lightbulb.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.volt)
                }
            }
            Text(item.question.explanation)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let origin = item.question.origin {
                extraRow(icon: "character.book.closed.fill", label: "英語で覚える", text: origin,
                         color: Color(red: 0.40, green: 0.75, blue: 1.0))
            }
            if let tip = item.question.tip {
                extraRow(icon: "wrench.and.screwdriver.fill", label: "現場では", text: tip,
                         color: Color(red: 1.0, green: 0.62, blue: 0.30))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameCard(
            tint: (session.isCurrentCorrect ? Theme.correct : Theme.wrong).opacity(0.10),
            border: (session.isCurrentCorrect ? Theme.correct : Theme.wrong).opacity(0.6)
        )
    }
}

/// 問題に添える図（Assets の名前）。未作成なら名前だけ示す。
struct QuestionFigureView: View {
    let name: String

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.cardBorder, lineWidth: 1)
                )
        } else {
            Label("図: \(name)（未作成）", systemImage: "photo.artframe")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
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
                        Label(BossRecordStore.isCleared(session.unit.id) ? "ボス戦にもう一度挑む" : "ボス戦に挑む", systemImage: "bolt.trianglebadge.exclamationmark.fill")
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
