import SwiftUI
import MapKit

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var showICloudAlert = false
    @State private var hasCheckedICloud = false
    @StateObject private var plansViewModel = PlansViewModel()
    @StateObject private var travelPlanViewModel = TravelPlanViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            EnjoyWorldView()
                .tabItem{ Label("計画", systemImage: "list.clipboard") }
                .tag(0)
            CalendarView()
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(1)
            PlacesListView()
                .tabItem { Label("場所保存", systemImage: "mappin.and.ellipse") }
                .tag(2)
            AlbumHomeView()
                .tabItem { Label("アルバム", systemImage: "photo.artframe") }
                .tag(3)
        }
        .environmentObject(plansViewModel)
        .environmentObject(travelPlanViewModel)
        .accentColor(.orange)
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue != newValue {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        }
        .task {
            if !hasCheckedICloud {
                hasCheckedICloud = true
                await checkICloudStatus()
            }
        }
        .alert("iCloudが必要です", isPresented: $showICloudAlert) {
            Button("設定を開く", role: .none) {
                if let url = URL(string: "App-prefs:CASTLE") {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("このアプリはデータを保存するためにiCloudを使用します。iCloudにサインインしてください。\n\n設定 > [あなたの名前] > iCloud")
        }
    }

    private func checkICloudStatus() async {
        let isAvailable = await CloudKitService.shared.isICloudAvailable()
        if !isAvailable {
            showICloudAlert = true
        }
    }
}
