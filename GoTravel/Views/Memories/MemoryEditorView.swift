import SwiftUI
import UIKit

/// 差し替える写真（sheet(item:) のため）
private struct PhotoSlotTarget: Identifiable { let id: String }

/// 共有シートに渡すもの
struct MemoryShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

/// 写真コラージュ・旅行ポスターを作る画面（3.8）。
///
/// 上に仕上がりを大きく見せ、写真を押すと選ばれる（指でずらす・2本指で広げる）。文字を押すと直せる。
/// 下にテンプレートの見本と、「写真・文字・比率・おまかせ」の道具
struct MemoryEditorView: View {
    @StateObject private var model: MemoryEditorModel
    @ObservedObject private var proStore = ProStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoId: String?
    @State private var dragBase: CGSize?
    @State private var zoomBase: CGFloat?
    @State private var textFocus: MemoryTextField?
    @State private var showsText = false
    @State private var replacing: PhotoSlotTarget?
    @State private var showsPro = false
    @State private var share: MemoryShareItems?
    @State private var toast: String?
    @State private var isExporting = false

    init(plan: TravelPlan, kind: MemoryKind) {
        _model = StateObject(wrappedValue: MemoryEditorModel(plan: plan, kind: kind))
    }

    private var showsWatermark: Bool { !proStore.isPurchased }

