import Foundation
import SwiftUI

struct horizontalEventsCard: View {
    var menuName: String
    var menuImage: String
    var rectColor: Color
    var imageColors: Color
    var textColor: Color

    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(rectColor)
                    .frame(width: 60, height: 60)

                Image(systemName: menuImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
                    .foregroundColor(imageColors)
            }

            Text(menuName)
                .font(.body)
                .foregroundStyle(textColor)
        }
    }
}
