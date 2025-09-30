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
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)

            HStack(spacing: 15) {
                AsyncImage(url: URL(string: eventImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView()
                    }
                }
                .frame(width: 130, height: 130)
                .cornerRadius(radius: topLeft, corners: .topLeft)
                .cornerRadius(radius: bottomLeft, corners: .bottomLeft)

                VStack(alignment: .leading, spacing: 8) {
                    Text(eventName)
                        .font(.custom("Poppins-SemiBold", size: 18))
                        .foregroundColor(.black)

                    HStack(spacing: 5) {
                        Image(systemName: eventLocationImage)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(eventLocation)
                            .font(.custom("Poppins-Light", size: 14))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    HStack {
                        Text(eventPrice)
                            .font(.custom("Poppins-SemiBold", size: 18))
                            .foregroundColor(Color("cOrange"))

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: eventRateImage)
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                            Text("(\(eventRate))")
                                .font(.custom("Poppins-Regular", size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.trailing, 15)
            }
        }
        .frame(height: 130)
    }
}

extension View {
    func cornerRadius(radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
