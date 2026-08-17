import SwiftUI
import CoreLocation

/// 遊び・体験のチケットを探す画面。
///
/// 旅行計画は「しおり」として扱いたいので、提携リンクはそちらに置かず
/// この画面にまとめている。広告として差し込むのではなく、
/// 「このアプリからチケットも探せる」という機能として見せるための構成。
///
/// 景品表示法（ステマ規制）により広告であることの明示は必須。
/// ただし表示の形は自由なので、行ごとの「PR」バッジではなく
/// 画面上部に一度だけ文章で書いている。
struct ExperienceSearchView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @StateObject private var locationManager = LocationManager()

    @State private var presentedURL: URL?
    @State private var isResolvingLocation = false
    @State private var locationErrorMessage: String?

    private var accent: Color { themeManager.currentTheme.actionFill }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var titleColor: Color { ThemePreset.readableText(on: cardFill) }

    var body: some View {
        ZStack {
            (colorScheme == .dark
                ? themeManager.currentTheme.backgroundDark
                : themeManager.currentTheme.backgroundLight)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    currentLocationCard
                    prefectureSections
                }
                .padding(20)
            }
        }
        .navigationTitle("あそび・体験を探す")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedURL) { url in
            SafariView(url: url)
        }
        .alert("現在地を取得できませんでした", isPresented: Binding(
            get: { locationErrorMessage != nil },
            set: { if !$0 { locationErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(locationErrorMessage ?? "")
        }
        // 許可を求めた直後に位置が届くので、届いたら続きを進める
        .onChange(of: locationManager.currentLocation?.latitude) { _, _ in
            guard isResolvingLocation, let coordinate = locationManager.currentLocation else { return }
            Task { await openFromCoordinate(coordinate) }
        }
        .onChange(of: locationManager.didFailToLocate) { _, failed in
            guard failed, isResolvingLocation else { return }
            isResolvingLocation = false
            locationErrorMessage = "設定アプリで位置情報の利用を許可すると、現在地の周辺から探せます。"
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("行き先の遊び・体験を予約")
                .font(.title3.bold())
                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

            Text("水族館・温泉・体験教室・日帰りツアーなど、当日から使えるチケットを探せます。")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            // ステマ規制対応。省略不可
            Text("提携サイト「アソビュー！」へ移動します。当アプリは提携により収益を得る場合があります。")
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(cardFill))
        }
    }

    // MARK: - 現在地

    private var currentLocationCard: some View {
        Button(action: startLocationSearch) {
            HStack(spacing: 12) {
                if isResolvingLocation {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accent))
                        .frame(width: 38, height: 38)
                } else {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18))
                        .foregroundColor(accent)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(accent.opacity(0.14)))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isResolvingLocation ? "現在地を確認しています…" : "現在地の周辺から探す")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(titleColor)
                    Text("いまいる都道府県の体験を表示します")
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.forward.square")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(cardFill))
        }
        .buttonStyle(.plain)
        .disabled(isResolvingLocation)
    }

    // MARK: - 都道府県

    private var prefectureSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("都道府県から探す")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

            ForEach(AsoviewArea.regions) { region in
                VStack(alignment: .leading, spacing: 8) {
                    Text(region.name)
                        .font(.caption.weight(.bold))
                        .foregroundColor(accent)

                    prefectureGrid(region.prefectures)
                }
            }
        }
    }

    private func prefectureGrid(_ prefectures: [AsoviewArea.Prefecture]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(prefectures) { prefecture in
                Button {
                    presentedURL = AffiliateLink.asoviewURL(slug: prefecture.slug)
                } label: {
                    Text(prefecture.name)
                        .font(.caption)
                        .foregroundColor(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(cardFill))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func startLocationSearch() {
        isResolvingLocation = true

        // すでに取得済みならそのまま使う
        if let coordinate = locationManager.currentLocation {
            Task { await openFromCoordinate(coordinate) }
            return
        }
        locationManager.requestCurrentLocation()
    }

    private func openFromCoordinate(_ coordinate: CLLocationCoordinate2D) async {
        let url = await AffiliateLink.asoviewURL(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            fallbackText: ""
        )
        isResolvingLocation = false

        if let url {
            presentedURL = url
        } else {
            // アソビューは国内専用なので、国外だと該当ページが無い
            locationErrorMessage = "現在地に対応するページが見つかりませんでした。日本国内でお試しいただくか、都道府県から選んでください。"
        }
    }
}

// sheet(item:) に URL を直接渡せるようにする
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
