import Foundation
import SwiftUI

enum Hotels: String, CaseIterable, Identifiable {
    case bellagio
    case fairmontmanaged
    case raffles
    case theritz
    
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
            return "https//dynamic-media-cdn.tripadvisor.com/media/photo-s/01/4d/44/a0/bellagio-resorts.jpg"
        case .fairmontmanaged:
            return "https//dynamic-media-cdn.tripadvisor.com/media/photo-s/01/4d/44/a0/bellagio-resorts.jpg"
        case .raffles:
            return "https//dynamic-media-cdn.tripadvisor.com/media/photo-s/01/4d/44/a0/bellagio-resorts.jpg"
        case .theritz:
            return "https//dynamic-media-cdn.tripadvisor.com/media/photo-s/01/4d/44/a0/bellagio-resorts.jpg"
        }
    }
    
    var price: String {
        switch self {
            case .bellagio:
            return "$1,200"
        case .fairmontmanaged:
            return "$1,100"
        case .raffles:
            return "$1,300"
        case .theritz:
            return "$1,400"
        }
    }
    
    var rate: String {
        switch self {
            case .bellagio:
            return "4.5"
        case .fairmontmanaged:
            return "4.3"
        case .raffles:
            return "4.7"
        case .theritz:
            return "4.6"
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
