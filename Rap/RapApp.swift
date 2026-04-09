import SwiftUI
import SwiftData

@main
struct RapApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([HistoryItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData ModelContainer の作成に失敗しました: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .task {
                    AppConfiguration.debugPrint()          // Xcodeコンソールでキー確認
                    await TranscriptionService.autoDiscover()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
