import SwiftUI
import MapKit

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            EnjoyWorldView()
                .tabItem{ Label("予定", systemImage: "calendar") }
                .tag(0)
            PlacesListView()
                .tabItem { Label("場所保存", systemImage: "list.bullet") }
                .tag(1)
            JapanPhotoView()
                .tabItem { Label("全国フォトマップ", systemImage: "photo.artframe") }
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
