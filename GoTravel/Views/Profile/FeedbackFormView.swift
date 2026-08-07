import SwiftUI

/// 種別の選択ボタン。
/// 色の出し分けを本体に直接書くと式が複雑になりすぎて型チェックが通らないため切り出す
private struct FeedbackKindButton: View {
    let kind: FeedbackKind
    let isSelected: Bool
    let accent: Color
    let inactive: Color
    let fill: Color
    let action: () -> Void

    private var background: Color {
        isSelected ? accent.opacity(0.18) : fill
    }

    private var border: Color {
        isSelected ? accent : Color.gray.opacity(0.25)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: kind.icon)
                    .font(.system(size: 18))
                Text(kind.label)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(background))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(border, lineWidth: isSelected ? 2 : 1)
            )
            .foregroundColor(isSelected ? accent : inactive)
        }
        .buttonStyle(.plain)
    }
}

/// 要望・不具合をアプリ内から送るフォーム
struct FeedbackFormView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var kind: FeedbackKind = .request
    @State private var message = ""
    @State private var contactEmail = ""
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?

    @FocusState private var messageFocused: Bool

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !trimmedMessage.isEmpty && trimmedMessage.count <= FeedbackService.messageLimit && !isSending
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                if didSend {
                    sentView
                } else {
                    formView
                }
            }
            .navigationTitle(didSend ? "送信しました" : "ご意見・ご要望")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSend ? "閉じる" : "キャンセル") { dismiss() }
                        .foregroundColor(themeManager.currentTheme.primary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { messageFocused = false }
                }
            }
            .alert("送信できませんでした", isPresented: errorBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 入力

    private var formView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                intro
                kindPicker
                messageField
                emailField
                collectedInfoNote
                sendButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var intro: some View {
        Text("いただいたご意見は開発者本人が全て読んでいます。今後のアップデートの参考にさせていただきます。")
            .font(.footnote)
            .foregroundColor(themeManager.currentTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("種類")

            HStack(spacing: 10) {
                ForEach(FeedbackKind.allCases) { item in
                    FeedbackKindButton(
                        kind: item,
                        isSelected: kind == item,
                        accent: themeManager.currentTheme.primary,
                        inactive: themeManager.currentTheme.secondaryText,
                        fill: cardFill
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) { kind = item }
                    }
                }
            }
        }
    }

    private var messageField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("内容")
                Spacer()
                Text("\(trimmedMessage.count) / \(FeedbackService.messageLimit)")
                    .font(.caption2)
                    .foregroundColor(trimmedMessage.count > FeedbackService.messageLimit
                                     ? themeManager.currentTheme.error
                                     : themeManager.currentTheme.secondaryText)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )

                // TextEditor には placeholder が無いので、空のときだけ例文を重ねる
                if message.isEmpty {
                    Text(kind.placeholder)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $message)
                    .focused($messageFocused)
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .frame(minHeight: 190)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("返信先メールアドレス（任意）")

            TextField("example@example.com", text: $contactEmail)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                )

            Text("ご記入いただいた場合のみ、内容によってお返事を差し上げることがあります。空欄のままでも送信できます。")
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var collectedInfoNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.footnote)
                .foregroundColor(themeManager.currentTheme.secondaryText)

            // 何が送られるかを隠さない。不具合の切り分けに必要なので同意のうえ送ってもらう
            Text("不具合の原因を調べるため、アプリのバージョン（\(FeedbackService.appVersion)）、iOSのバージョン、機種名が一緒に送信されます。氏名や位置情報、写真は送信されません。")
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardFill)
        )
    }

    private var sendButton: some View {
        Button(action: send) {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSending ? "送信中..." : "送信する")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeManager.currentTheme.actionFill)
            )
            .foregroundColor(.white)
            .opacity(canSend ? 1 : 0.5)
        }
        .disabled(!canSend)
    }

    // MARK: - 送信後

    private var sentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 56))
                .foregroundColor(themeManager.currentTheme.success)

            Text("ありがとうございます")
                .font(.title3.bold())
                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

            // 送りっぱなしで音沙汰が無いと二度目は送ってもらえないので、
            // どう扱われるのかをここで伝える
            Text("いただいた内容は開発者が確認し、今後のアップデートに反映していきます。\n\n個別のお返事は難しい場合がありますが、対応した内容はアップデートのお知らせでご紹介しています。")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                dismiss()
            } label: {
                Text("閉じる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeManager.currentTheme.actionFill)
                    )
                    .foregroundColor(.white)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 部品

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.bold())
            .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark] :
                [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: - 動作

    private func send() {
        messageFocused = false
        isSending = true

        Task {
            do {
                try await FeedbackService.shared.submit(
                    kind: kind,
                    message: message,
                    contactEmail: contactEmail
                )
                isSending = false
                withAnimation { didSend = true }
            } catch {
                isSending = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
