import SwiftUI

// 1 問ぶんの出題画面と、問題に添える図。
// ドリル（SessionView）・教材の差し込み問題（LessonSessionView）・ボス戦（図だけ）で使う。

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
                    if let images = item.choiceImages {
                        ImageChoiceGrid(
                            images: images,
                            captions: item.choices,
                            correctIndex: item.correctIndex,
                            selectedIndex: session.selectedIndex,
                            revealed: session.hasAnswered,
                            onSelect: { index in
                                session.answerChoice(index)
                                reactToAnswer()
                            }
                        )
                        .scaleEffect(session.hasAnswered && session.isCurrentCorrect ? correctScale : 1.0)
                        .offset(x: session.hasAnswered && !session.isCurrentCorrect ? shakeOffset : 0)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(item.choices.enumerated()), id: \.offset) { index, choice in
                                choiceButton(index: index, choice: choice)
                            }
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
        case .choice where item.choiceImages != nil: return ("図を選ぶ", "square.grid.2x2")
        case .choice where item.question.image != nil: return ("図を見て選ぶ", "photo")
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

/// 選択肢が図のときの 2 列の格子（imageChoice）。ドリル・教材・ボス戦で共用。
/// 回答後は正解を緑、選んだ誤答を赤で囲み、各図の名前（captions）を出す。
struct ImageChoiceGrid: View {
    let images: [String]
    let captions: [String]
    let correctIndex: Int
    let selectedIndex: Int?
    let revealed: Bool
    var compact: Bool = false
    let onSelect: (Int) -> Void

    private let labels = ["ア", "イ", "ウ", "エ", "オ", "カ"]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, name in
                tile(index: index, name: name)
            }
        }
    }

    private func tile(index: Int, name: String) -> some View {
        Button {
            onSelect(index)
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    figure(name)
                    Text(labels[index % labels.count])
                        .font(.caption.bold())
                        .foregroundStyle(labelColor(index))
                        .frame(width: 24, height: 24)
                        .background(labelBackground(index), in: Circle())
                        .padding(6)
                }
                if revealed, captions.indices.contains(index), !captions[index].isEmpty {
                    Text(captions[index])
                        .font(.caption.bold())
                        .foregroundStyle(index == correctIndex ? Theme.correct : Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
            }
            .padding(6)
            .gameCard(tint: tint(index), border: border(index))
            .overlay(alignment: .topTrailing) {
                if let icon = resultIcon(index) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(index == correctIndex ? Theme.correct : Theme.wrong)
                        .background(Circle().fill(Color.white))
                        .padding(10)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(revealed)
        .accessibilityLabel(Text("\(labels[index % labels.count])"))
    }

    @ViewBuilder
    private func figure(_ name: String) -> some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 96 : 128)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Label(name, systemImage: "photo.artframe")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 96 : 128)
        }
    }

    private func resultIcon(_ index: Int) -> String? {
        guard revealed else { return nil }
        if index == correctIndex { return "checkmark.circle.fill" }
        if index == selectedIndex { return "xmark.circle.fill" }
        return nil
    }

    private func tint(_ index: Int) -> Color {
        guard revealed else { return .clear }
        if index == correctIndex { return Theme.correct.opacity(0.18) }
        if index == selectedIndex { return Theme.wrong.opacity(0.18) }
        return .clear
    }

    private func border(_ index: Int) -> Color {
        guard revealed else { return Theme.cardBorder }
        if index == correctIndex { return Theme.correct }
        if index == selectedIndex { return Theme.wrong }
        return Theme.cardBorder.opacity(0.5)
    }

    private func labelColor(_ index: Int) -> Color {
        guard revealed else { return Theme.backgroundBottom }
        if index == correctIndex || index == selectedIndex { return Theme.backgroundBottom }
        return Theme.textSecondary
    }

    private func labelBackground(_ index: Int) -> Color {
        guard revealed else { return Theme.volt }
        if index == correctIndex { return Theme.correct }
        if index == selectedIndex { return Theme.wrong }
        return Color.white.opacity(0.6)
    }
}
