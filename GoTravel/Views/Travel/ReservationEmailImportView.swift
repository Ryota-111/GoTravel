import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// 予約確認メールを貼り付けて、予約の下書きを作る画面。予約の編集画面から開く。
///
/// **読み取った内容をそのまま保存しない。** 下書きは編集画面に返し、
/// 確かめてから保存してもらう。読み違えても「直す手間」で済むようにするため。
/// 往復の航空券のように1通に複数の予約があるときは、まとめて返す（編集画面が順に開く）
struct ReservationEmailImportView: View {
    let plan: TravelPlan
    /// 利用者が選んだ種類。選んでいなければ nil（文面から当てる）
    let kind: Reservation.Kind?
    /// 共有メニューから送られてきた本文や画像。あれば開いてすぐ読み取る
    var initial: SharedImportInbox.Item.Content? = nil
    let onImport: ([ImportedReservation]) -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var foundNothing = false
    @State private var isReading = false
    /// 確認画面のスクリーンショットや e チケットの画像
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isReadingImage = false
    @State private var imageReadFailed = false
    /// e チケットや、メールを印刷した PDF（3.6）
    @State private var showsPDFImporter = false
    @State private var pdfReadFailed = false
    @State private var showsGmailHelp = false
    @FocusState private var isTextFocused: Bool

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }
    private var canRead: Bool { !isReading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark
                    ? themeManager.currentTheme.backgroundDark
                    : themeManager.currentTheme.backgroundLight)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    pasteSection
                        .padding(20)
                }
            }
            .navigationTitle("予約を取り込む")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                switch initial {
                case .text(let shared):
                    text = shared
                    await read()
                case .image(let url):
                    if let image = UIImage(contentsOfFile: url.path) {
                        await readImage(image)
                    } else {
                        imageReadFailed = true
                    }
                case .pdf(let url):
                    await readPDF(url)
                case nil:
                    break
                }
            }
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                pickedPhoto = nil
                Task { await readImage(item) }
            }
            .fileImporter(isPresented: $showsPDFImporter, allowedContentTypes: [.pdf]) { result in
                guard case .success(let url) = result else {
                    pdfReadFailed = true
                    return
                }
                Task { await readPDF(url) }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(accent)
                }
            }
        }
    }

    private var pasteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(kind.map { "\($0.label)の予約確認メールの本文を貼り付けるか、" }
                 ?? "予約確認メールの本文を貼り付けるか、")
                + Text("予約の確認画面のスクリーンショットや e チケットの PDF を選んでください。予約番号・日時・金額などを読み取って、入力欄に入れます。")
            .font(.system(size: 13))
            .foregroundColor(themeManager.currentTheme.secondaryText)

            PasteButton(payloadType: String.self) { strings in
                guard let pasted = strings.first else { return }
                Task { @MainActor in
                    text = pasted
                    foundNothing = false
                }
            }
            .tint(accent)
            .labelStyle(.titleAndIcon)

            HStack(spacing: 10) {
                // スクリーンショットや e チケットの画像から読む。
                // 予約サイトのアプリの中だけで確認していて、メールが無い予約もあるため
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    outlinedLabel("写真から読み取る", systemImage: "photo")
                }
                .disabled(isReadingImage)

                // e チケットの PDF や、メールを PDF にしたもの（3.6）
                Button {
                    showsPDFImporter = true
                } label: {
                    outlinedLabel("PDFから読み取る", systemImage: "doc.richtext")
                }
                .buttonStyle(.plain)
                .disabled(isReadingImage)
            }

            gmailHelp

            if isReadingImage {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("文字を読み取っています…")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
            }
            if pdfReadFailed {
                Label("PDF から文字を読み取れませんでした。鍵のかかっていない PDF を選んでください。",
                      systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if imageReadFailed {
                Label("画像から文字を読み取れませんでした。文字がはっきり写った画像を選んでください。",
                      systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused($isTextFocused)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(textColor)
                    .font(.system(size: 13))
                    .frame(minHeight: 220)
                    .padding(8)
                if text.isEmpty {
                    Text("ここにメールの本文を貼り付け（写真や PDF から読み取った文字もここに入ります）")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(cardFill))

            if foundNothing {
                Label("予約の内容が見つかりませんでした。本文全体を貼り付けているか確かめてください。",
                      systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await read() }
            } label: {
                // 端末の中の AI で読むと数秒かかることがあるので、読んでいるあいだはそれと分かるようにする
                HStack(spacing: 8) {
                    if isReading {
                        ProgressView()
                            .tint(ThemePreset.readableText(on: accent))
                    }
                    Text(isReading ? "読み取っています…" : "読み取る")
                }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ThemePreset.readableText(on: accent))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(accent))
            }
            .buttonStyle(.plain)
            .disabled(!canRead)
            .opacity(canRead ? 1 : 0.5)

            Label("メールや画像・PDF の内容はこの端末の中だけで読み取ります。どこにも送りません。",
                  systemImage: "lock")
                .font(.system(size: 11))
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func outlinedLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 15, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundColor(accent)
            .background(Capsule().stroke(accent, lineWidth: 1))
    }

    /// Gmail アプリからの送り方（3.6、ご意見から）。
    /// Gmail にはメール1通を丸ごと共有するボタンが無く、「印刷」から PDF にして共有する
    private var gmailHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showsGmailHelp.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                    Text("Gmail のメールを送るには")
                    Spacer(minLength: 0)
                    Image(systemName: showsGmailHelp ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsGmailHelp {
                VStack(alignment: .leading, spacing: 6) {
                    helpStep(1, "Gmail で予約確認メールを開き、メールの右上の「︙」から「印刷」を選ぶ")
                    helpStep(2, "印刷の画面の右上にある共有ボタン（四角から矢印）を押す")
                    helpStep(3, "「Travory」を選ぶ。次に Travory を開くと、どの旅行の予約か選んで取り込めます")
                    Text("本文を長押しして選び、「共有」から「Travory」を選んでも送れます。")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(cardFill))
            }
        }
    }

    private func helpStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ThemePreset.readableText(on: accent))
                .frame(width: 18, height: 18)
                .background(Circle().fill(accent))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// PDF の文字を読んで入力欄に入れ、そのまま予約として読み取る（3.6）
    private func readPDF(_ url: URL) async {
        isReadingImage = true
        imageReadFailed = false
        pdfReadFailed = false
        foundNothing = false
        defer { isReadingImage = false }

        guard let recognized = try? await ReservationPDFTextReader.text(at: url) else {
            pdfReadFailed = true
            return
        }
        text = recognized
        await read()
    }

    /// 画像の文字を読んで入力欄に入れ、そのまま予約として読み取る。
    /// 読んだ文字を入力欄に見せておくのは、読み違えたときに直せるようにするため
    private func readImage(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            imageReadFailed = true
            return
        }
        await readImage(image)
    }

    private func readImage(_ image: UIImage) async {
        isReadingImage = true
        imageReadFailed = false
        pdfReadFailed = false
        foundNothing = false
        defer { isReadingImage = false }

        guard let cgImage = image.cgImage,
              let recognized = try? await ReservationImageTextReader.text(
                  from: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation)) else {
            imageReadFailed = true
            return
        }
        text = recognized
        await read()
    }

    private func read() async {
        isTextFocused = false
        isReading = true
        defer { isReading = false }

        // 決まった形の読み取りに、使える端末では端末の中の AI で足りないところを埋める（3.4。どこにも送らない）
        let drafts = await ReservationReader.read(text, kind: kind).filter(\.hasContent)
        guard !drafts.isEmpty else {
            foundNothing = true
            return
        }

        // 目的地が海外のときだけ現地の時計を使う。国内なら日本時間
        var destination: TimeZone?
        if let zone = await DestinationTimeZoneService.shared.timeZone(for: plan),
           ScheduleClock.isForeign(zone, at: plan.startDate) {
            destination = zone
        }

        var results = drafts.map {
            $0.makeReservation(destinationTimeZone: destination, tripCurrency: plan.currencyCode,
                               yenRate: plan.exchangeRate(for: CurrencyCatalog.yen))
        }
        // 往復の航空券などは、メールの金額が全部の合計になっている
        if results.count > 1, results[0].reservation.cost != nil || results[0].reservation.foreignCost != nil {
            results[0].notes.append("金額はメールの合計です。ほかの\(results.count - 1)件の分も含まれています")
        }
        onImport(results)
        dismiss()
    }
}

private extension ReservationDraft {
    /// 何も読み取れなかった下書き（予約のメールではなかった）を落とす
    var hasContent: Bool {
        start != nil || confirmationNumber != nil || transportNumber != nil
    }
}

private extension CGImagePropertyOrientation {
    /// UIImage の向きを、Vision に渡す向きに直す
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
