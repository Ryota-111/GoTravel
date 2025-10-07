import SwiftUI
import MapKit

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            EnjoyWorldView()
                .tabItem{ Label("予定", systemImage: "calendar") }
                .tag(0)
            MapHomeView()
                .tabItem { Label("マップ", systemImage: "map") }
                .tag(1)
            PlacesListView()
                .tabItem { Label("保存済み", systemImage: "list.bullet") }
                .tag(2)
            HomeView()
                .tabItem { Label("マイページ", systemImage: "person") }
                .tag(3)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue != newValue {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        }
    }
}
