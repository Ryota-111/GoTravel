import SwiftUI

struct CreateAlbumView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    @StateObject private var albumManager = AlbumManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var creationMode: CreationMode = .manual
    @State private var albumTitle = ""
    @State private var selectedType: AlbumType = .travel
    @State private var selectedTravelPlan: TravelPlan?

    let travelPlans: [TravelPlan]
    let albumTypes: [AlbumType] = [.travel, .family, .landscape, .food, .custom]

    enum CreationMode {
        case manual
        case fromTravelPlan
    }

    // MARK: - Theme
    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var cardBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var fieldBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.backgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    private var bgGradient: some View {
        let colors: [Color]
        switch themeManager.currentTheme.type {
        case .whiteBlack:
            colors = [Color(white: 0.97), Color(white: 0.91)]
        default:
            colors = colorScheme == .dark
                ? [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark]
                : [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]
        }
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private var canCreate: Bool {
        creationMode == .manual
            ? !albumTitle.trimmingCharacters(in: .whitespaces).isEmpty
            : selectedTravelPlan != nil
    }

    // cardColorが未設定、または白すぎる色のプランにIDから決定論的な色を割り当てる
    private func resolvedPlanColor(_ plan: TravelPlan) -> Color {
        let palette: [Color] = [
            .blue, .purple, .pink, .orange, .teal,
            .indigo, Color(red: 0.2, green: 0.65, blue: 0.4),
            Color(red: 0.85, green: 0.35, blue: 0.25)
        ]
        let key = plan.id ?? plan.title
        let fallback = palette[abs(key.hashValue) % palette.count]

        guard let color = plan.cardColor else { return fallback }

        // 知覚輝度 > 0.85 は白に近すぎるためパレットを使用
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return fallback }
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness < 0.85 ? color : fallback
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            bgGradient

            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        modeSection

                        if creationMode == .manual {
                            titleSection
                            typeSection
                        } else {
                            travelPlanSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }

                createButton
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(accentColor)
                    .imageScale(.medium)
                    .padding(8)
                    .background(accentColor.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            Text("新規アルバム")
                .font(.headline)
                .foregroundColor(accentColor)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(themeManager.currentTheme.xprimary.opacity(0.12))
    }

    // MARK: - Mode Section
    private var modeSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("作成方法", icon: "square.grid.2x2")
                HStack(spacing: 12) {
                    modeCard(
                        title: "新しく作成",
                        subtitle: "タイトルと種類を設定",
                        icon: "square.and.pencil",
                        mode: .manual
                    )
                    modeCard(
                        title: "旅行計画から",
                        subtitle: "既存の計画を使う",
                        icon: "airplane.departure",
                        mode: .fromTravelPlan
                    )
                }
            }
        }
    }

    private func modeCard(title: String, subtitle: String, icon: String, mode: CreationMode) -> some View {
        let isSelected = creationMode == mode
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                creationMode = mode
            }
        }) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? themeManager.currentTheme.xprimary
                              : themeManager.currentTheme.xprimary.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .white : accentColor.opacity(0.6))
                }
                VStack(spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(isSelected ? accentColor : accentColor.opacity(0.55))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? themeManager.currentTheme.xprimary.opacity(0.1)
                          : accentColor.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected
                                    ? themeManager.currentTheme.xprimary
                                    : accentColor.opacity(0.15),
                                    lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Title Section
    private var titleSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("アルバム名", icon: "pencil")
                TextField("例：夏の北海道旅行", text: $albumTitle)
                    .font(.body)
                    .foregroundColor(accentColor)
                    .padding(14)
                    .background(fieldBg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                albumTitle.isEmpty
                                    ? themeManager.currentTheme.error.opacity(0.35)
                                    : themeManager.currentTheme.xprimary.opacity(0.3),
                                lineWidth: 1.5
                            )
                    )
            }
        }
    }

    // MARK: - Type Section
    private var typeSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("アルバムの種類", icon: "tag.fill")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    ForEach(albumTypes, id: \.self) { type in
                        typeCard(type)
                    }
                }
            }
        }
    }

    private func typeCard(_ type: AlbumType) -> some View {
        let isSelected = selectedType == type
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedType = type
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(type.defaultCoverColor.opacity(isSelected ? 0.9 : 0.18))
                        .frame(width: 50, height: 50)
                        .shadow(color: isSelected ? type.defaultCoverColor.opacity(0.4) : .clear,
                                radius: 6, x: 0, y: 3)
                    Image(systemName: type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : type.defaultCoverColor)
                }
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(type.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? type.defaultCoverColor : accentColor.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.defaultCoverColor.opacity(0.08) : accentColor.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? type.defaultCoverColor : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Travel Plan Section
    private var travelPlanSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("旅行計画を選択", icon: "airplane.departure")

                if travelPlans.isEmpty {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeManager.currentTheme.xprimary.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: "airplane.departure")
                                .font(.system(size: 28))
                                .foregroundColor(themeManager.currentTheme.xprimary.opacity(0.4))
                        }
                        Text("旅行計画がありません")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                        Text("先に旅行計画を作成してください")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    VStack(spacing: 10) {
                        ForEach(travelPlans) { plan in
                            planCard(plan)
                        }
                    }
                }
            }
        }
    }

    private func planCard(_ plan: TravelPlan) -> some View {
        let isSelected = selectedTravelPlan?.id == plan.id
        let planColor = resolvedPlanColor(plan)
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTravelPlan = plan
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(planColor.opacity(0.85))
                        .frame(width: 46, height: 46)
                        .shadow(color: planColor.opacity(0.35), radius: 4, x: 0, y: 2)
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(accentColor)
                        .lineLimit(1)
                    Text(plan.destination)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(planColor)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? planColor.opacity(0.08) : fieldBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? planColor : accentColor.opacity(0.1), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Create Button
    private var createButton: some View {
        Button(action: createAlbum) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("アルバムを作成")
            }
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(canCreate
                          ? themeManager.currentTheme.xprimary
                          : themeManager.currentTheme.secondaryText)
                    .shadow(color: themeManager.currentTheme.xprimary.opacity(canCreate ? 0.4 : 0),
                            radius: 8, x: 0, y: 4)
            )
            .animation(.easeInOut(duration: 0.2), value: canCreate)
        }
        .disabled(!canCreate)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helper Views
    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBg)
                    .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
            )
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.xprimary)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)
        }
    }

    // MARK: - Action
    private func createAlbum() {
        if creationMode == .manual {
            albumManager.createAlbum(title: albumTitle, type: selectedType)
        } else if let travelPlan = selectedTravelPlan {
            albumManager.createTravelPlanAlbum(from: travelPlan)
        }
        dismiss()
    }
}
