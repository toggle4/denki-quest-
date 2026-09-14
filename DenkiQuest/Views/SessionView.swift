import SwiftUI

/// 1 セッションの画面。問題 → 解説 → 次へ を繰り返し、最後に結果を表示する。
struct SessionView: View {
    @State private var session: QuizSession
    @Environment(\.dismiss) private var dismiss

    init(unit: LearningUnit) {
        _session = State(initialValue: QuizSession(unit: unit))
    }

    var body: some View {
        Group {
            if session.isFinished {
                ResultView(
                    session: session,
                    retry: { session = QuizSession(unit: session.unit) },
                    finish: { dismiss() }
                )
            } else if let item = session.current {
                QuestionView(session: session, item: item)
            } else {
                ContentUnavailableView("問題がありません", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle(session.unit.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 出題と回答後のフィードバック。
private struct QuestionView: View {
    let session: QuizSession
    let item: QuizSession.Item

    private let choiceLabels = ["ア", "イ", "ウ", "エ", "オ", "カ"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Text(item.question.prompt)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(Array(item.choices.enumerated()), id: \.offset) { index, choice in
                        choiceButton(index: index, choice: choice)
                    }
                }

                if session.hasAnswered {
                    feedback
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if session.hasAnswered {
                Button {
                    session.next()
                } label: {
                    Text(session.currentIndex + 1 < session.items.count ? "次へ" : "結果を見る")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.bar)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("第 \(session.currentIndex + 1) 問 / \(session.items.count) 問")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("正解 \(session.correctCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: session.progress)
        }
    }

    private func choiceButton(index: Int, choice: String) -> some View {
        Button {
            session.select(index)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(choiceLabels[index % choiceLabels.count])
                    .font(.headline)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.15), in: Circle())
                Text(choice)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let icon = resultIcon(for: index) {
                    Image(systemName: icon)
                        .font(.headline)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(choiceBackground(for: index), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor(for: index), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(session.hasAnswered)
    }

    private func resultIcon(for index: Int) -> String? {
        guard session.hasAnswered else { return nil }
        if index == item.correctIndex { return "checkmark.circle.fill" }
        if index == session.selectedIndex { return "xmark.circle.fill" }
        return nil
    }

    private func choiceBackground(for index: Int) -> Color {
        guard session.hasAnswered else { return Color(.secondarySystemBackground) }
        if index == item.correctIndex { return Color.green.opacity(0.2) }
        if index == session.selectedIndex { return Color.red.opacity(0.2) }
        return Color(.secondarySystemBackground)
    }

    private func borderColor(for index: Int) -> Color {
        guard session.hasAnswered else { return .clear }
        if index == item.correctIndex { return .green }
        if index == session.selectedIndex { return .red }
        return .clear
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                session.isCurrentCorrect ? "正解！" : "不正解",
                systemImage: session.isCurrentCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(session.isCurrentCorrect ? Color.green : Color.red)
            Text(item.question.explanation)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// セッション終了時の結果。
private struct ResultView: View {
    let session: QuizSession
    let retry: () -> Void
    let finish: () -> Void

    private var message: String {
        let total = session.items.count
        guard total > 0 else { return "" }
        switch Double(session.correctCount) / Double(total) {
        case 1.0: return "全問正解！この単元はばっちり。"
        case 0.8...: return "あと少し。間違えた問題の解説を読み返そう。"
        case 0.5...: return "半分以上正解。もう 1 セッションやってみよう。"
        default: return "まずは用語に慣れるところから。繰り返せば必ず覚えられる。"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
            Text("セッション終了")
                .font(.title.bold())
            Text("\(session.correctCount) / \(session.items.count) 問正解")
                .font(.title2)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            VStack(spacing: 12) {
                Button(action: retry) {
                    Text("もう一度")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                Button(action: finish) {
                    Text("単元一覧に戻る")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
