import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

// MARK: - 予定の添付（3.5）
//
// 直す画面の「添付」欄と、行程の行に出す添付の札。仕組みは `ScheduleAttachmentStore`

/// 予定を直す（作る）画面の添付の欄。足す・消すはその場で反映する（保存ボタンを待たない）
struct ScheduleAttachmentsEditor: View {
    let itemId: String
    let accent: Color
    let textColor: Color
    let secondaryText: Color
    let fieldBackground: Color

    @ObservedObject private var store = ScheduleAttachmentStore.shared
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showsPhotoPicker = false
    @State private var showsFileImporter = false
    @State private var previewURL: URL?
    @State private var errorText: String?
    @State private var removing: ScheduleAttachment?
    @State private var isAdding = false

    private var attachments: [ScheduleAttachment] { store.attachments(for: itemId) }
    private var remaining: Int { ScheduleAttachmentStore.maxPerItem - attachments.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "paperclip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accent)
                Text("添付（画像・PDF）")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textColor)
                Spacer()
                if isAdding {
                    ProgressView().controlSize(.small)
                }
                Menu {
                    Button("写真から選ぶ", systemImage: "photo.on.rectangle") { showsPhotoPicker = true }
                    Button("ファイルから選ぶ", systemImage: "folder") { showsFileImporter = true }
                } label: {
                    Label("追加", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(remaining > 0 ? accent : secondaryText.opacity(0.5))
                }
                .disabled(remaining <= 0 || isAdding)
            }

            if attachments.isEmpty {
                Text("eチケットや予約の控え、地図のスクリーンショットなどを、この予定に付けておけます")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 6) {
                    ForEach(attachments) { attachment in
                        attachmentRow(attachment)
                    }
                }
            }

            Text("添付は自分にだけ見えます。旅行を共有していても、同行者には送られません")
                .font(.caption2)
                .foregroundColor(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .photosPicker(isPresented: $showsPhotoPicker, selection: $photoSelection,
                      maxSelectionCount: max(remaining, 1), matching: .images)
        .onChange(of: photoSelection) { _, selection in
            guard !selection.isEmpty else { return }
            photoSelection = []
            Task { await addPhotos(selection) }
        }
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.pdf, .image],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): addFiles(urls)
            case .failure: errorText = ScheduleAttachmentStore.AddError.unreadable.errorDescription
            }
        }
        .quickLookPreview($previewURL, in: attachments.map(\.localURL))
        .alert("添付できませんでした", isPresented: Binding(
            get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
        .confirmationDialog("「\(removing?.displayName ?? "")」を外しますか？",
                            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible) {
            Button("外す", role: .destructive) {
                if let removing { store.remove(removing) }
                removing = nil
            }
            Button("キャンセル", role: .cancel) { removing = nil }
        }
    }

    private func attachmentRow(_ attachment: ScheduleAttachment) -> some View {
        HStack(spacing: 10) {
            Button {
                open(attachment)
            } label: {
                HStack(spacing: 10) {
                    AttachmentThumbnail(attachment: attachment, size: 40, tint: accent)
                    Text(attachment.displayName)
                        .font(.subheadline)
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                removing = attachment
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(secondaryText.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(attachment.displayName)を外す"))
        }
        .padding(8)
        .background(fieldBackground)
        .cornerRadius(AppRadius.medium)
    }

    private func open(_ attachment: ScheduleAttachment) {
        if let url = store.openableURL(for: attachment) {
            previewURL = url
        } else {
            errorText = "この添付は、まだこの端末に届いていません。しばらくしてから開いてください"
        }
    }

    private func addPhotos(_ selection: [PhotosPickerItem]) async {
        isAdding = true
        defer { isAdding = false }
        for item in selection {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ScheduleAttachmentStore.AddError.unreadable
                }
                try store.addImage(data, to: itemId)
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription
                    ?? ScheduleAttachmentStore.AddError.unreadable.errorDescription
                return
            }
        }
    }

    private func addFiles(_ urls: [URL]) {
        for url in urls {
            do {
                try store.addFile(at: url, to: itemId)
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription
                    ?? ScheduleAttachmentStore.AddError.unreadable.errorDescription
                return
            }
        }
    }
}

/// 行程の行に出す添付の札。押すとその場で開く（画像・PDF を並べて左右にめくれる）
struct ScheduleAttachmentChips: View {
    let itemId: String
    let tint: Color

    @ObservedObject private var store = ScheduleAttachmentStore.shared
    @State private var previewURL: URL?
    @State private var showsMissing = false

    private var attachments: [ScheduleAttachment] { store.attachments(for: itemId) }

    var body: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(attachments) { attachment in
                        Button {
                            if let url = store.openableURL(for: attachment) {
                                previewURL = url
                            } else {
                                showsMissing = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: attachment.isPDF ? "doc.richtext" : "photo")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(attachment.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: 140, alignment: .leading)
                            }
                            .foregroundColor(tint)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(tint.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("添付 \(attachment.displayName) を開く"))
                    }
                }
            }
            .quickLookPreview($previewURL, in: attachments.map(\.localURL))
            .alert("まだ届いていません", isPresented: $showsMissing) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("この添付は、まだこの端末に届いていません。しばらくしてから開いてください")
            }
        }
    }
}

/// 添付の小さな絵。写真は縮めて出し、PDF は印を出す
private struct AttachmentThumbnail: View {
    let attachment: ScheduleAttachment
    let size: CGFloat
    let tint: Color

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.small).fill(tint.opacity(0.12))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: attachment.isPDF ? "doc.richtext" : "photo")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(tint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
        .task(id: attachment.fileName) {
            guard !attachment.isPDF else { return }
            let path = attachment.localURL.path
            let side = size * 3
            image = await Task.detached(priority: .utility) {
                UIImage(contentsOfFile: path)?.preparingThumbnail(of: CGSize(width: side, height: side))
            }.value
        }
    }
}
