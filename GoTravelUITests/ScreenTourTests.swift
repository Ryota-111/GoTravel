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
            if tap(app, "日本全国フォトマ") { shot("album-detail") }
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
