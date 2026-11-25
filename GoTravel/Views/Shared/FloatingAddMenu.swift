import SwiftUI
import Combine

/// 画面の右下の「＋」を押すと、選べるものが上に向かって順に開く小さなメニュー（3.8）。
/// 思い出・場所保存で使う。
///
/// 見た目は「旅の思い出をつくる」と同じ紙と墨。開くと＋が墨色の × に回り、項目が下から少しずつずれて出る。
/// 後ろを暗くするのは使う側で行う（画面全体にかぶせるため）
struct FloatingAddMenu: View {
    struct Entry: Identifiable {
        let id: String
        /// 小さく添える手書きの英字
        let english: String
        let title: String
        let icon: String
        /// 読み上げの名前（無ければ title）
        var spokenLabel: String? = nil
        let action: () -> Void
    }

    @Binding var isOpen: Bool
    /// 上から順に。最後のものが＋のすぐ上に来る
    let entries: [Entry]
    /// 閉じているときの＋の読み上げの名前
    var buttonLabel: String = "追加"
    var accessibilityHint: String = ""
    var identifier: String = "floatingAddButton"

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                // ＋に近いものから先に出す（閉じるときは遠いものから）
                let fromBottom = entries.count - 1 - index
                row(entry)
                    .opacity(isOpen ? 1 : 0)
                    .scaleEffect(isOpen ? 1 : 0.6, anchor: .trailing)
                    .offset(y: isOpen ? 0 : CGFloat(18 + fromBottom * 14))
                    .animation(.spring(response: 0.38, dampingFraction: 0.78)
                        .delay(isOpen ? Double(fromBottom) * 0.035 : Double(index) * 0.02), value: isOpen)
                    .allowsHitTesting(isOpen)
                    .accessibilityHidden(!isOpen)
            }
            plusButton
        }
    }

    private func row(_ entry: Entry) -> some View {
        Button {
            isOpen = false
            entry.action()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: -3) {
                    Text(entry.english)
                        .font(MemoryFont.hand(16))
                        .foregroundStyle(MemoryColor.softInk)
                    Text(entry.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MemoryColor.ink)
                }
                .padding(.leading, 16)
                .padding(.trailing, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(MemoryColor.paper))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)

                Image(systemName: entry.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(MemoryColor.ink)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(MemoryColor.paper))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    // ＋の真ん中にそろえる
                    .padding(.trailing, (FloatingAddButtonLabel.size - 46) / 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowPressStyle())
        .accessibilityLabel(entry.spokenLabel ?? entry.title)
    }

    private var plusButton: some View {
        let fill = isOpen ? MemoryColor.ink : themeManager.currentTheme.xprimary
        return Button {
            isOpen.toggle()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isOpen ? MemoryColor.paper : ThemePreset.readableText(on: fill))
                .rotationEffect(.degrees(isOpen ? 135 : 0))
                .frame(width: FloatingAddButtonLabel.size, height: FloatingAddButtonLabel.size)
                .background(Circle().fill(fill))
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isOpen)
        .sensoryFeedback(.impact(weight: .light), trigger: isOpen)
        .accessibilityLabel(isOpen ? "閉じる" : buttonLabel)
        .accessibilityIdentifier(identifier)
        .accessibilityHint(isOpen ? "" : accessibilityHint)
    }
}

/// ＋のメニューを開いているあいだ、後ろを暗くする。押すと閉じる。
///
/// 暗くするのはタブの中の、下のタブより上まで。下のタブはアプリ全体の画面（`MainTabView`）にあり、
/// タブの中からは暗くできないので、そこから下は `FloatingMenuDim` を見て `MainTabView` が暗くする（3.8）
struct FloatingAddMenuBackdrop: View {
    @Binding var isOpen: Bool

    var body: some View {
        GeometryReader { proxy in
            Group {
                if isOpen {
                    Color.black.opacity(FloatingMenuDim.opacity)
                        .ignoresSafeArea(edges: .top)
                        .onTapGesture { isOpen = false }
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .onAppear { FloatingMenuDim.shared.bottomInset = proxy.safeAreaInsets.bottom }
            .onChange(of: proxy.safeAreaInsets.bottom) { _, inset in FloatingMenuDim.shared.bottomInset = inset }
        }
        .allowsHitTesting(isOpen)
        .onChange(of: isOpen) { _, open in
            FloatingMenuDim.shared.isOpen = open
            FloatingMenuDim.shared.close = open ? { isOpen = false } : nil
        }
        .onDisappear {
            // 開いたままほかのタブへ移ったら閉じる
            if isOpen { isOpen = false }
            FloatingMenuDim.shared.isOpen = false
            FloatingMenuDim.shared.close = nil
        }
    }
}

/// ＋のメニューを開いているか（下のタブを暗くするため、アプリ全体の画面と分け合う。3.8）
final class FloatingMenuDim: ObservableObject {
    static let shared = FloatingMenuDim()
    static let opacity = 0.28

    @Published var isOpen = false
    /// タブの中の下の余白（下のタブの高さ）。画面の下の端からこの高さを暗くする
    @Published var bottomInset: CGFloat = 0
    /// 暗いところを押したときに閉じる
    var close: (() -> Void)?

    private init() {}
}

/// 下のタブのところを暗くする（`MainTabView` に重ねる）
struct FloatingMenuTabBarDim: View {
    @ObservedObject private var dim = FloatingMenuDim.shared

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if dim.isOpen {
                    Color.black.opacity(FloatingMenuDim.opacity)
                        .frame(height: dim.bottomInset)
                        .contentShape(Rectangle())
                        .onTapGesture { dim.close?() }
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(dim.isOpen)
        .animation(.easeInOut(duration: 0.2), value: dim.isOpen)
    }
}

/// 押しているあいだ少し縮める
private struct MenuRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1, anchor: .trailing)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
