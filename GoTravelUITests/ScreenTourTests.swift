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
        // アプリ全体をひと通り押して回る（テスターとしての確認。3.8）。
        // qa ですべて、qa-plan・qa-profile などで区切りごとに
        let qaSections = Set(steps.filter { $0.hasPrefix("qa") }.map(String.init))
        if !qaSections.isEmpty {
            qaTour(extra: extra, sections: qaSections)
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

    // MARK: - ひと通りの確認（qa）

    /// 左上の戻る。無ければ左上を押す
    private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons.firstMatch
        if button.waitForExistence(timeout: 1.5), button.isHittable {
            button.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.08)).tap()
        }
        sleep(1)
    }

    /// シートを閉じる。キャンセル・閉じる・完了のどれかを押し、無ければ下に払う
    private func closeSheet(_ app: XCUIApplication) {
        for label in ["キャンセル", "閉じる", "完了"] {
            let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            if button.exists, button.isHittable { button.tap(); sleep(1); return }
        }
        app.swipeDown(velocity: .fast)
        sleep(1)
    }

    /// 名前の書いてあるボタン（ラベルが一致）を押す
    @discardableResult
    private func press(_ app: XCUIApplication, _ label: String) -> Bool {
        let element = app.buttons.matching(NSPredicate(format: "label == %@ OR identifier == %@", label, label)).firstMatch
        guard element.waitForExistence(timeout: 2), element.isHittable else { return tap(app, label) }
        element.tap()
        sleep(2)
        return true
    }

    private func qaTour(extra: [String], sections: Set<String>) {
        func wants(_ name: String) -> Bool { sections.contains("qa") || sections.contains("qa-\(name)") }
        // 計画のタブ
        if wants("plan") {
            let app = launch(tab: 0, extra: extra)
            shot("qa-01-plan")
            app.swipeUp(); sleep(1); shot("qa-02-plan-scrolled")
            app.swipeUp(); sleep(1); shot("qa-03-plan-scrolled2")
            app.swipeDown(); app.swipeDown(); sleep(1)
            if press(app, "タスクリスト") || tap(app, "タスクリスト") { shot("qa-04-tasks"); back(app) }
            if press(app, "旅行計画を追加") { shot("qa-05-add-trip"); closeSheet(app) }
            if press(app, "予定を追加") { shot("qa-06-add-plan"); closeSheet(app) }
        }
        // プロフィールと設定
        if wants("profile") {
            let app = launch(tab: 0, extra: extra)
            if press(app, "プロフィール") {
                shot("qa-10-profile")
                app.swipeUp(); sleep(1); shot("qa-11-profile-scrolled")
                app.swipeDown(); sleep(1)
                for (index, row) in ["アプリ設定", "ヘルプ・サポート", "データ", "最近削除", "Pro", "応援", "地図アプリ", "通知", "カレンダー", "時間帯"].enumerated() {
                    if tap(app, row) {
                        shot("qa-12-profile-\(index)")
                        back(app)
                    } else {
                        app.swipeUp(); sleep(1)
                        if tap(app, row) { shot("qa-12-profile-\(index)"); back(app) }
                        app.swipeDown(); sleep(1)
                    }
                }
            }
        }
        // 旅行の中（日程・地図・リスト・予約確認・費用）
        if wants("trip") {
            let app = launch(tab: 0, extra: extra)
            if tap(app, "沖縄 3泊4日") {
                shot("qa-20-trip")
                for (index, tab) in ["地図", "リスト", "予約確認", "費用"].enumerated() where tap(app, tab) {
                    sleep(3)
                    shot("qa-21-trip-\(index)")
                    app.swipeUp(); sleep(1)
                    shot("qa-21-trip-\(index)-scrolled")
                    app.swipeDown(); sleep(1)
                }
                if tap(app, "日程") {
                    if press(app, "追加") { shot("qa-22-add-item"); closeSheet(app) }
                    if tap(app, "Day 2") { shot("qa-23-day2") }
                }
                if tap(app, "予約確認") {
                    if press(app, "予約を追加") || press(app, "追加") { sleep(1); shot("qa-24-add-reservation"); closeSheet(app) }
                }
            }
        }
        // おでかけの予定
        if wants("outing") {
            let app = launch(tab: 0, extra: extra)
            app.swipeUp(); sleep(1)
            if tap(app, "鎌倉さんぽ") {
                shot("qa-30-plan-detail")
                app.swipeUp(); sleep(1); shot("qa-31-plan-detail-scrolled")
            }
        }
        // カレンダー
        if wants("calendar") {
            let app = launch(tab: 1, extra: extra)
            shot("qa-40-calendar")
            if press(app, "次の月") { shot("qa-41-calendar-next") }
            if press(app, "カレンダーの表示") { shot("qa-42-calendar-mode"); closeSheet(app) }
        }
        // 場所保存
        if wants("places") {
            let app = launch(tab: 2, extra: extra)
            shot("qa-50-places")
            if press(app, "行った") { shot("qa-51-places-visited"); press(app, "行きたい") }
            if press(app, "placesAddButton") || press(app, "場所を追加") { shot("qa-52-places-add"); app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap(); sleep(1) }
            if tap(app, "地図") { sleep(3); shot("qa-53-places-map"); tap(app, "リスト") }
            if tap(app, "伏見稲荷大社") { shot("qa-54-place-detail"); back(app) }
        }
        // 思い出
        if wants("memories") {
            let app = launch(tab: 3, extra: extra)
            shot("qa-60-memories")
            app.swipeUp(); sleep(1); shot("qa-61-memories-scrolled")
            app.swipeDown(); sleep(1)
            if press(app, "memoriesAddButton") { shot("qa-62-memories-add"); app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap(); sleep(1) }
            if tap(app, "旅の記録") { sleep(2); shot("qa-63-stats"); closeSheet(app); back(app) }
            if tap(app, "日本全国フォトマ") { sleep(2); shot("qa-64-photomap"); back(app) }
        }
    }
}
