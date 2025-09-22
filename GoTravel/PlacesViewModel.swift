import Foundation
import Combine
import MapKit
import FirebaseFirestore

final class PlacesViewModel: ObservableObject {
    @Published var places: [VisitedPlace] = []
    private var listener: ListenerRegistration?
    
    init() {
        startListening()
    }
    
    deinit {
        stopListening()
    }
    
    func startListening() {
        listener = FirestoreService.shared.observePlaces { [weak self] result in
            switch result {
            case .success(let list):
                DispatchQueue.main.async {
                    self?.places = list
                }
            case .failure(let err):
                print("Failed to observe places:", err.localizedDescription)
                DispatchQueue.main.async {
                    self?.places = []
                }
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
