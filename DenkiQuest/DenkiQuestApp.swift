import SwiftUI
import SwiftData

@main
struct DenkiQuestApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            SoundPlayer.enabledKey: true,
            Haptics.enabledKey: true,
        ])
    }

    var body: some Scene {
        WindowGroup {
            UnitListView()
                .preferredColorScheme(.dark)
                .tint(Theme.volt)
        }
        .modelContainer(for: StudyRecord.self)
    }
}
