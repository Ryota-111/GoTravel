import XCTest

/// 見本データで主な画面を開いて、画面の写真を残す（見た目を確かめるため）。
///
/// 写真の保存先は環境変数 `TOUR_DIR`（`TEST_RUNNER_TOUR_DIR=... xcodebuild test ...` で渡す）。
/// 渡されていなければ何もしないので、ふだんのテストでは動かない
final class ScreenTourTests: XCTestCase {

    private var directory: URL?
    /// お知らせを出さないために渡す、今の版（`TEST_RUNNER_TOUR_VERSION` で渡す）
    private static var appVersion: String { ProcessInfo.processInfo.environment["TOUR_VERSION"] ?? "3.5" }

    override func setUpWithError() throws {
        continueAfterFailure = true
        guard let path = ProcessInfo.processInfo.environment["TOUR_DIR"], !path.isEmpty else {
            throw XCTSkip("TOUR_DIR が無いので撮らない")
        }
        directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory!, withIntermediateDirectories: true)
    }

    private func launch(tab: Int, extra: [String] = [], onboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-TravoryEmptyDataMode", "-TravoryDemoData",
                               "-appleSignInUserId", "demo", "-hasCompletedOnboarding", onboarding ? "NO" : "YES",
                               // お知らせや案内は、画面を隠すので出さない
                               "-lastShownWhatsNewVersion", Self.appVersion, "-TabSwipePromptState", "done",
                               "-TravoryInitialTab", "\(tab)"] + extra
        app.launch()
        // 通知の許可などの確認が出ていたら閉じる
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["許可", "Allow", "アプリの使用中は許可", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 1.5) { button.tap() }
        }
        sleep(3)
        return app
    }

    private func shot(_ name: String) {
        guard let directory else { return }
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: directory.appendingPathComponent(name + ".png"))
    }

    /// 写真へのアクセスの確認が出ていたら、すべての写真を許可する（シミュレーターの許可の命令が効かない版があるため）
    private func allowPhotos(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            for root in [springboard, app] {
                for label in ["フルアクセスを許可", "Allow Full Access", "すべての写真へのアクセスを許可"] {
                    let button = root.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
                    if button.waitForExistence(timeout: 2) { button.tap(); sleep(2); return }
                }
            }
        }
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

    /// 文字で探して押す。見つからなければ何もしない
    @discardableResult
    private func tap(_ app: XCUIApplication, _ text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        for query in [app.buttons, app.staticTexts, app.otherElements] {
            let element = query.matching(predicate).firstMatch
            if element.waitForExistence(timeout: 2), element.isHittable {
                element.tap()
                sleep(2)
                return true
            }
        }
        return false
    }

    @MainActor
    func testTour() throws {
        let steps = (ProcessInfo.processInfo.environment["TOUR_STEPS"] ?? "tabs,travel,plan,place").split(separator: ",")
        let extra = (ProcessInfo.processInfo.environment["TOUR_ARGS"] ?? "").split(separator: " ").map(String.init)

        if steps.contains("onboarding") {
            // 最初の紹介画面を、最後のページまでめくる
            let app = launch(tab: 0, extra: extra, onboarding: true)
            shot("onboarding-1")
            for page in 2...4 where tap(app, "次へ") {
                shot("onboarding-\(page)")
            }
        }
        if steps.contains("tabs") {
            for tab in 0..<4 {
                let app = launch(tab: tab, extra: extra)
                shot("tab\(tab)")
                if tab == 0 {
                    app.swipeUp()
                    sleep(1)
                    shot("tab0-scrolled")
                }
            }
        }
        if steps.contains("travel") {
            let app = launch(tab: 0, extra: extra)
            if tap(app, "沖縄 3泊4日") {
                shot("travel-detail")
                app.swipeUp()
                sleep(1)
                shot("travel-detail-2")
                app.swipeUp()
                sleep(1)
                shot("travel-detail-3")
                // 左上の戻るボタンで戻れること（遷移を変えても、戻る操作が生きているか）。
                // 左端からなぞって戻る操作は、ここからは再現できないので実機で確かめる
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.098)).tap()
                sleep(2)
                shot("travel-back")
                // 戻ったあと、もう一度開けること
                if tap(app, "京都 紅葉めぐり") { shot("travel-reopen") }
            }
        }
        if steps.contains("album") {
            let app = launch(tab: 3, extra: extra)
            // アルバムの表紙（フォトマップの地図、写真1〜4枚の並び）が見えるところまで下げて撮る
            shot("album-home-top")
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)))
            sleep(1)
            shot("album-home")
            app.swipeDown()
            sleep(1)
            if tap(app, "日本全国フォトマ") { shot("album-detail") }
        }
        if steps.contains("memories") {
            // 旅の思い出をつくる（3.8）：写真コラージュ・ポスター・日記の編集画面
            for (index, kind) in ["写真コラージュ", "旅行ポスター", "旅行日記"].enumerated() {
                // 旅行の一覧は計画のタブで読み込まれるので、計画のタブで起動してから移る
                let app = launch(tab: 0, extra: extra)
                openTab(app, "思い出")
                sleep(2)
                if index == 0 { shot("memories-entry") }
                guard tap(app, kind) else { continue }
                if index == 0 { shot("memories-picker") }
                guard tap(app, "沖縄 3泊4日") else { continue }
                allowPhotos(app)
                sleep(8)
                shot("memories-\(index)")
            }
        }
        if steps.contains("addmenu") {
            // 思い出タブの右下の＋のメニュー（3.8）
            let app = launch(tab: 0, extra: extra)
            openTab(app, "思い出")
            sleep(2)
            shot("addmenu-closed")
            let plus = app.buttons.matching(NSPredicate(format: "label == '作る' OR identifier == 'memoriesAddButton'")).firstMatch
            if plus.waitForExistence(timeout: 3) {
                plus.tap()
                sleep(2)
                shot("addmenu-open")
                if tap(app, "写真コラージュを作る") {
                    sleep(2)
                    shot("addmenu-collage")
                }
            }
        }
        if steps.contains("free") {
            // 旅行計画なしで自由に作る（3.8）：思い出タブのダイジェストの列 → コラージュの「自由に作る」
            let app = launch(tab: 0, extra: extra)
            openTab(app, "思い出")
            sleep(2)
            // ダイジェストの列の最後（「自由に作る」のカード）まで送る
            let card = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '3泊4日のダイジェスト'")).firstMatch
            if card.waitForExistence(timeout: 3) {
                let window = app.windows.firstMatch
                let y = card.frame.midY / window.frame.height
                for _ in 0..<3 {
                    window.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: y))
                        .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: y)))
                }
                sleep(1)
            }
            shot("free-digest-row")
            if tap(app, "写真コラージュ") {
                sleep(1)
                shot("free-entry")
            }
            if tap(app, "自由に作る") {
                allowPhotos(app)
                sleep(2)
                shot("free-setup")
                // 写真を自分で選ぶ（選択の画面は別のアプリなので、出せたら写真を数枚押してみる）
                app.swipeUp()
                sleep(1)
                if tap(app, "使いたい写真") {
                    shot("free-pick-empty")
                    if tap(app, "100枚まで") {
                        sleep(3)
                        shot("free-picker-sheet")
                        // 選択の画面は別のアプリで中を探せないので、写真のマスの位置を押して、右上の印で決める
                        let window = app.windows.firstMatch
                        for (x, y) in [(0.5, 0.43), (0.83, 0.43), (0.5, 0.74), (0.83, 0.74), (0.5, 0.58)] {
                            window.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
                            usleep(400_000)
                        }
                        sleep(1)
                        let done = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons.matching(NSPredicate(format: "label IN %@", ["追加", "完了", "Add", "Done"])).firstMatch
                        if done.exists {
                            done.tap()
                        } else {
                            window.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.155)).press(forDuration: 0.15)
                        }
                        sleep(3)
                        sleep(3)
                        shot("free-pick-grid")
                    }
                    tap(app, "期間で選ぶ")
                }
                if tap(app, "写真コラージュを作る") {
                    allowPhotos(app)
                    sleep(8)
                    shot("free-editor")
                    // 戻ると、旅行の一覧の下に「自由に作ったもの」として残っている
                    app.navigationBars.buttons.firstMatch.tap()
                    sleep(2)
                    app.swipeUp()
                    sleep(1)
                    shot("free-picker")
                }
            }
        }
        if steps.contains("map") {
            // 旅行計画の地図タブ（地図と行程表）。地図の絵が読み込まれるまで待つ
            let app = launch(tab: 0, extra: extra)
            if tap(app, "沖縄 3泊4日"), tap(app, "地図") {
                sleep(8)
                shot("travel-map")
                if tap(app, "Day 2") || tap(app, "2日目") {
                    sleep(8)
                    shot("travel-map-day2")
                }
            }
        }
        if steps.contains("packing") {
            let app = launch(tab: 0, extra: extra)
            if tap(app, "沖縄 3泊4日"), tap(app, "リスト") {
                shot("packing")
                if tap(app, "充電器") { shot("packing-checked") }
            }
            if tap(app, "費用") { shot("budget") }
        }
        if steps.contains("plan") {
            let app = launch(tab: 0, extra: extra)
            app.swipeUp()
            if tap(app, "鎌倉さんぽ") { shot("plan-detail") }
        }
        if steps.contains("place") {
            let app = launch(tab: 2, extra: extra)
            if tap(app, "伏見稲荷大社") {
                shot("place-detail")
                app.swipeUp()
                sleep(1)
                shot("place-detail-2")
            }
        }
    }
}
