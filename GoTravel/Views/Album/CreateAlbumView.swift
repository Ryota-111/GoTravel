import SwiftUI

struct CreateAlbumView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    @StateObject private var albumManager = AlbumManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var creationMode: CreationMode = .manual
    @State private var albumTitle = ""
    @State private var selectedType: AlbumType = .travel
    @State private var selectedTravelPlan: TravelPlan?
    @Environment(\.colorScheme) var colorScheme

    let travelPlans: [TravelPlan]
    let albumTypes: [AlbumType] = [.travel, .family, .landscape, .food, .custom]

    enum CreationMode {
        case manual
        case fromTravelPlan
    }

    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 30) {
                headerView
                modeSelectionSection
                
                if creationMode == .manual {
                    manualCreationSection
                } else {
                    travelPlanSelectionSection
                }
                
                Spacer()
                
                createButton
                    .padding()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [themeManager.currentTheme.yprimary, themeManager.currentTheme.dark]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerView: some View {
        HStack {
            backButton

            Spacer()

            Text("新規アルバム")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.accent2)

            Spacer()
        }
        .padding()
        .background(themeManager.currentTheme.yprimary)
    }
    
    private var backButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundColor(themeManager.currentTheme.accent2)
                    .imageScale(.large)
                Text("戻る")
                    .foregroundColor(themeManager.currentTheme.accent2)
            }
        }
    }

    // MARK: - Mode Selection
    private var modeSelectionSection: some View {
        VStack(spacing: 12) {
            Text("アルバムの作成方法")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.accent2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ModeButton(
                    title: "新しく作成",
                    icon: "square.and.pencil",
                    isSelected: creationMode == .manual
                ) {
                    creationMode = .manual
                }

                ModeButton(
                    title: "旅行計画から",
                    icon: "airplane.departure",
                    isSelected: creationMode == .fromTravelPlan
                ) {
                    creationMode = .fromTravelPlan
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Manual Creation
    private var manualCreationSection: some View {
        VStack(spacing: 20) {
            TextField("アルバム名", text: $albumTitle)
                .font(.title3)
                .padding()
                .background(themeManager.currentTheme.secondaryText.opacity(0.2))
                .cornerRadius(15)

            VStack(alignment: .leading, spacing: 12) {
                Text("アルバムの種類")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.accent2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(albumTypes, id: \.self) { type in
                            AlbumTypeButton(
                                type: type,
                                isSelected: selectedType == type
                            ) {
                                selectedType = type
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Travel Plan Selection
    private var travelPlanSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("旅行計画を選択")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.accent2)

            if travelPlans.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 50))
                        .foregroundColor(themeManager.currentTheme.secondaryText)

                    Text("旅行計画がありません")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(travelPlans) { plan in
                            TravelPlanSelectionCard(
                                plan: plan,
                                isSelected: selectedTravelPlan?.id == plan.id
                            ) {
                                selectedTravelPlan = plan
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Create Button
    private var createButton: some View {
        Button(action: createAlbum) {
            Text("作成")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            buttonColor,
                            buttonColor.opacity(0.7)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(15)
        }
        .disabled(!canCreate)
        .opacity(canCreate ? 1 : 0.5)
    }

    private var buttonColor: Color {
        if creationMode == .fromTravelPlan {
            return selectedTravelPlan?.cardColor ?? themeManager.currentTheme.xprimary
        } else {
            return selectedType.defaultCoverColor
        }
    }

    private var canCreate: Bool {
        if creationMode == .manual {
            return !albumTitle.isEmpty
        } else {
            return selectedTravelPlan != nil
        }
    }

    private func createAlbum() {
        if creationMode == .manual {
            albumManager.createAlbum(title: albumTitle, type: selectedType)
        } else if let travelPlan = selectedTravelPlan {
            albumManager.createTravelPlanAlbum(from: travelPlan)
        }
        dismiss()
    }
}
