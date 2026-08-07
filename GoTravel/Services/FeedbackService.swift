import Foundation
import CloudKit
import UIKit

/// 要望や不具合の報告を CloudKit のパブリックDBへ送る。
///
/// メールアプリの設定に左右されず、アプリを離れずに送れるようにするためのもの。
/// バージョンや機種を自動で添えることで、どの環境で起きたのかを聞き返さずに済むようにしている。
@MainActor
final class FeedbackService {
    static let shared = FeedbackService()

    /// CloudKit 側のレコードタイプ名。Console で中身を読むときの名前でもある
    static let recordType = "Feedback"

    /// 本文の上限。CloudKit の String は十分長く入るが、読む側が破綻しない範囲に収める
    static let messageLimit = 2000

    enum SubmitError: LocalizedError {
        case emptyMessage
        case rateLimited
        case iCloudUnavailable
        case failed

        var errorDescription: String? {
            switch self {
            case .emptyMessage:
                return "内容を入力してください。"
            case .rateLimited:
                return "本日の送信上限に達しました。お手数ですが、明日以降にお試しください。"
            case .iCloudUnavailable:
                return "iCloudにサインインすると送信できます。設定アプリからサインインしてください。"
            case .failed:
                return "送信できませんでした。通信環境をご確認のうえ、もう一度お試しください。"
            }
        }
    }

    /// 誤操作や連投で埋まらないよう、端末側で1日の件数を抑える
    private let dailyLimit = 3
    private let historyKey = "feedbackSubmittedAt"

    private let container = CKContainer(identifier: "iCloud.com.gmail.taismryotasis.Travory")

    private init() {}

    var remainingToday: Int {
        max(0, dailyLimit - todaysSubmissions().count)
    }

    func submit(kind: FeedbackKind, message: String, contactEmail: String) async throws {
        let body = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { throw SubmitError.emptyMessage }
        guard remainingToday > 0 else { throw SubmitError.rateLimited }

        // サインインしていないと保存が必ず失敗するので、送信前に理由を出し分ける
        let status = try? await container.accountStatus()
        guard status == .available else { throw SubmitError.iCloudUnavailable }

        let record = CKRecord(recordType: Self.recordType)
        record["kind"] = kind.rawValue as CKRecordValue
        record["message"] = String(body.prefix(Self.messageLimit)) as CKRecordValue
        record["contactEmail"] = contactEmail.trimmingCharacters(in: .whitespacesAndNewlines) as CKRecordValue
        record["appVersion"] = Self.appVersion as CKRecordValue
        record["osVersion"] = UIDevice.current.systemVersion as CKRecordValue
        record["deviceModel"] = Self.deviceModel as CKRecordValue
        record["submittedAt"] = Date() as CKRecordValue

        do {
            _ = try await container.publicCloudDatabase.save(record)
        } catch {
            throw SubmitError.failed
        }

        recordSubmission()
    }

    // MARK: - 送信履歴

    private func todaysSubmissions() -> [Date] {
        let stored = UserDefaults.standard.array(forKey: historyKey) as? [Date] ?? []
        return stored.filter { Calendar.current.isDateInToday($0) }
    }

    private func recordSubmission() {
        var history = todaysSubmissions()
        history.append(Date())
        UserDefaults.standard.set(history, forKey: historyKey)
    }

    // MARK: - 環境情報

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    /// "iPhone16,2" のような機種識別子。UIDevice.model は "iPhone" しか返さず区別できない
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let identifier = Mirror(reflecting: systemInfo.machine).children
            .reduce(into: "") { result, element in
                guard let value = element.value as? Int8, value != 0 else { return }
                result.append(Character(UnicodeScalar(UInt8(value))))
            }

        return identifier.isEmpty ? UIDevice.current.model : identifier
    }
}
