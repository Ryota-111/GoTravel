import Foundation
import SwiftUI

enum Hotels: String, CaseIterable, Identifiable {
    case bellagio
    case fairmontmanaged
    case raffles
    case theritz

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .bellagio:
            return "Bellagio"
        case .fairmontmanaged:
            return "Fairmont Managed"
        case .raffles:
            return "Raffles"
        case .theritz:
            return "The Ritz"
        }
    }
    
    var locationName: String {
        switch self {
            case .bellagio:
            return "Las Vegas - USA"
        case .fairmontmanaged:
            return "New York - USA"
        case .raffles:
            return "Singapore"
        case .theritz:
            return "London - UK"
        }
    }
    
    var imageName: String {
        switch self {
            case .bellagio:
            return "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800"
        case .fairmontmanaged:
            return "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800"
        case .raffles:
            return "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800"
        case .theritz:
            return "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800"
        }
    }
    
    var price: String {
        switch self {
            case .bellagio:
            return "$345"
        case .fairmontmanaged:
            return "$250"
        case .raffles:
            return "$420"
        case .theritz:
            return "$550"
        }
    }
    
    var rate: String {
        switch self {
            case .bellagio:
            return "4.0"
        case .fairmontmanaged:
            return "4.5"
        case .raffles:
            return "4.8"
        case .theritz:
            return "4.9"
        }
    }
    
    var discription: String {
        switch self {
        case .bellagio:
            return "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a tortor eget elit faucibus, quis tincidunt elit. Donec a tortor eget elit faucibus, quis tincidunt elit."
        case .fairmontmanaged:
            return "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a tortor eget elit faucibus, quis tincidunt elit. Donec a tortor eget elit faucibus, quis tincidunt elit."
        case .raffles:
            return "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a tortor eget elit faucibus, quis tincidunt elit. Donec a tortor eget elit faucibus, quis tincidunt elit."
        case .theritz:
            return "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a tortor eget elit faucibus, quis tincidunt elit. Donec a tortor eget elit faucibus, quis tincidunt elit."
        }
    }
}
