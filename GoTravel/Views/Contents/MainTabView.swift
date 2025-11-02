import SwiftUI
import MapKit

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            EnjoyWorldView()
                .tabItem{ Label("計画", systemImage: "text.pad.header.badge.clock") }
                .tag(0)
            CalendarView()
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(1)
            PlacesListView()
                .tabItem { Label("場所保存", systemImage: "figure.walk.suitcase.rolling") }
                .tag(2)
            AlbumHomeView()
                .tabItem { Label("アルバム", systemImage: "photo.artframe") }
                .tag(3)
        }
        .accentColor(.orange)
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue != newValue {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        }
    }
}
