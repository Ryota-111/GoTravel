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
            NavigationLink(destination: JapanPhotoView()) {
                Image("GoTravel_background")
                    .resizable()
                    .frame(width: 330, height: 150)
                    .cornerRadius(25)
            }
        }
    }
}

#Preview {
    AlbamHomeView()
}
