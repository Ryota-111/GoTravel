import SwiftUI

struct AlbamHomeView: View {
    
    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - body
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark ? [.blue.opacity(0.7), .black] : [.blue.opacity(0.6), .white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        titleSection
                        JapanHomeCard
                    }
                }
            }
        }
    }
    
    private var titleSection: some View {
        Text("アルバム")
            .font(.largeTitle)
            .bold()
            .foregroundColor(.white)
    }
    
    private var JapanHomeCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("日本地図アルバム")
                    .foregroundColor(.gray)
            }
            
            ZStack {
                Image("prefecture_japan")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 340, height: 170)
                    .clipShape(Rectangle())
                    .cornerRadius(25)
                
                NavigationLink(destination: JapanPhotoView()) {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 340, height: 170)
                }
            }
        }
    }
}

#Preview {
    AlbamHomeView()
}
