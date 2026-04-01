import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LyricsAnalyzeView()
                .tabItem {
                    Label("解析", systemImage: "waveform.and.mic")
                }
                .tag(0)

            TrackDecodeView()
                .tabItem {
                    Label("解説", systemImage: "music.note.list")
                }
                .tag(1)

            FreeSearchView()
                .tabItem {
                    Label("検索", systemImage: "magnifyingglass")
                }
                .tag(2)
        }
        .tint(Color.gold)
        .background(Color.appBackground)
        .onAppear {
            // Tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color(hex: "#0d0d0d"))

            let normalAttr: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.gray
            ]
            let selectedAttr: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor(Color(hex: "#E8C84A"))
            ]
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttr
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttr
            appearance.stackedLayoutAppearance.normal.iconColor = .gray
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(hex: "#E8C84A"))

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            // Navigation bar
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithOpaqueBackground()
            navAppearance.backgroundColor = UIColor(Color(hex: "#0d0d0d"))
            navAppearance.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
            ]
            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
