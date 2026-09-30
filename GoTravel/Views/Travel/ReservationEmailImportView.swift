import SwiftUI

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
            .navigationTitle("メールから取り込む")
            .navigationBarTitleDisplayMode(.inline)
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
            Text(kind.map { "\($0.label)の予約確認メールの本文を貼り付けてください。" }
                 ?? "予約確認メールの本文を貼り付けてください。")
                + Text("予約番号・日時・金額などを読み取って、入力欄に入れます。")
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

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused($isTextFocused)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(textColor)
                    .font(.system(size: 13))
                    .frame(minHeight: 220)
                    .padding(8)
                if text.isEmpty {
                    Text("ここにメールの本文を貼り付け")
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

            Label("メールの内容はこの端末の中だけで読み取ります。どこにも送りません。",
                  systemImage: "lock")
                .font(.system(size: 11))
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
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
