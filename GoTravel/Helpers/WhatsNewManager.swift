import Foundation

/// アップデート後に一度だけ「新機能のお知らせ」を出すための状態管理。
///
/// リリースノートを読むユーザーはごく一部なので、追加した機能や
/// 意見の送り先はアプリ内でも伝えないと気付かれない。
enum WhatsNewManager {
    private static let lastShownVersionKey = "lastShownWhatsNewVersion"

    /// 動作確認用。true の間は起動のたびにお知らせを出す。
    ///
    /// 本来の「1バージョンにつき1回」の挙動を確認したくなったら false に戻す。
    /// DEBUG ビルド限定なので、消し忘れてもTestFlightやApp Storeには影響しない。
    #if DEBUG
    static let alwaysShowForTesting = false
    #endif

    /// 現在のアプリバージョン（"2.4" など。ビルド番号は含めない）
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// お知らせを出すべきか。
    ///
    /// 新規インストールでは出さない。オンボーディング直後に
    /// 「新機能」と言われても、その人にとっては全部が新機能で意味がないため。
    static var shouldShow: Bool {
        guard WhatsNew.current != nil else { return false }

        #if DEBUG
        if alwaysShowForTesting { return true }
        #endif

        guard let lastShown = UserDefaults.standard.string(forKey: lastShownVersionKey) else {
            // ここに来るのは、この仕組みを入れる前から使っている人。
            // 新しく入れた人は、オンボーディングを終えた時点で
            // `markAsShown()` により記録が入るので、ここには来ない
            return OnboardingManager.shared.hasCompletedOnboarding
        }
        return lastShown != currentVersion
    }

    /// 表示済みとして記録する
    static func markAsShown() {
        UserDefaults.standard.set(currentVersion, forKey: lastShownVersionKey)
    }

    /// 動作確認用
    static func reset() {
        UserDefaults.standard.removeObject(forKey: lastShownVersionKey)
    }
}

// MARK: - お知らせの中身

/// バージョンごとのお知らせ。リリースのたびにここだけ書き換える
struct WhatsNew: Identifiable {
    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    let version: String
    let items: [Item]

    var id: String { version }

    /// 現在のバージョンのお知らせ。用意していないバージョンでは nil（＝表示しない）
    static var current: WhatsNew? {
        all.first { $0.version == WhatsNewManager.currentVersion }
    }

