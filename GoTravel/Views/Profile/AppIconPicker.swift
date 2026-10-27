import SwiftUI

/// ホーム画面のアイコン（Travory Pro）。
/// 別の絵を、代わりのアイコンとして入れてある（`AppIcon-*`。ビルド設定の
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` に並べたもの）
enum AppIconOption: String, CaseIterable, Identifiable {
    case standard = "Default"
    case desk = "Desk"
    case globe = "Globe"
    case window = "Window"
    case skySea = "SkySea"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: return "いつもの"
        case .desk: return "旅の計画"
        case .globe: return "空と地球"
        case .window: return "窓の景色"
        case .skySea: return "空と海"
        }
    }

    /// `setAlternateIconName` に渡す名前（いつものアイコンは nil）
    var iconName: String? { self == .standard ? nil : "AppIcon-\(rawValue)" }

    /// 選ぶ画面に出す見本
    var previewAsset: String { "IconPreview-\(rawValue)" }

    init(iconName: String?) {
        self = AppIconOption.allCases.first { $0.iconName == iconName } ?? .standard
    }
}

struct AppIconPicker: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var proStore = ProStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var current = AppIconOption(iconName: UIApplication.shared.alternateIconName)
    @State private var showsPro = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("アプリのアイコン")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textOnCardBackground2(for: colorScheme))
                if !proStore.isPurchased {
                    Text("Pro")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange))
                }
            }
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(AppIconOption.allCases) { option in
                    Button {
                        choose(option)
                    } label: {
                        VStack(spacing: 6) {
                            Image(option.previewAsset)
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(themeManager.currentTheme.actionFill, lineWidth: current == option ? 3 : 0)
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    if !proStore.isPurchased && option != .standard {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Circle().fill(Color.black.opacity(0.55)))
                                            .offset(x: 4, y: 4)
                                    }
                                }
                            Text(option.name)
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryTextOnCardBackground2(for: colorScheme))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("アイコン：\(option.name)")
                    .accessibilityAddTraits(current == option ? .isSelected : [])
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.currentTheme.cardBackground2))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeManager.currentTheme.cardBorder, lineWidth: 1))
        .sheet(isPresented: $showsPro) {
            NavigationStack {
                ProView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { showsPro = false }
                        }
                    }
            }
        }
        .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil },
                                                        set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func choose(_ option: AppIconOption) {
        guard option != current else { return }
        // いつものアイコンへ戻すのは、Pro でなくてもできる（買う前に戻せなくならないように）
        guard proStore.isPurchased || option == .standard else {
            showsPro = true
            return
        }
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            Task { @MainActor in
                if error == nil {
                    current = option
                } else {
                    errorMessage = "アイコンを変えられませんでした。もう一度お試しください。"
                }
            }
        }
    }
}
