import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("ようこそ、\(auth.userEmail.isEmpty ? "ゲスト" : auth.userEmail) さん")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding()
                
                // サンプルの中身: お気に入りスポット一覧 (ダミー)
                List {
                    Section(header: Text("おすすめスポット")) {
                        ForEach(sampleSpots, id: \.self) { spot in
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.pink)
                                Text(spot)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    let _ = auth.signOut()
                }) {
                    Text("ログアウト")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .navigationTitle("ホーム")
        }
    }
    
    // ダミーデータ
    private var sampleSpots: [String] {
        ["東京タワー", "京都・嵐山", "大阪・道頓堀", "富士山ビュースポット"]
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthViewModel())
    }
}
