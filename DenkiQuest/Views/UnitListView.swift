import SwiftUI

/// 単元一覧。タップすると 1 セッション（10 問）を開始する。
struct UnitListView: View {
    @State private var units: [LearningUnit] = []
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let loadError {
                    ContentUnavailableView(
                        "教材を読み込めません",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                } else {
                    List(units) { unit in
                        NavigationLink(value: unit) {
                            UnitRow(unit: unit)
                        }
                    }
                }
            }
            .navigationTitle("でんきクエスト")
            .navigationDestination(for: LearningUnit.self) { unit in
                SessionView(unit: unit)
            }
        }
        .task { load() }
    }

    private func load() {
        do {
            units = try ContentLoader.loadUnits()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct UnitRow: View {
    let unit: LearningUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(unit.stage.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                Text(unit.title)
                    .font(.headline)
            }
            Text(unit.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(unit.questions.count) 問")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    UnitListView()
}