    private static let all: [WhatsNew] = [
        WhatsNew(
            version: "2.7",
            items: [
                Item(
                    icon: "globe.europe.africa.fill",
                    title: "海外旅行の時差に対応しました",
                    detail: "予定や予約の時刻を「現地時間」「日本時間」のどちらで入れるか選べるようになりました。現地時間で入れた予定は、日本にいても現地に着いても入れたとおりの時刻で表示されます。これまでは現地に着くと時差の分だけ時刻がずれていました。飛行機の予約では出発と到着をそれぞれの時間で入れられ、所要時間も時差込みで正しく出ます。ご要望をいただいて対応しました。"
                ),
                Item(
                    icon: "clock.arrow.2.circlepath",
                    title: "これまでの海外旅行も直せます",
                    detail: "以前に作った海外旅行で、現地の時刻のつもりで入れた予定がある場合は、旅行計画のタイムスケジュールの上に「現地時間にそろえる」が表示されます。押すと、時刻の数字はそのままで現地時間として扱います。"
                ),
                Item(
                    icon: "arrow.triangle.turn.up.right.diamond.fill",
                    title: "経路案内でGoogleマップを選べます",
                    detail: "「プロフィール」→「経路案内のアプリ」で、Appleマップ・Googleマップ・毎回選ぶ から選べます。すべての画面の経路案内がこの設定で開きます。Googleマップのアプリが入っていなくても、ブラウザで開きます。ご要望をいただいて追加しました。"
                ),
                Item(
                    icon: "person.2.badge.gearshape.fill",
                    title: "共有した計画の変更が届くようになりました",
                    detail: "共有した旅行計画に後から予定を足しても、相手には最初の内容のまま表示されることがありました。同行者が自分の持ち物にチェックを入れただけで、古い内容で上書きされてしまっていたためです。お互いの変更が消えずに届くように直しました。ご報告をいただいて修正しました。"
                ),
                Item(
                    icon: "arrow.triangle.2.circlepath",
                    title: "共有の内容が自動で最新になります",
                    detail: "アプリを開き直したときや、旅行計画を開いたときに、同行者の変更を自動で取り込みます。旅行計画の画面には最後に更新した時刻と更新ボタンがあり、いつでも最新の内容にできます。"
                )
            ]
        ),
        WhatsNew(
            version: "2.6",
            items: [
                Item(
                    icon: "tag.fill",
                    title: "タグで予定を仕分けられます",
                    detail: "「仕事」「遊び」など、自由に作ったタグで予定を分けられるようになりました。一覧をタグで絞り込めるので、探している予定にすぐたどり着けます。カレンダーに出る点も、タグの色になります。"
                ),
                Item(
                    icon: "bell.badge.fill",
                    title: "通知のタイミングを選べます",
                    detail: "「1週間前」「前日の夜」「1時間前」など、鳴らすタイミングを予定ごとに選べるようになりました。よく使う組み合わせは、種別ごとの初期設定として保存できます。これまでは入れるか消すかしかなく、選んだ内容も残りませんでした。"
                ),
                Item(
                    icon: "paintpalette.fill",
                    title: "テーマが14種類増えました",
                    detail: "色だけでなく、書体や角の形、カードの作りまで変わります。買い切りで、これから増えるぶんも含まれます。桜・瀬戸内・紅葉・雪国は、旬のあいだ購入なしでお使いいただけます。プロフィールの「Travory Pro」から、それぞれの見え方をご覧いただけます。"
                ),
                Item(
                    icon: "icloud.and.arrow.up.fill",
                    title: "写真をiCloudでお預かりします",
                    detail: "これまで写真は端末の中だけにあり、機種変更やアプリの入れ直しで消えてしまっていました。旅行のカバー写真・場所の写真・アルバムの写真を、お客様ご自身のiCloudにも保管します。Travory Proに含まれます。"
                ),
                Item(
                    icon: "list.bullet.clipboard.fill",
                    title: "お土産・やりたいことのリストが増えました",
                    detail: "旅行計画の「リスト」から、持ち物・お土産・やりたいことを切り替えられます。お土産には「誰に」を書いておけるので、お店で迷いません。ご要望をいただいて追加しました。"
                ),
                Item(
                    icon: "arrow.down.doc.fill",
                    title: "持ち物を前の旅行から持ってこられます",
                    detail: "「前の旅行から」を押すと、以前の旅行のリストをそのまま取り込めます。チェックは外した状態で入り、同じ名前のものは重ねません。「よく使う持ち物」の候補も、自分で追加・削除・並べ替えができるようになりました。ご要望をいただいて追加しました。"
                ),
                Item(
                    icon: "yensign.circle.fill",
                    title: "画像に実際に使った金額が出ます",
                    detail: "旅行の記録を画像で書き出すとき、実際に使った金額を記録していればそちらを表示します。まだ記録していない項目は予定の金額のままです。ご要望をいただいて追加しました。"
                ),
                Item(
                    icon: "magnifyingglass",
                    title: "保存した場所をそのまま検索できます",
                    detail: "場所の詳細から、その場所の名前でネット検索できるようになりました。営業時間や口コミを調べるのに、名前をコピーして貼り直す手間が要りません。"
                ),
                Item(
                    icon: "checklist",
                    title: "やることリストが引き継げます",
                    detail: "これまで端末の中だけに保存していたため、アプリを入れ直すと消えてしまっていました。他のデータと同じようにiCloudで同期され、機種を変えてもそのまま残ります。無料でお使いいただけます。"
                ),
                Item(
                    icon: "cloud.sun.fill",
                    title: "旅行中の天気が日ごとに出ます",
                    detail: "複数日の旅行で、1日目・2日目…とそれぞれの日の天気を並べるようにしました。旅行中なのに「10日前になると表示されます」と出てしまう問題も直しています。"
                ),
                Item(
                    icon: "mappin.and.ellipse",
                    title: "場所まわりを使いやすくしました",
                    detail: "訪問場所を先に登録しなくても、タイムスケジュールを追加するときにその場で場所を選べます。登録した場所が複数あるときは、経路案内の行き先を選べるようになりました。"
                ),
                Item(
                    icon: "list.bullet.rectangle",
                    title: "おでかけの画面を整理しました",
                    detail: "詳細・編集・タイムスケジュールの追加を、余白と区切り線で見やすくしました。タイムスケジュールには件数が出ます。"
                ),
                Item(
                    icon: "clock.fill",
                    title: "日常の予定に終わる時刻を入れられます",
                    detail: "始まりだけでなく、終わりの時刻も設定できるようになりました。"
                ),
                Item(
                    icon: "moon.fill",
                    title: "ダークモードを見やすくしました",
                    detail: "背景が真っ黒で境目が分かりにくかったため、少し明るい色に変えました。"
                ),
                Item(
                    icon: "ipad",
                    title: "iPadでの表示を修正",
                    detail: "画面の中身が左の細い列に詰め込まれてしまう問題を直しました。"
                )
            ]
        ),
        WhatsNew(
            version: "2.4",
            items: [
                Item(
                    icon: "checkmark.circle.fill",
                    title: "実際に使った金額を記録できます",
                    detail: "予定をタップして「実際に使った金額」を入力すると、予算との差額が分かります。予算サマリーでは旅行全体の予算と実績を比べられます。ご要望をいただいて追加しました。"
                ),
                Item(
                    icon: "mappin.and.ellipse",
                    title: "登録できる場所が大きく増えました",
                    detail: "検索が表示中の範囲に限られていたため、遠くの場所が見つからない状態でした。全国から探せるようにし、住所でも検索できるようにしました。地図を長押しすれば、検索に出てこない場所も登録できます。"
                ),
                Item(
                    icon: "person.2.fill",
                    title: "割り勘の人数を変えられます",
                    detail: "予算サマリーで人数を自由に増減できるようになりました。アプリを使っていない同行者がいる場合や、共有していない旅行でも割り勘を計算できます。"
                ),
                Item(
                    icon: "lightbulb.fill",
                    title: "ご意見・ご要望を送れるようになりました",
                    detail: "「ヘルプ・サポート」から、欲しい機能や気になった点をそのまま送れます。いただいた声には必ず目を通しています。"
                ),
                Item(
                    icon: "paintpalette.fill",
                    title: "アプリの色を変えられます",
                    detail: "ご存じでしたか？「プロフィール」→「アプリ設定」から、アプリ全体の配色を選べます。白黒やパステルピンクもご用意しています。"
                ),
                Item(
                    icon: "cloud.sun.fill",
                    title: "天気が日本語で表示されます",
                    detail: "「Mostly Cloudy」のような英語表記を、「くもり時々晴れ」のように日本語で表示するようにしました。"
                ),
                Item(
                    icon: "plus.circle.fill",
                    title: "追加しやすくしました",
                    detail: "「旅行計画」「予定計画」は見出しの横に、「場所保存」は画面の右下に追加ボタンを置きました。件数が増えても、下までスクロールせずに追加できます。"
                ),
                Item(
                    icon: "link.badge.plus",
                    title: "共有コードの不具合を修正",
                    detail: "共有コードを送っても相手が参加できないことがある問題を修正しました。コードは発行が完了してから表示されます。海外での時刻表示も修正しました。"
                ),
                Item(
                    icon: "lock.fill",
                    title: "ロック画面ウィジェットの切り替えを調整",
                    detail: "旅行中のタイムテーブルが、予定の時刻から5分後に次の予定へ切り替わるようになりました。"
                )
            ]
        )
    ]
}
