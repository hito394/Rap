import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    // Cross-tab navigation state
    @State private var selectedTrack: PickupTrack?
    @State private var navigateToTrack = false
    @State private var beginnerQuestion: String?
    @State private var navigateToSearch = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView(
                selectedTrack: $selectedTrack,
                navigateToTrack: $navigateToTrack,
                beginnerQuestion: $beginnerQuestion,
                navigateToSearch: $navigateToSearch
            )
            .tabItem { Label("ホーム", systemImage: "house.fill") }
            .tag(0)

            VideoSearchView()
                .tabItem { Label("動画", systemImage: "play.rectangle.fill") }
                .tag(1)

            TrackDecodeView(preselected: navigateToTrack ? selectedTrack : nil)
                .tabItem { Label("解説", systemImage: "music.note.list") }
                .tag(2)

            LyricsAnalyzeView()
                .tabItem { Label("解析", systemImage: "waveform.and.mic") }
                .tag(3)

            FreeSearchView(preseededQuestion: navigateToSearch ? beginnerQuestion : nil)
                .tabItem { Label("検索", systemImage: "magnifyingglass") }
                .tag(4)
        }
        .tint(Color.gold)
        .onChange(of: navigateToTrack) { _, newVal in
            if newVal { selectedTab = 2; navigateToTrack = false }
        }
        .onChange(of: navigateToSearch) { _, newVal in
            if newVal { selectedTab = 4; navigateToSearch = false }
        }
        .onAppear { applyAppearance() }
    }

    private func applyAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color(hex: "#0d0d0d"))

        let normalAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.gray]
        let selectedAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor(Color(hex: "#E8C84A"))]
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttr
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttr
        tabAppearance.stackedLayoutAppearance.normal.iconColor = .gray
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(hex: "#E8C84A"))
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color(hex: "#0d0d0d"))
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        ]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
