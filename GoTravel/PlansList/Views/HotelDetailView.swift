import Foundation
import SwiftUI

struct HotelDetailView: View {
    let hotel: Hotels
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack {
                        AsyncImage(url: URL(string: hotel.imageName)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                        } placeholder: {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: 300)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "cloak")
                                .resizable()
                                .frame(width: 25, height: 25)
                                .foregroundColor(Color("cOrange"))
                            Text("3 Hours")
                                .font(.custom("Poppin-Light", size: 16))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Image(systemName: "star")
                                .resizable()
                                .frame(width: 25, height: 25)
                                .foregroundColor(Color("cOrange"))
                            Text(hotel.rate)
                                .font(.custom("Poppin-Light", size: 16))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Image(systemName: "therometer.transmission")
                                .resizable()
                                .frame(width: 25, height: 25)
                                .foregroundColor(Color("cOrange"))
                            Text("30°C")
                                .font(.custom("Poppin-Light", size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}
