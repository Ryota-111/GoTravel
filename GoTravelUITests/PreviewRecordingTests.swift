import XCTest

/// App Store の動画（アプリのプレビュー）を撮るための操作（3.8）。
///
/// 録画そのものはシミュレーターの `simctl io recordVideo` で外から撮る。テストは操作だけをし、
/// 見せたい操作の始まりと終わりの時刻を `TOUR_DIR/<名前>.start` `.end` に書く（録画を切り出すため）。
/// `TOUR_DIR` が無ければ何もしないので、ふだんのテストでは動かない。
/// 見本の写真は `TOUR_ARGS`（`-TravoryDemoPhotosDir <フォルダ>` など）で渡す
final class PreviewRecordingTests: XCTestCase {

    private var directory: URL?

    override func setUpWithError() throws {
        continueAfterFailure = true
        guard let path = ProcessInfo.processInfo.environment["TOUR_DIR"], !path.isEmpty else {
            throw XCTSkip("TOUR_DIR が無いので撮らない")
        }
        directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory!, withIntermediateDirectories: true)
    }

    private func launch() -> XCUIApplication {
        let extra = (ProcessInfo.processInfo.environment["TOUR_ARGS"] ?? "").split(separator: " ").map(String.init)
        let app = XCUIApplication()
        app.launchArguments = ["-TravoryEmptyDataMode", "-TravoryDemoData", "-appleSignInUserId", "demo",
                               "-hasCompletedOnboarding", "YES", "-lastShownWhatsNewVersion", "3.8",
                               "-TabSwipePromptState", "done", "-TravoryInitialTab", "0",
                               "-calendarShareTipDismissed", "YES", "-TravoryProPreview", "YES",
                               // 撮っている途中に App Store の評価のお願いが出ないように（最後に頼んだのが先の日付）
                               "-ReviewLastRequestedAt", "<date>2099-01-01T00:00:00Z</date>"] + extra
        app.launch()
        // まれに起動がうまくいかず、ホーム画面に戻ることがある。下のタブが出なければ起動し直す
        if !app.tabBars.firstMatch.waitForExistence(timeout: 8) {
            app.launch()
            _ = app.tabBars.firstMatch.waitForExistence(timeout: 10)
        }
        sleep(2)
        return app
    }

    private func mark(_ name: String, _ suffix: String) {
        guard let directory else { return }
        let text = String(format: "%.3f", Date().timeIntervalSince1970)
        try? text.write(to: directory.appendingPathComponent("\(name).\(suffix)"), atomically: true, encoding: .utf8)
    }

    /// 下（iPad では上・Duo では横）のタブを押す
    private func openTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 2) {
            tab.tap()
        } else {
            // iPad は上、Duo は横にタブがある（アイコンだけのこともある）。ボタン以外も含めて名前で探す
            let any = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR identifier == %@", name, name)).firstMatch
            if any.waitForExistence(timeout: 2) { any.tap() }
        }
        sleep(2)
    }

    /// 文字で探して押す（横に並んだものは、見えるまで送る）
    @discardableResult
    private func tap(_ app: XCUIApplication, _ text: String, wait: UInt32 = 1, swipeIn: XCUIElement? = nil) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        for attempt in 0..<5 {
            for query in [app.buttons, app.staticTexts] {
                let element = query.matching(predicate).firstMatch
                // 画面の中に見えているときだけ押す（横に送った先の見本は、押せるかの判定で止まることがあるため）
                if element.waitForExistence(timeout: attempt == 0 ? 2 : 0.5),
                   app.windows.firstMatch.frame.insetBy(dx: 4, dy: 4).contains(element.frame) {
                    element.tap()
                    sleep(wait)
                    return true
                }
            }
            guard let swipeIn else { break }
            swipeIn.swipeLeft()
        }
        return false
    }

    private func allowPhotos(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for root in [springboard, app] {
            for label in ["フルアクセスを許可", "Allow Full Access"] {
                let button = root.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
                if button.waitForExistence(timeout: 2) { button.tap(); sleep(2); return }
            }
        }
    }

    /// 思い出タブから、旅の思い出（写真コラージュ・旅行ポスター・旅行日記）を沖縄の旅行で開く
    private func openMemory(_ app: XCUIApplication, kind: String) {
        openTab(app, "思い出")
        sleep(2)
        tap(app, kind, wait: 2)
        tap(app, "沖縄 3泊4日", wait: 1)
        allowPhotos(app)
        _ = app.buttons["書き出す"].waitForExistence(timeout: 30)
        sleep(3)
    }

    /// 下のテンプレートの見本を順に押す。見えていなければ、見本の帯（画面の下）を左へ送ってから探す
    private func pickTemplates(_ app: XCUIApplication, _ names: [String]) {
        let window = app.windows.firstMatch
        for name in names {
            for _ in 0..<4 {
                let element = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
                if element.exists, window.frame.insetBy(dx: 4, dy: 4).contains(element.frame) {
                    element.tap()
                    sleep(2)
                    break
                }
                // 帯の高さを、選んでいる見本の位置から決める（無ければ画面の下のほう）
                let y = element.exists ? element.frame.midY / window.frame.height : 0.9
                window.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: y))
                    .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: y)))
                sleep(1)
            }
        }
    }

    // MARK: - 旅のダイジェスト

    @MainActor
    func testDigest() {
        let app = launch()
        mark("digest", "start")
        openTab(app, "思い出")
        sleep(2)
        // 旅のダイジェストの「沖縄 3泊4日」のカード
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS '沖縄 3泊4日'")).firstMatch
        if card.waitForExistence(timeout: 5) { card.tap() } else { tap(app, "沖縄 3泊4日") }
        allowPhotos(app)
        sleep(4)
        // 旅行全体と日ごとのカードをめくって見せる
        let window = app.windows.firstMatch
        window.swipeLeft(); sleep(1)
        window.swipeLeft(); sleep(1)
        window.swipeRight(); sleep(1)
        window.swipeRight(); sleep(2)
        // 真ん中のカードを押して、使う写真を確かめる
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.38)).tap()
        sleep(3)
        app.swipeUp(); sleep(1)
        app.swipeDown(); sleep(1)
        tap(app, "作る", wait: 1)
        // 作り終わるのを待って、できた動画を見せる
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline, app.activityIndicators.count > 0 || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '作って'")).count > 0 {
            sleep(1)
        }
        sleep(12)
        mark("digest", "end")
    }

    // MARK: - アプリ全体の紹介（3.9）

    /// 計画 → 日程 → 地図 → 予約 → リスト → 費用 → 場所保存 → フォトマップ を続けて撮る。
    /// 場面ごとに `ov_<場面>.start` `.end` を書くので、編集でそこだけ切り出す
    @MainActor
    func testOverview() {
        let app = launch()
        let window = app.windows.firstMatch

        mark("ov_plans", "start")
        sleep(2)
        let trip = app.buttons.matching(NSPredicate(format: "label CONTAINS '沖縄 3泊4日'")).firstMatch
        if trip.waitForExistence(timeout: 5) {
            trip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            tap(app, "沖縄 3泊4日")
        }
        sleep(3)
        mark("ov_plans", "end")

        mark("ov_schedule", "start")
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        sleep(2)
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        sleep(2)
        mark("ov_schedule", "end")

        for (name, tab) in [("map", "地図"), ("reservation", "予約確認"), ("list", "リスト"), ("budget", "費用")] {
            tap(app, tab, wait: 0)
            mark("ov_\(name)", "start")
            sleep(name == "map" ? 4 : 3)
            if name == "budget" {
                window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                    .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
                sleep(2)
            }
            mark("ov_\(name)", "end")
        }

        // 計画の一覧へ戻って、場所保存とフォトマップ
        let back = app.buttons.matching(NSPredicate(format: "label == '戻る' OR label == 'Back'")).firstMatch
        if back.waitForExistence(timeout: 2) { back.tap() } else { window.swipeRight() }
        sleep(2)
        openTab(app, "場所保存")
        mark("ov_places", "start")
        sleep(3)
        mark("ov_places", "end")

        openTab(app, "思い出")
        tap(app, "日本全国フォトマップ", wait: 0)
        // 開ききってから撮る（「全画面で見る」が出たら開いている）
        _ = app.buttons.matching(NSPredicate(format: "label CONTAINS '全画面'")).firstMatch.waitForExistence(timeout: 10)
        sleep(1)
        mark("ov_photomap", "start")
        sleep(5)
        mark("ov_photomap", "end")
        // テストが終わるとアプリが閉じるので、少し待ってから終える
        sleep(3)
    }

    // MARK: - 写真コラージュ

    @MainActor
    func testCollage() {
        let app = launch()
        mark("collage", "start")
        openMemory(app, kind: "写真コラージュ")
        pickTemplates(app, ["フィルム", "グリッド", "チケット", "フォトブース", "ジャーナル"])
        tap(app, "おまかせ", wait: 2)
        tap(app, "書き出す", wait: 1)
        tap(app, "写真に保存", wait: 5)
        mark("collage", "end")
    }

    // MARK: - 旅行ポスター

    @MainActor
    func testPoster() {
        let app = launch()
        mark("poster", "start")
        openMemory(app, kind: "旅行ポスター")
        pickTemplates(app, ["ポストカード", "スプリット", "デュオトーン", "文字の切り抜き", "ヴィンテージ", "マガジン表紙"])
        tap(app, "書き出す", wait: 1)
        tap(app, "写真に保存", wait: 5)
        mark("poster", "end")
    }

    // MARK: - 旅行日記

    @MainActor
    func testDiary() {
        let app = launch()
        mark("diary", "start")
        openMemory(app, kind: "旅行日記")
        // その日のひとことを、ページの上でそのまま書く
        let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        if field.waitForExistence(timeout: 5) {
            field.tap()
            sleep(1)
            app.typeText("はじめての沖縄、最高のスタート！")
            sleep(1)
            tap(app, "完了", wait: 2)
        }
        tap(app, "スタイル", wait: 1)
        tap(app, "ジャーナル", wait: 3)
        tap(app, "書き出す", wait: 1)
        tap(app, "全ページを写真に保存", wait: 6)
        mark("diary", "end")
    }
}
