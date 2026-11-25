import SwiftUI

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

/// ＋のメニューを開いているあいだ、後ろを暗くする。押すと閉じる
struct FloatingAddMenuBackdrop: View {
    @Binding var isOpen: Bool

    var body: some View {
        if isOpen {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { isOpen = false }
                .transition(.opacity)
                .accessibilityHidden(true)
        }
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
