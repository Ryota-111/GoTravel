import SwiftUI

/// 予定に「参加する人」を選ぶ。共有していて2人以上のときだけ出す。
///
/// **何も選んでいなければ全員。** 「全員」を押すと選択を外す。
///
/// 選んでいる間は、押したとおりに残す。全員を選んだものを「全員」として保存するのは
/// 保存のとき（`SharedMembers.normalizedParticipants`）だけ。
/// 以前は全員に達した瞬間に選択を空に戻していて、2人の旅行で「自分」→ 相手 と押すと
/// 押したものが消えて「全員」に戻ったように見えていた
struct ParticipantPicker: View {
    let plan: TravelPlan
    @Binding var selected: Set<String>
    let tint: Color
    let textColor: Color
    let secondaryText: Color
    let fieldBackground: Color

    @EnvironmentObject private var viewModel: TravelPlanViewModel
    @EnvironmentObject private var authVM: AuthViewModel

    private var members: [String] { plan.sharedWith }

    /// 誰も選んでいないか、全員を選んでいる。どちらも全員の予定として保存される
    private var isEveryone: Bool {
        selected.isEmpty || members.allSatisfy(selected.contains)
    }

    var body: some View {
        if plan.isShared && members.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(tint)
                    Text("参加する人")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(textColor)
                }

                FlowChips(spacing: 8) {
                    chip("全員", isSelected: selected.isEmpty) { selected = [] }
                    ForEach(members, id: \.self) { member in
                        chip(name(of: member), isSelected: selected.contains(member)) { toggle(member) }
                    }
                }

                Text(isEveryone
                     ? "全員の時間軸に出ます"
                     : "選んだ人の時間軸と、「全員」の見方にだけ出ます")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            .padding(14)
            .background(fieldBackground)
            .cornerRadius(12)
        }
    }

    private func name(of member: String) -> String {
        let name = SharedMembers.displayName(of: member,
                                             names: viewModel.memberNames(for: plan.id),
                                             members: members,
                                             myUserId: authVM.userId)
        return member == authVM.userId && name != "自分" ? "\(name)（自分）" : name
    }

    private func toggle(_ member: String) {
        if selected.contains(member) {
            selected.remove(member)
        } else {
            selected.insert(member)
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? tint : tint.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 幅なりに折り返して並べる
private struct FlowChips: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
