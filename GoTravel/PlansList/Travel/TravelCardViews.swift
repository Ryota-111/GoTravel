import SwiftUI

struct TravelCardViews: View {
    var travelName: String
    var travelLocation: String
    var travelImage: String
    var isLiked: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(colors: [Color("back"), Color("back2")], startPoint: .topTrailing, endPoint: .bottomLeading))
                .frame(width: 250, height: 250)
            
            AsyncImage(url: URL(string: travelImage)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 250)
                    .cornerRadius(25)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 250, height: 250)
            
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)
                            .frame(width: 40, height: 40)
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 25, height: 25)
                            .foregroundColor(Color("cOrange"))
                    }
                }
                
                Spacer()
                
                Text(travelName).font(.custom("Poppins-Regular", size: 10))
                    .foregroundStyle(.white)
                    .kerning(-1)
                
                HStack {
                    Image(systemName: "mappin.and.ellipse.circle")
                        .imageScale(.large)
                        .foregroundColor(.white)
                    Text(travelLocation)
                        .font(.custom("Poppin-Light", size: 15))
                        .foregroundStyle(.white)
                        .kerning(-1)
                }
            }
            .padding([.vertical, .horizontal])
        }
        .frame(maxWidth: 250, maxHeight: 250)
    }
}
