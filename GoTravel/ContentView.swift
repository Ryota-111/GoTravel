import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()
    
    var body: some View {
        Group {
            if auth.isLoggedIn {
                HomeView()
                    .environmentObject(auth)
            } else {
                LoginView()
                    .environmentObject(auth)
            }
        }
        .environmentObject(auth)
        .animation(.easeInOut, value: auth.isLoggedIn)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
