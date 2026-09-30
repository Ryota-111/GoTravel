import Foundation

/// 共有した旅行の、メンバーの名前と「参加する人」の扱い。
///
/// 出発地の違うメンバーが現地で集まる旅行で、それぞれの移動を分けて見られるようにする
/// （`docs/設計_メンバーごとの時間軸.md`）。画面にも通信にも触らない
enum SharedMembers {

    /// 画面に出す名前。付いていなければ、自分は「自分」、他の人は「メンバー2」のように出す
    static func displayName(of userId: String,
                            names: [String: String],
                            members: [String],
                            myUserId: String?) -> String {
        if let name = names[userId]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if userId == myUserId { return "自分" }
        let index = (members.firstIndex(of: userId) ?? members.count) + 1
        return "メンバー\(index)"
    }

    /// 選んだ人を保存する形にする。**誰も選んでいない・全員を選んだなら nil（全員）。**
    /// 全員を並べて持つと、あとから参加した人がその予定から漏れるため
    static func normalizedParticipants(_ selected: Set<String>, members: [String]) -> [String]? {
        let chosen = members.filter(selected.contains)
        guard !chosen.isEmpty, chosen.count < members.count else { return nil }
        return chosen
    }

    /// その人の時間軸に出る予定か。全員の予定は、誰の時間軸にも出る
    static func includes(_ item: ScheduleItem, member: String?) -> Bool {
        guard let member, let participants = item.participantIds, !participants.isEmpty else { return true }
        return participants.contains(member)
    }

    /// 全員のものでない予定に添える名前（「さくら・父」）。全員の予定なら nil
    static func participantLabel(of item: ScheduleItem,
                                 names: [String: String],
                                 members: [String],
                                 myUserId: String?) -> String? {
        guard let participants = item.participantIds, !participants.isEmpty else { return nil }
        return participants
            .map { displayName(of: $0, names: names, members: members, myUserId: myUserId) }
            .joined(separator: "・")
    }
}
