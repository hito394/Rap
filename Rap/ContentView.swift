import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var selectedTrack: PickupTrack?
    @State private var navigateToTrack = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView(selectedTrack: $selectedTrack, navigateToTrack: $navigateToTrack)
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(0)

            TrackDecodeView(preselected: navigateToTrack ? selectedTrack : nil)
                .tabItem {
                    Label("解説", systemImage: "music.note.list")
                }
                .tag(1)

            LyricsAnalyzeView()
                .tabItem {
                    Label("解析", systemImage: "waveform.and.mic")
                }
                .tag(2)

            FreeSearchView()
                .tabItem {
                    Label("検索", systemImage: "magnifyingglass")
                }
                .tag(3)
        }
        .tint(Color.gold)
        .onChange(of: navigateToTrack) { _, newVal in
            if newVal {
                selectedTab = 1
                navigateToTrack = false
            }
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
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
