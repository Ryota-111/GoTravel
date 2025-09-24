import SwiftUI

struct HomeView: View {
    @StateObject private var vm = ProfileViewModel()
    @State private var isEditing: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showRemoveAvatarConfirm: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 18) {
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
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .shadow(radius: 6)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    
                    Menu {
                        Button("写真を選択") { showImagePicker = true }
                        if vm.avatarImage != nil {
                            Button("削除", role: .destructive) { showRemoveAvatarConfirm = true }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 42, height: 42)
                                .shadow(radius: 2)
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                        .padding(4)
                    }
                    .offset(x: -6, y: -6)
                }
                .padding(.top, 20)
                
                Form {
                    Section(header: Text("プロフィール")) {
                        TextField("名前", text: $vm.profile.name)
                            .disabled(!isEditing)
                        TextField("メールアドレス", text: $vm.profile.email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(!isEditing)
                    }
                    
                    if isEditing {
                        Section {
                            Button(action: {
                                vm.saveProfile()
                                isEditing = false
                            }) {
                                HStack {
                                    Spacer()
                                    if vm.isSaving {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Text("保存")
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("マイページ")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "キャンセル" : "編集") {
                        if isEditing {
                            let reloaded = ProfileViewModel()
                            vm.profile = reloaded.profile
                            vm.avatarImage = reloaded.avatarImage
                            isEditing = false
                        } else {
                            isEditing = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                PhotoPicker { image in
                    vm.saveAvatar(image)
                    showImagePicker = false
                }
            }
            .confirmationDialog("プロフィール画像を削除しますか？", isPresented: $showRemoveAvatarConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    vm.removeAvatar()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
