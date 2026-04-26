import StoreKit
import SwiftUI
import Combine

@MainActor
class TipStore: ObservableObject {
    static let shared = TipStore()

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadingState: LoadingState = .loading
    @Published private(set) var purchaseState: PurchaseState = .idle

    private var updatesTask: Task<Void, Never>?

    private let productIds = [
        "com.gmail.taismryotasis.Travory.tip.small",
        "com.gmail.taismryotasis.Travory.tip.medium",
        "com.gmail.taismryotasis.Travory.tip.large",
        "com.gmail.taismryotasis.Travory.tip.xlarge"
    ]

    enum LoadingState {
        case loading
        case loaded
        case failed(String)
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case failed(String)
    }

    private init() {
        Task { await loadProducts() }
        updatesTask = Task { await listenForTransactionUpdates() }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Transaction Updates Listener
    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                await transaction.finish()
                purchaseState = .success
            case .unverified:
                break
            }
        }
    }

    // MARK: - Load Products
    func loadProducts() async {
        loadingState = .loading
        do {
            let fetched = try await Product.products(for: productIds)
            products = fetched.sorted { $0.price < $1.price }
            loadingState = fetched.isEmpty
                ? .failed("商品が見つかりません。スキームのStoreKit設定を確認してください。")
                : .loaded
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    purchaseState = .success
                case .unverified:
                    purchaseState = .failed("購入の検証に失敗しました")
                }
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed("購入に失敗しました")
        }
    }

    func resetState() {
        purchaseState = .idle
    }
}
