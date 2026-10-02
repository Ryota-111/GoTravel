import SwiftUI
import PhotosUI

/// 予約確認メールを貼り付けて、予約の下書きを作る画面。予約の編集画面から開く。
///
/// **読み取った内容をそのまま保存しない。** 下書きは編集画面に返し、
/// 確かめてから保存してもらう。読み違えても「直す手間」で済むようにするため。
/// 往復の航空券のように1通に複数の予約があるときは、まとめて返す（編集画面が順に開く）
struct ReservationEmailImportView: View {
    let plan: TravelPlan
    /// 利用者が選んだ種類。選んでいなければ nil（文面から当てる）
    let kind: Reservation.Kind?
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
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                pickedPhoto = nil
                Task { await readImage(item) }
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
                + Text("予約の確認画面のスクリーンショットを選んでください。予約番号・日時・金額などを読み取って、入力欄に入れます。")
            .font(.system(size: 13))
            .foregroundColor(themeManager.currentTheme.secondaryText)

            HStack(spacing: 10) {
                PasteButton(payloadType: String.self) { strings in
                    guard let pasted = strings.first else { return }
                    Task { @MainActor in
                        text = pasted
                        foundNothing = false
                    }
                }
                .tint(accent)
                .labelStyle(.titleAndIcon)

                // スクリーンショットや e チケットの画像から読む。
                // 予約サイトのアプリの中だけで確認していて、メールが無い予約もあるため
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Label("写真から読み取る", systemImage: "photo")
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundColor(accent)
                        .background(Capsule().stroke(accent, lineWidth: 1))
                }
                .disabled(isReadingImage)
            }

            if isReadingImage {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("画像の文字を読み取っています…")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
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
                    Text("ここにメールの本文を貼り付け（写真から読み取った文字もここに入ります）")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))

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
                Text("読み取る")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ThemePreset.readableText(on: accent))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(accent))
            }
            .buttonStyle(.plain)
            .disabled(!canRead)
            .opacity(canRead ? 1 : 0.5)

            Label("メールや画像の内容はこの端末の中だけで読み取ります。どこにも送りません。",
                  systemImage: "lock")
                .font(.system(size: 11))
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 画像の文字を読んで入力欄に入れ、そのまま予約として読み取る。
    /// 読んだ文字を入力欄に見せておくのは、読み違えたときに直せるようにするため
    private func readImage(_ item: PhotosPickerItem) async {
        isReadingImage = true
        imageReadFailed = false
        foundNothing = false
        defer { isReadingImage = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let cgImage = image.cgImage,
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

        let drafts = ReservationEmailParser.parse(text, kind: kind).filter(\.hasContent)
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

        var results = drafts.map { $0.makeReservation(destinationTimeZone: destination) }
        // 往復の航空券などは、メールの金額が全部の合計になっている
        if results.count > 1, results[0].reservation.cost != nil {
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
