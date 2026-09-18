import SwiftUI

/// 教材の 1 ブロックを旧ゲームのテーマで描画する。
struct LessonBlockView: View {
    let block: LessonBlock

    var body: some View {
        switch block {
        case .paragraph(let text):
            Text(InlineMarkdown.attributed(text))
                .font(.body)
                .lineSpacing(7)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .strongLine(let text):
            Text(InlineMarkdown.attributed(text))
                .font(.headline)
                .foregroundStyle(Theme.volt)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•")
                            .foregroundStyle(Theme.volt)
                        Text(InlineMarkdown.attributed(item))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(5)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.backgroundBottom)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Theme.volt))
                        Text(InlineMarkdown.attributed(item))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(5)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .table(let table):
            LessonTableView(table: table)

        case .callout(let callout):
            LessonCalloutView(callout: callout)

        case .figure(let name):
            LessonFigureView(name: name)
        }
    }
}

// MARK: - 表

private struct LessonTableView: View {
    let table: LessonTable

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
            GridRow {
                ForEach(0..<table.columnCount, id: \.self) { column in
                    Text(table.cell(table.headers, column))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.volt)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 10)

            ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                Divider().overlay(Theme.cardBorder)
                GridRow {
                    ForEach(0..<table.columnCount, id: \.self) { column in
                        Text(InlineMarkdown.attributed(table.cell(row, column)))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 14)
        .gameCard()
    }
}

// MARK: - 注意・実務メモ

private struct LessonCalloutView: View {
    let callout: LessonCallout

    /// ⚠️ は間違えやすい点、🔌 は試験・実務とのつながり。
    private var tint: Color {
        switch callout.icon {
        case "⚠️": return Color(red: 1.0, green: 0.62, blue: 0.30)
        case "🔌": return Color(red: 0.40, green: 0.75, blue: 1.0)
        default: return Theme.textSecondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = callout.icon {
                Text(icon)
                    .font(.title3)
            }
            Text(InlineMarkdown.attributed(callout.text))
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .gameCard(tint: tint.opacity(0.12), border: tint.opacity(0.5))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 4)
        }
    }
}

// MARK: - 図

private struct LessonFigureView: View {
    let name: String

    var body: some View {
        Group {
            if UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .gameCard()
            } else {
                // Assets/figures/<name>.svg はまだ未作成。位置だけ示す。
                VStack(spacing: 6) {
                    Image(systemName: "photo.artframe")
                        .font(.title2)
                    Text(name)
                        .font(.caption.monospaced())
                }
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.cardBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )
            }
        }
    }
}

// MARK: - インライン記法

enum InlineMarkdown {
    /// `**…**` だけをボールドに変換する。サイズは呼び出し側の font を引き継ぐ。
    static func attributed(_ text: String) -> AttributedString {
        let parts = text.components(separatedBy: "**")
        // `**` の数が奇数だと対応が取れないので、そのまま返す。
        guard parts.count % 2 == 1 else { return AttributedString(text) }

        var result = AttributedString()
        for (index, part) in parts.enumerated() where !part.isEmpty {
            var chunk = AttributedString(part)
            if index.isMultiple(of: 2) == false {
                chunk.inlinePresentationIntent = .stronglyEmphasized
            }
            result.append(chunk)
        }
        return result
    }
}
