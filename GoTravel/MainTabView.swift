import SwiftUI
import MapKit

struct MainTabView: View {
    var body: some View {
        TabView {
            MapHomeView()
                .tabItem { Label("マップ", systemImage: "map") }
            PlacesListView()
                .tabItem { Label("保存済み", systemImage: "list.bullet") }
            HomeView() // もし HomeView がプロファイルや設定なら
                .tabItem { Label("その他", systemImage: "person") }
        }
    }
}
