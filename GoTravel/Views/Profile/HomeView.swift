import SwiftUI

struct HomeView: View {
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 20) {
                        avatarSection
                        profileNavigationCard
                        accountActionCard
                    }
                    .padding()
                }
                .navigationTitle("プロフィール")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    private var avatarSection: some View {
        Group {
            if let ui = vm.avatarImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(width: 150, height: 150)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    private var profileNavigationCard: some View {
        NavigationLink(destination: ProfileEditView(vm: vm)) {
            VStack(alignment: .leading, spacing: 15) {
                Text("プロフィール編集")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text("名前、メールアドレスの変更")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
        }
    }
    
    private var accountActionCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("アカウント")
                .font(.headline)
                .foregroundColor(.white)

            NavigationLink(destination: AccountActionView(vm: vm)) {
                HStack {
                    Text("サインアウト / アカウント削除")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [.blue.opacity(0.7), .black] : [.blue.opacity(0.6), .white]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct ProfileEditView: View {
    @StateObject var vm: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showImagePicker = false
    @State private var showRemoveAvatarConfirm = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    avatarSection
                    
                    nameEmailEditSection
                    
                    saveButton
                }
                .padding()
            }
            .navigationTitle("プロフィール編集")
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker { image in
                vm.saveAvatar(image)
                showImagePicker = false
            }
        }
        .confirmationDialog("プロフィール画像を削除",
                            isPresented: $showRemoveAvatarConfirm) {
            Button("削除", role: .destructive) { vm.removeAvatar() }
        }
    }
    
    private var avatarSection: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let ui = vm.avatarImage {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(width: 150, height: 150)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Menu {
                Button("写真を選択") { showImagePicker = true }
                if vm.avatarImage != nil {
                    Button("削除", role: .destructive) { showRemoveAvatarConfirm = true }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .offset(x: -10, y: -10)
        }
        .padding(.top, 20)
    }
    private var nameEmailEditSection: some View {
        VStack(spacing: 15) {
            TextField("名前", text: $vm.profile.name)
                .textFieldStyle(CustomTextFieldStyle())
            
            TextField("メールアドレス", text: $vm.profile.email)
                .textFieldStyle(CustomTextFieldStyle())
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            vm.saveProfile()
            presentationMode.wrappedValue.dismiss()
        }) {
            Text("保存")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
        }
        .disabled(vm.isSaving)
    }
}

struct AccountActionView: View {
    @StateObject var vm: ProfileViewModel
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Button(action: { vm.signOut { _ in } }) {
                    Text("サインアウト")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: { vm.deleteAccount { _ in } }) {
                    Text("アカウント削除")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("アカウントアクション")
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.white)
            .padding(10)
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
    }
}
