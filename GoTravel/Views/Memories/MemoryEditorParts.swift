import SwiftUI
import PhotosUI

// MARK: - 編集画面の部品（3.8・旅の思い出をつくる）

/// 旅行中の写真から1枚選ぶ。ほかの写真は写真アプリから選べる
struct MemoryPhotoPickerSheet: View {
    let candidates: [TripPhotoCandidate]
    var includesVideos = false
    let onPick: (String, Bool, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?

    private var shown: [TripPhotoCandidate] { candidates.filter { includesVideos || !$0.isVideo } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if shown.isEmpty {
                    Text("この旅行の期間に撮った写真が見つかりませんでした。下の「ほかの写真から選ぶ」から選べます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(24)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                    ForEach(shown) { candidate in
                        Button {
                            onPick(candidate.id, candidate.isVideo, candidate.date)
                            dismiss()
                        } label: {
                            CandidateThumbnail(candidate: candidate)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PhotosPicker(selection: $pickerItem, matching: includesVideos ? .any(of: [.images, .videos]) : .images,
                             photoLibrary: .shared()) {
                    Label("ほかの写真から選ぶ", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("写真を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
            }
            .onChange(of: pickerItem) { _, item in
                guard let id = item?.itemIdentifier else { return }
                let isVideo = item?.supportedContentTypes.contains { $0.conforms(to: .movie) } ?? false
                onPick(id, isVideo, nil)
                dismiss()
            }
        }
    }
}

/// 候補の小さな写真
struct CandidateThumbnail: View {
    let candidate: TripPhotoCandidate
    @State private var image: UIImage?

    var body: some View {
        Color.gray.opacity(0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image { Image(uiImage: image).resizable().scaledToFill() }
            }
            .overlay(alignment: .bottomTrailing) {
                if candidate.isVideo {
                    Image(systemName: "video.fill").font(.caption).foregroundStyle(.white).padding(6).shadow(radius: 3)
                }
            }
            .clipped()
            .task(id: candidate.id) { image = await TripPhotoLibrary.image(assetId: candidate.id, maxPixel: 300) }
    }
}

/// 文字を直す
struct MemoryTextSheet: View {
    @Binding var project: MemoryProject
    var focus: MemoryTextField?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: MemoryTextField?

    var body: some View {
        NavigationStack {
            Form {
                Section(MemoryTextField.title.label) {
                    TextField("例：Okinawa Trip", text: $project.title).focused($focused, equals: .title)
                }
                Section(MemoryTextField.note.label) {
                    TextField("例：Good Memories ♡", text: $project.note).focused($focused, equals: .note)
                }
                Section(MemoryTextField.subtitle.label) {
                    TextField("例：2026.11.15 – 11.17", text: $project.subtitle).focused($focused, equals: .subtitle)
                }
                if project.kind == .poster {
                    Section(MemoryTextField.detail.label) {
                        TextField("例：26.2124° N · 127.6792° E", text: $project.detail).focused($focused, equals: .detail)
                    }
                    Section("日数") {
                        TextField("例：3 DAYS", text: $project.badge)
                    }
                }
                if project.kind == .photoDump {
                    Section("スタンプの文字") {
                        TextField("例：Okinawa", text: $project.detail).focused($focused, equals: .detail)
                        TextField("例：3 DAYS", text: $project.badge)
                    }
                }
            }
            .navigationTitle("文字を直す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } }
            }
            .onAppear { focused = focus }
        }
        .presentationDetents([.medium, .large])
    }
}

/// テンプレートの見本を横に並べる。Pro のものは鍵の印
struct MemoryTemplateStrip: View {
    let kind: MemoryKind
    let selectedId: String
    let context: MemoryCanvasContext
    let isPro: Bool
    let onSelect: (MemoryTemplate) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MemoryTemplate.templates(for: kind)) { template in
                    Button { onSelect(template) } label: {
                        VStack(spacing: 6) {
                            // 見本の中の写真や文字が押した操作を受け取らないようにする（どこを押しても選べるように）
                            ScaledCanvas(size: context.project.aspect.canvasSize) {
                                MemoryCanvas(templateId: template.id, context: context)
                            }
                            .allowsHitTesting(false)
                            .frame(height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(template.id == selectedId ? Color.accentColor : Color.secondary.opacity(0.25),
                                        lineWidth: template.id == selectedId ? 3 : 1))
                            .overlay(alignment: .topTrailing) {
                                if template.isPro && !isPro {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(5)
                                        .background(Circle().fill(Color.orange))
                                        .padding(4)
                                }
                            }
                            Text(template.name)
                                .font(.caption2.weight(template.id == selectedId ? .bold : .regular))
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// 下の道具のボタン
struct MemoryToolButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 18, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

/// 読み込み中・写真が無いときの表示
struct MemoryLoadingView: View {
    let text: String
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(text).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
