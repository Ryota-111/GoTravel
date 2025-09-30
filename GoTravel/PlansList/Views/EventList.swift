import Foundation
import SwiftUI

var topLeft: CGFloat = 20
var bottomLeft: CGFloat = 20

struct EventList: View {
    var eventName: String
    var eventImage: String
    var eventLocation: String
    var eventLocationImage: String
    var eventPrice: String
    var eventRate: String
    var eventRateImage: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(.white)
                .frame(height: 130)
            
            HStack(spacing: 15) {
                AsyncImage(url: URL(string: eventImage)) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 130, height: 130)
                .cornerRadius(radius: topLeft, corners: .topLeft)
                .cornerRadius(radius: bottomLeft, corners: .bottomLeft)
            }
        }
    }
}