    private var editingContext: MemoryCanvasContext {
        MemoryCanvasContext(project: model.project, images: model.images, showsWatermark: showsWatermark,
                            selectedPhotoId: selectedPhotoId, interactive: true,
                            onTapPhoto: { id in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedPhotoId = selectedPhotoId == id ? nil : id
                                }
                            },
                            onTapText: { field in
                                textFocus = field
                                showsText = true
                            })
    }

    var body: some View {
        Group {
            switch model.phase {
            case .loading(let text):
                MemoryLoadingView(text: text)
            case .denied:
                MemoryPermissionView()
            case .ready:
                editor
            }
        }
        .navigationTitle(model.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if model.phase == .ready {
                    Menu {
                        Button { Task { await save() } } label: { Label("写真に保存", systemImage: "square.and.arrow.down") }
                        Button { prepareShare() } label: { Label("送る・投稿する", systemImage: "square.and.arrow.up") }
                    } label: {
                        if isExporting { ProgressView() } else { Text("書き出す").bold() }
                    }
                    .disabled(isExporting)
                }
            }
        }
        .task { await model.start() }
        .sheet(isPresented: $showsText) {
            MemoryTextSheet(project: Binding(get: { model.project }, set: { new in model.update { $0 = new } }),
                            focus: textFocus)
        }
        .sheet(item: $replacing) { target in
            MemoryPhotoPickerSheet(candidates: model.candidates) { assetId, isVideo, date in
                model.replacePhoto(target.id, assetId: assetId, isVideo: isVideo, date: date)
            }
        }
        .sheet(isPresented: $showsPro) { ProSheet(highlighted: nil) }
        .sheet(item: $share) { item in ShareSheet(items: item.items) }
        .overlay(alignment: .top) { toastView }
    }

    // MARK: - 編集

    private var editor: some View {
        VStack(spacing: 0) {
            preview
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 10)

            if selectedPhotoId != nil {
                selectedBar
            } else {
                tools
            }

            MemoryTemplateStrip(kind: model.kind, selectedId: model.project.templateId,
                                context: MemoryCanvasContext(project: model.project, images: model.images,
                                                             showsWatermark: false),
                                isPro: proStore.isPurchased) { template in
                if template.isPro && !proStore.isPurchased {
                    showsPro = true
                } else {
                    selectedPhotoId = nil
                    model.update { $0.templateId = template.id }
                    model.fillPhotos(for: template)
                }
            }
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    /// 仕上がり。選んだ写真は、指でずらす・2本指で広げる
    private var preview: some View {
        GeometryReader { geo in
            let size = model.project.aspect.canvasSize
            let scale = min(geo.size.width / size.width, geo.size.height / size.height)
            ScaledCanvas(size: size) {
                MemoryCanvas(templateId: model.project.templateId, context: editingContext)
            }
            .frame(width: size.width * scale, height: size.height * scale)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            .gesture(dragGesture(scale: scale))
            .simultaneousGesture(zoomGesture)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func dragGesture(scale: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let id = selectedPhotoId, let index = model.project.photos.firstIndex(where: { $0.id == id }) else { return }
                let base = dragBase ?? model.project.photos[index].offset
                if dragBase == nil { dragBase = base }
                let next = CGSize(width: base.width + value.translation.width / max(scale, 0.01),
                                  height: base.height + value.translation.height / max(scale, 0.01))
                model.project.photos[index].offset = next
            }
            .onEnded { _ in
                dragBase = nil
                model.update { _ in }
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard let id = selectedPhotoId, let index = model.project.photos.firstIndex(where: { $0.id == id }) else { return }
                let base = zoomBase ?? model.project.photos[index].scale
                if zoomBase == nil { zoomBase = base }
                model.project.photos[index].scale = min(max(base * value.magnification, 1), 4)
            }
            .onEnded { _ in
                zoomBase = nil
                model.update { _ in }
            }
    }

    private var tools: some View {
        HStack(spacing: 0) {
            MemoryToolButton(title: "文字", systemImage: "textformat") {
                textFocus = .title
                showsText = true
            }
            Menu {
                ForEach(MemoryAspect.allCases) { aspect in
                    Button {
                        model.update { $0.aspect = aspect }
                    } label: {
                        if aspect == model.project.aspect { Label(aspect.label, systemImage: "checkmark") } else { Text(aspect.label) }
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "aspectratio").font(.system(size: 18, weight: .semibold))
                    Text("比率").font(.caption2.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            MemoryToolButton(title: "おまかせ", systemImage: "wand.and.stars") {
                withAnimation(.easeInOut(duration: 0.25)) { model.reshuffle() }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .overlay(alignment: .top) {
            Text("写真を押すと、差し替え・位置の調整ができます。文字を押すと直せます")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .offset(y: -6)
        }
    }

    /// 写真を選んでいるとき
    private var selectedBar: some View {
        HStack(spacing: 0) {
            MemoryToolButton(title: "差し替え", systemImage: "photo.on.rectangle") {
                if let id = selectedPhotoId { replacing = PhotoSlotTarget(id: id) }
            }
            MemoryToolButton(title: "位置を戻す", systemImage: "arrow.counterclockwise") {
                guard let id = selectedPhotoId else { return }
                model.update { project in
                    if let index = project.photos.firstIndex(where: { $0.id == id }) {
                        project.photos[index].offset = .zero
                        project.photos[index].scale = 1
                    }
                }
            }
            MemoryToolButton(title: "完了", systemImage: "checkmark.circle") {
                withAnimation { selectedPhotoId = nil }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .overlay(alignment: .top) {
            Text("指でずらす・2本指で広げると、写真の見える範囲を変えられます")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .offset(y: -6)
        }
    }

    // MARK: - 書き出し

    private func save() async {
        isExporting = true
        selectedPhotoId = nil
        let files = model.renderFiles(showsWatermark: showsWatermark)
        let saved = await TripPhotoLibrary.save(files: files)
        isExporting = false
        show(saved ? "写真に保存しました" : "保存できませんでした。設定で写真への追加を許可してください")
    }

    private func prepareShare() {
        selectedPhotoId = nil
        let files = model.renderFiles(showsWatermark: showsWatermark)
        guard !files.isEmpty else { return }
        share = MemoryShareItems(items: files + ["\(model.project.title) #Travory"])
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func show(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { toast = nil } }
    }
}

/// 写真を読む許可が無いとき
struct MemoryPermissionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("写真へのアクセスが必要です")
                .font(.headline)
            Text("旅行中に撮った写真から作るため、設定でTravoryに写真へのアクセスを許可してください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
