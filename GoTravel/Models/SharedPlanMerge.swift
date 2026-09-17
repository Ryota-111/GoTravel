import Foundation

/// 共有された旅行計画を、手元のものとどう突き合わせるかを決める。
///
/// **ここは外の世界に触らない。**
/// ネットワークも Core Data も時計も画面も使わず、入れた値だけで答えを返す。
/// そうしておくと、実機2台と iCloud アカウントを用意しなくても
/// 「同時に編集したら消えないか」「削除が復活しないか」をテストで確かめられる。
///
/// 通信と保存は呼び出し側（`TravelPlanViewModel.refreshSharedPlans`）の仕事。
/// この関数は**何をすべきかを返すだけ**で、自分では何もしない。
enum SharedPlanMerge {

    /// 突き合わせた結果、何をすべきか
    enum Decision {
        /// 相手のほうが新しい。手元へ取り込む（中身はマージ済み）
        case takeRemote(TravelPlan)
        /// 手元のほうが新しい。相手へ送る
        case pushLocal(TravelPlan)
        /// どちらも同じ。触らない
        case doNothing
    }

    /// - Parameters:
    ///   - local: 手元の計画。まだ持っていなければ nil
    ///   - remote: パブリックDBから降りてきた計画
    ///   - myUserId: この端末のユーザーID
    static func decide(local: TravelPlan?,
                       remote: TravelPlan,
                       myUserId: String) -> Decision {
        // まだ手元に無い共有計画は、そのまま取り込む
        guard let local else {
            return .takeRemote(adopt(remote, local: nil, myUserId: myUserId))
        }

        if remote.updatedAt > local.updatedAt {
            return .takeRemote(adopt(remote, local: local, myUserId: myUserId))
        }
        if local.updatedAt > remote.updatedAt {
            return .pushLocal(local)
        }
        // 更新時刻が同じ＝どちらも変わっていない。
        // ここで無理に送り合うと、往復し続けて落ち着かなくなる
        return .doNothing
    }

    /// 降りてきた計画を、この端末に置ける形へ整える
    private static func adopt(_ remote: TravelPlan,
                              local: TravelPlan?,
                              myUserId: String) -> TravelPlan {
        var adopted = remote

        // 手元の行は必ず端末ユーザーの userId で持つ。
        // `NSFetchedResultsController` の条件に合わなくなると、
        // 取り込んだのに一覧へ出てこない。本来の持ち主は ownerId が覚えている
        adopted.userId = myUserId

        // **自分だけの持ち物・お土産を、共有側の内容で消さない。**
        //
        // パブリックDBには持ち主のいない項目（やりたいこと）しか載っていない。
        // 降りてきたものでそのまま置き換えると、自分の持ち物が毎回消える。
        // 共有ぶんはリモートを正とし、自分のぶんは手元のものを残す
        let myItems = local?.packingItems.filter { $0.ownerId != nil } ?? []
        adopted.packingItems = remote.packingItems.filter { $0.ownerId == nil } + myItems

        return adopted
    }
}

// MARK: - テストから中身を取り出すための入口

extension SharedPlanMerge.Decision {
    var takenPlan: TravelPlan? {
        if case .takeRemote(let plan) = self { return plan }
        return nil
    }

    var pushedPlan: TravelPlan? {
        if case .pushLocal(let plan) = self { return plan }
        return nil
    }

    var isDoNothing: Bool {
        if case .doNothing = self { return true }
        return false
    }
}
