import SwiftUI
import CloudKit

struct CloudKitTestView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var accountStatus: String = "確認中..."
    @State private var isCheckingStatus = false
    @State private var testResult: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isUpdating = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("iCloud接続状態")) {
                    HStack {
                        Text("ステータス")
                        Spacer()
                        if isCheckingStatus {
                            ProgressView()
                        } else {
                            Text(accountStatus)
                                .foregroundColor(accountStatusColor)
                        }
                    }

                    Button(action: checkAccountStatus) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("ステータスを確認")
                        }
                    }
                    .disabled(isCheckingStatus)
                }

                Section(header: Text("接続テスト")) {
                    Button(action: testConnection) {
                        HStack {
                            Image(systemName: "network")
                            Text("接続テスト実行")
                        }
                    }
                    .disabled(isCheckingStatus)

                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("テストデータ")) {
                    Button(action: createTestRecord) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("テストレコード作成")
                        }
                    }
                    .disabled(isCheckingStatus)

                    Button(action: fetchTestRecords) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("テストレコード取得")
                        }
                    }
                    .disabled(isCheckingStatus)
                }

                Section(header: Text("VisitedPlace テスト")) {
                    Button(action: createTestVisitedPlace) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                            Text("VisitedPlace作成")
                        }
                    }
                    .disabled(isCheckingStatus)

                    Button(action: fetchTestVisitedPlaces) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("VisitedPlace取得")
                        }
                    }
                    .disabled(isCheckingStatus)
                }

                Section(header: Text("Plan テスト")) {
                    Button(action: createTestPlan) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Plan作成")
                        }
                    }
                    .disabled(isCheckingStatus)

                    Button(action: fetchTestPlans) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Plan取得")
                        }
                    }
                    .disabled(isCheckingStatus)
                }

                Section(header: Text("TravelPlan テスト")) {
                    Button(action: fetchTestTravelPlans) {
                        HStack {
                            Image(systemName: "airplane.departure")
                            Text("TravelPlan取得（全件）")
                        }
                    }
                    .disabled(isCheckingStatus)

                    Button(action: checkTravelPlanUserIds) {
                        HStack {
                            Image(systemName: "person.text.rectangle")
                            Text("TravelPlanのuserIdを確認")
                        }
                    }
                    .disabled(isCheckingStatus)
                }

                Section(header: Text("データ修正")) {
                    Button(action: checkAllDataUserIds) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("全データのuserIdを確認")
                        }
                    }
                    .disabled(isUpdating || isCheckingStatus)

                    Button(action: updateAllDataToCurrentUser) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("全データを現在のユーザーに更新")
                        }
                    }
                    .disabled(isUpdating || isCheckingStatus || authVM.userId == nil)

                    if isUpdating {
                        HStack {
                            ProgressView()
                            Text("更新中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("情報")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Container ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("iCloud.com.gmail.taismryotasis.Travory")
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("現在のUser ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(authVM.userId ?? "未ログイン")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(authVM.userId != nil ? .green : .red)
                    }
                }
            }
            .navigationTitle("CloudKit テスト")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("結果", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .task {
            initialCheck()
        }
    }

    private var accountStatusColor: Color {
        switch accountStatus {
        case "利用可能":
            return .green
        case "確認中...":
            return .secondary
        default:
            return .red
        }
    }

    private func initialCheck() {
        checkAccountStatus()
    }

    private func checkAccountStatus() {
        isCheckingStatus = true
        testResult = ""

        Task {
            do {
                let status = try await CloudKitService.shared.checkAccountStatus()
                await MainActor.run {
                    switch status {
                    case .available:
                        accountStatus = "利用可能"
                    case .noAccount:
                        accountStatus = "アカウントなし"
                    case .restricted:
                        accountStatus = "制限あり"
                    case .couldNotDetermine:
                        accountStatus = "確認できません"
                    case .temporarilyUnavailable:
                        accountStatus = "一時的に利用不可"
                    @unknown default:
                        accountStatus = "不明"
                    }
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    accountStatus = "エラー: \(error.localizedDescription)"
                    isCheckingStatus = false
                }
            }
        }
    }

    private func testConnection() {
        isCheckingStatus = true
        testResult = ""

        Task {
            let isAvailable = await CloudKitService.shared.isICloudAvailable()
            await MainActor.run {
                if isAvailable {
                    testResult = "✅ CloudKitに正常に接続できました"
                    alertMessage = "CloudKitへの接続に成功しました！"
                } else {
                    testResult = "❌ CloudKitに接続できません"
                    alertMessage = "iCloudにサインインしてください。\n設定 > iCloud"
                }
                showAlert = true
                isCheckingStatus = false
            }
        }
    }

    private func createTestRecord() {
        isCheckingStatus = true

        Task {
            do {
                let recordID = CKRecord.ID(recordName: "testRecord_\(UUID().uuidString)")
                let record = CKRecord(recordType: "TestRecord", recordID: recordID)
                record["title"] = "テストレコード"
                record["createdAt"] = Date()

                _ = try await CloudKitService.shared.save(record)

                await MainActor.run {
                    alertMessage = "テストレコードを作成しました！\nRecord: \(recordID.recordName)"
                    showAlert = true
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "エラー: \(error.localizedDescription)"
                    showAlert = true
                    isCheckingStatus = false
                }
            }
        }
    }

    private func fetchTestRecords() {
        isCheckingStatus = true

        Task {
            do {
                let records = try await CloudKitService.shared.fetchAllRecords(
                    recordType: "TestRecord"
                )

                await MainActor.run {
                    if records.isEmpty {
                        alertMessage = "テストレコードが見つかりませんでした"
                    } else {
                        alertMessage = "\(records.count)件のテストレコードを取得しました"
                    }
                    showAlert = true
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "エラー: \(error.localizedDescription)"
                    showAlert = true
                    isCheckingStatus = false
                }
            }
        }
    }

    private func createTestVisitedPlace() {
        isCheckingStatus = true

        Task {
            do {
                // テスト用の画像を生成（青いグラデーション）
                let testImage = createTestImage(color: .blue)

                // テスト用のVisitedPlaceを作成
                let testPlace = VisitedPlace(
                    title: "テスト訪問地 - \(Date().formatted(.dateTime.hour().minute()))",
                    notes: "CloudKitテストで作成された場所（画像付き）",
                    latitude: 35.6812,
                    longitude: 139.7671,
                    createdAt: Date(),
                    visitedAt: Date(),
                    address: "東京都千代田区",
                    tags: ["test", "cloudkit", "with-image"],
                    category: .sightseeing
                )

                let savedPlace = try await CloudKitService.shared.saveVisitedPlace(
                    testPlace,
                    userId: "test_user_\(UUID().uuidString.prefix(8))",
                    image: testImage
                )

                await MainActor.run {
                    alertMessage = "VisitedPlace（画像付き）を作成しました！\nID: \(savedPlace.id ?? "unknown")\nTitle: \(savedPlace.title)"
                    showAlert = true
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "エラー: \(error.localizedDescription)"
                    showAlert = true
                    isCheckingStatus = false
                }
            }
        }
    }

    // テスト用の画像を生成
    private func createTestImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // グラデーション背景
            let colors = [color.withAlphaComponent(0.8).cgColor, color.withAlphaComponent(0.3).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray,
                                     locations: [0.0, 1.0])!
            context.cgContext.drawLinearGradient(gradient,
                                                 start: .zero,
                                                 end: CGPoint(x: size.width, y: size.height),
                                                 options: [])

            // テキスト
            let text = "CloudKit Test"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(x: (size.width - textSize.width) / 2,
                                y: (size.height - textSize.height) / 2,
                                width: textSize.width,
                                height: textSize.height)
            text.draw(in: textRect, withAttributes: attributes)
        }
    }

    private func fetchTestVisitedPlaces() {
        isCheckingStatus = true

        Task {
            do {
                // 全てのVisitedPlaceを取得（テスト用）
                let records = try await CloudKitService.shared.fetchAllRecords(recordType: "VisitedPlace")

                // 画像の有無をチェック
                var withImageCount = 0
                for record in records {
                    if record["image"] as? CKAsset != nil {
                        withImageCount += 1
                    }
                }

                await MainActor.run {
                    if records.isEmpty {
                        alertMessage = "VisitedPlaceが見つかりませんでした"
                    } else {
                        alertMessage = "\(records.count)件のVisitedPlaceを取得しました\n画像付き: \(withImageCount)件"
                    }
                    showAlert = true
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "エラー: \(error.localizedDescription)"
                    showAlert = true
                    isCheckingStatus = false
                }
            }
        }
    }

    private func createTestPlan() {
        isCheckingStatus = true

        Task {
            do {
                // テスト用のPlanを作成
                let testPlaces = [
                    PlannedPlace(
                        name: "テスト場所1",
                        latitude: 35.6812,
                        longitude: 139.7671,
                        address: "東京都千代田区"
                    ),
                    PlannedPlace(
                        name: "テスト場所2",
                        latitude: 35.6895,
                        longitude: 139.6917,
                        address: "東京都新宿区"
                    )
                ]

                let testScheduleItems = [
                    PlanScheduleItem(
                        time: Date(),
                        title: "スケジュール1",
                        note: "テストスケジュール"
                    )
                ]

                let testPlan = Plan(
                    title: "テストプラン - \(Date().formatted(.dateTime.hour().minute()))",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(86400), // +1 day
                    places: testPlaces,
                    cardColor: .blue,
                    userId: "test_user_\(UUID().uuidString.prefix(8))",
                    planType: .outing,
                    description: "CloudKitテストで作成されたプラン",
                    scheduleItems: testScheduleItems
                )

                let savedPlan = try await CloudKitService.shared.savePlan(
                    testPlan,
                    userId: testPlan.userId ?? "unknown"
                )

                await MainActor.run {
                    alertMessage = "Planを作成しました！\nID: \(savedPlan.id)\nTitle: \(savedPlan.title)\nPlaces: \(savedPlan.places.count)件"
                    showAlert = true
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "エラー: \(error.localizedDescription)"
                    showAlert = true
                    isCheckingStatus = false
                }
            }
        }
    }

    private func fetchTestPlans() {
        isCheckingStatus = true

        Task {
            do {
                // 全てのPlanを取得（テスト用）
                let records = try await CloudKitService.shared.fetchAllRecords(recordType: "Plan")

                await MainActor.run {
                    if records.isEmpty {
                        alertMessage = "Planが見つかりませんでした"
                    } else {
                        alertMessage = "\(records.count)件のPlanを取得しました"
                    }
                    showAlert = true
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "エラー: \(error.localizedDescription)"
                    showAlert = true
                    isCheckingStatus = false
                }
            }
        }
    }

    // MARK: - Data Fix Methods
    private func checkAllDataUserIds() {
        isCheckingStatus = true

        Task {
            do {
                // VisitedPlaceを確認
                let visitedPlaceRecords = try await CloudKitService.shared.fetchAllRecords(recordType: "VisitedPlace")
                var visitedPlaceUserIds: [String: Int] = [:]
                for record in visitedPlaceRecords {
                    if let userId = record["userId"] as? String {
                        visitedPlaceUserIds[userId, default: 0] += 1
                    } else {
                        visitedPlaceUserIds["(nil)", default: 0] += 1
                    }
                }

                // Planを確認
                let planRecords = try await CloudKitService.shared.fetchAllRecords(recordType: "Plan")
                var planUserIds: [String: Int] = [:]
                for record in planRecords {
                    if let userId = record["userId"] as? String {
                        planUserIds[userId, default: 0] += 1
                    } else {
                        planUserIds["(nil)", default: 0] += 1
                    }
                }

                // TravelPlanを確認
                let travelPlanRecords = try await CloudKitService.shared.fetchAllRecords(recordType: "TravelPlan")
                var travelPlanUserIds: [String: Int] = [:]
                for record in travelPlanRecords {
                    if let userId = record["userId"] as? String {
                        travelPlanUserIds[userId, default: 0] += 1
                    } else {
                        travelPlanUserIds["(nil)", default: 0] += 1
                    }
                }

                await MainActor.run {
                    var message = "【VisitedPlace】\n"
                    for (userId, count) in visitedPlaceUserIds.sorted(by: { $0.key < $1.key }) {
                        message += "\(userId): \(count)件\n"
                    }

                    message += "\n【Plan】\n"
                    for (userId, count) in planUserIds.sorted(by: { $0.key < $1.key }) {
                        message += "\(userId): \(count)件\n"
                    }

                    message += "\n【TravelPlan】\n"
                    for (userId, count) in travelPlanUserIds.sorted(by: { $0.key < $1.key }) {
                        message += "\(userId): \(count)件\n"
                    }

                    message += "\n【現在のUser ID】\n\(authVM.userId ?? "未ログイン")"

                    alertMessage = message
                    showAlert = true
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "エラー: \(error.localizedDescription)"
                    showAlert = true
                    isCheckingStatus = false
                }
            }
        }
    }

    private func updateAllDataToCurrentUser() {
        guard let currentUserId = authVM.userId else {
            alertMessage = "ユーザーIDが取得できません"
            showAlert = true
            return
        }

        isUpdating = true

        Task {
            do {
                var updatedCount = 0

                // VisitedPlaceを更新
                let visitedPlaceRecords = try await CloudKitService.shared.fetchAllRecords(recordType: "VisitedPlace")
                for record in visitedPlaceRecords {
                    let existingUserId = record["userId"] as? String
                    if existingUserId != currentUserId {
                        record["userId"] = currentUserId
                        _ = try await CloudKitService.shared.save(record)
                        updatedCount += 1
                        print("✅ Updated VisitedPlace: \(record.recordID.recordName)")
                    }
                }

                // Planを更新
                let planRecords = try await CloudKitService.shared.fetchAllRecords(recordType: "Plan")
                for record in planRecords {
                    let existingUserId = record["userId"] as? String
                    if existingUserId != currentUserId {
                        record["userId"] = currentUserId
                        _ = try await CloudKitService.shared.save(record)
                        updatedCount += 1
                        print("✅ Updated Plan: \(record.recordID.recordName)")
                    }
                }

                // TravelPlanを更新
                let travelPlanRecords = try await CloudKitService.shared.fetchAllRecords(recordType: "TravelPlan")
                for record in travelPlanRecords {
                    let existingUserId = record["userId"] as? String
                    if existingUserId != currentUserId {
                        record["userId"] = currentUserId
                        _ = try await CloudKitService.shared.save(record)
                        updatedCount += 1
                        print("✅ Updated TravelPlan: \(record.recordID.recordName)")
                    }
                }

                await MainActor.run {
                    alertMessage = "✅ \(updatedCount)件のデータを更新しました！\n\n新しいUser ID:\n\(currentUserId)"
                    showAlert = true
                    isUpdating = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "エラー: \(error.localizedDescription)"
                    showAlert = true
                    isUpdating = false
                }
            }
        }
    }

    // MARK: - TravelPlan Debug Methods
    private func fetchTestTravelPlans() {
        isCheckingStatus = true

        Task {
            do {
                // 全てのTravelPlanを取得（userIdフィルタなし）
                let records = try await CloudKitService.shared.fetchAllRecords(recordType: "TravelPlan")

                await MainActor.run {
                    if records.isEmpty {
                        alertMessage = "TravelPlanが見つかりませんでした"
                    } else {
                        var message = "\(records.count)件のTravelPlanを取得しました\n\n"
                        for (index, record) in records.prefix(5).enumerated() {
                            let title = record["title"] as? String ?? "タイトルなし"
                            let userId = record["userId"] as? String ?? "(nil)"
                            let destination = record["destination"] as? String ?? "不明"
                            message += "[\(index + 1)] \(title)\n"
                            message += "  目的地: \(destination)\n"
                            message += "  userId: \(userId)\n\n"
                        }
                        if records.count > 5 {
                            message += "... 他\(records.count - 5)件"
                        }
                        alertMessage = message
                    }
                    showAlert = true
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "エラー: \(error.localizedDescription)"
                    showAlert = true
                    isCheckingStatus = false
                }
            }
        }
    }

    private func checkTravelPlanUserIds() {
        isCheckingStatus = true

        Task {
            do {
                let records = try await CloudKitService.shared.fetchAllRecords(recordType: "TravelPlan")
                var userIds: [String: Int] = [:]

                for record in records {
                    if let userId = record["userId"] as? String {
                        userIds[userId, default: 0] += 1
                    } else {
                        userIds["(nil)", default: 0] += 1
                    }
                }

                await MainActor.run {
                    var message = "【TravelPlan UserID分布】\n"
                    for (userId, count) in userIds.sorted(by: { $0.key < $1.key }) {
                        message += "\(userId): \(count)件\n"
                    }
                    message += "\n【現在のUser ID】\n\(authVM.userId ?? "未ログイン")"

                    if let currentUserId = authVM.userId {
                        let currentUserCount = userIds[currentUserId] ?? 0
                        message += "\n\n【結果】\n現在のユーザーIDに紐づくTravelPlan: \(currentUserCount)件"
                    }

                    alertMessage = message
                    showAlert = true
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "エラー: \(error.localizedDescription)"
                    showAlert = true
                    isCheckingStatus = false
                }
            }
        }
    }

}

#Preview {
    CloudKitTestView()
        .environmentObject(AuthViewModel())
}

