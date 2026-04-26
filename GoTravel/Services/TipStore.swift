import StoreKit
import SwiftUI
import Combine

@MainActor
class TipStore: ObservableObject {
    static let shared = TipStore()

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadingState: LoadingState = .loading
    @Published private(set) var purchaseState: PurchaseState = .idle

    private let productIds = [
        "com.gmail.taismryotasis.Travory.tip.small",
        "com.gmail.taismryotasis.Travory.tip.medium",
        "com.gmail.taismryotasis.Travory.tip.large",
        "com.gmail.taismryotasis.Travory.tip.xlarge"
    ]

    enum LoadingState {
        case loading
        case loaded
        case failed
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case failed(String)
    }

    private init() {
        Task { await loadProducts() }
    }

    func loadProducts() async {
        loadingState = .loading
        do {
            let fetched = try await Product.products(for: productIds)
            products = fetched.sorted { $0.price < $1.price }
            loadingState = fetched.isEmpty ? .failed : .loaded
        } catch {
            loadingState = .failed
        }
    }

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
