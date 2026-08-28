import StoreKit
import SwiftUI
import Combine

/// 追加テーマの買い切り購入を管理する。
/// TipStore（投げ銭・消耗型）とは別物で、こちらは非消耗型の所有判定を持つ。
@MainActor
final class ProStore: ObservableObject {
    static let shared = ProStore()

    /// App Store Connect に登録する非消耗型の商品ID
    static let productId = "com.gmail.taismryotasis.Travory.pro.themes"

    @Published private(set) var product: Product?
    @Published private(set) var isPurchased = false
    @Published private(set) var loadingState: LoadingState = .loading
    @Published private(set) var purchaseState: PurchaseState = .idle

    private var updatesTask: Task<Void, Never>?

    enum LoadingState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case restoring
        case success
        case failed(String)
    }

    /// 表示用の価格。読み込めていないときは nil
    var displayPrice: String? { product?.displayPrice }

    private init() {
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
        updatesTask = Task { await listenForTransactionUpdates() }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Transaction Updates Listener
    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }

    // MARK: - Load Product
    func loadProduct() async {
        loadingState = .loading
        do {
            let fetched = try await Product.products(for: [Self.productId])
            product = fetched.first
            loadingState = fetched.isEmpty
                ? .failed("商品が見つかりません。App Store Connect の商品IDを確認してください。")
                : .loaded
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Entitlements
    /// 所有しているかを調べ直し、テーマ側にも反映する
    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productId,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPurchased = owned
        ThemeManager.shared.setPremiumUnlocked(owned)
    }

    // MARK: - Purchase
    func purchase() async {
        guard let product else {
            purchaseState = .failed("商品を読み込めていません")
            return
        }

        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    purchaseState = .success
                case .unverified:
                    purchaseState = .failed("購入の検証に失敗しました")
                }
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                // 承認待ち。完了すると Transaction.updates 側で拾う
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed("購入に失敗しました")
        }
    }

    // MARK: - Restore
    func restore() async {
        purchaseState = .restoring
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = isPurchased ? .success : .failed("復元できる購入がありませんでした")
        } catch {
            purchaseState = .failed("復元に失敗しました")
        }
    }

    func resetState() {
        purchaseState = .idle
    }
}
