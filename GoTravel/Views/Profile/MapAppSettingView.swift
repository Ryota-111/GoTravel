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
        List {
            Section {
                Text("旅行計画やおでかけの「経路案内」で開く地図アプリです。")
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
