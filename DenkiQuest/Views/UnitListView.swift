import SwiftUI
import SwiftData

/// 単元一覧。タップすると 1 セッション（10 問）を開始する。
struct UnitListView: View {
    @State private var units: [LearningUnit] = []
    @State private var loadError: String?
    @AppStorage(SoundPlayer.enabledKey) private var soundEnabled = true
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @Query(sort: \StudyRecord.startedAt, order: .reverse) private var records: [StudyRecord]
    @State private var showStudyLog = false

    private var stats: StudyStats { StudyStats(records: records) }

    var body: some View {
        NavigationStack {
            ZStack {
                GameBackground()
                if let loadError {
                    ContentUnavailableView(
                        "教材を読み込めません",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                } else {
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
                            Text("クエストを選ぼう")
                                .font(.headline)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                            ForEach(units) { unit in
                                NavigationLink(value: unit) {
                                    UnitRow(unit: unit)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded { GameFeedback.tap() })
                            }
                        }
                        .padding()
                    }
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
            .sheet(isPresented: $showStudyLog) {
                StudyLogView(stats: stats, records: records, units: units)
            }
        }
        .task { load() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .shadow(color: Theme.volt.opacity(0.5), radius: 20)
            Text("1 クエスト = 10 問・約 5 分")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 4)
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
                Text(unit.stage.label)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.backgroundBottom)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.stageColor(unit.stage), in: Capsule())
                Text(unit.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(unit.description)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
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
