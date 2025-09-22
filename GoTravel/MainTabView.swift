import SwiftUI
import MapKit

struct MainTabView: View {
    var body: some View {
        TabView {
            MapHomeView()
                .tabItem { Label("マップ", systemImage: "map") }
            PlacesListView()
                .tabItem { Label("保存済み", systemImage: "list.bullet") }
            HomeView()
                .tabItem { Label("マイページ", systemImage: "person") }
        }
    }
}
