import SwiftUI

/// 経路案内に使う地図アプリを選ぶ
struct MapAppSettingView: View {
    @AppStorage(MapNavigator.preferenceKey) private var preference: String = MapApp.ask.rawValue
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var accentColor: Color {
        themeManager.currentTheme.adaptiveText(for: colorScheme)
    }

    var body: some View {
        // iPad・Mac の広い画面では、中身を読みやすい幅にそろえる（iPhone では何もしない）
        editorBody.readableFormWidth()
    }

    @ViewBuilder private var editorBody: some View {
        List {
            Section {
                // 「Google マップにしたのに、計画の地図が Apple のまま」とご質問をいただいた（3.3）。
                // アプリの中の地図は MapKit で描いているので、ここで変わるのは開くアプリだけ
                Text("旅行計画やおでかけの「経路案内」を押したときに開く地図アプリです。アプリの中に出る地図は、どれを選んでも Apple のマップで表示します。")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            Section {
                ForEach(MapApp.allCases) { app in
                    Button {
                        preference = app.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            Text(app.displayName)
                                .foregroundColor(accentColor)

                            Spacer()

                            if preference == app.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(themeManager.currentTheme.actionFill)
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } footer: {
                if preference == MapApp.google.rawValue && !MapNavigator.isGoogleMapsInstalled {
                    Text("Google マップのアプリが入っていないため、ブラウザで開きます。")
                }
            }
        }
        .navigationTitle("経路案内のアプリ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
