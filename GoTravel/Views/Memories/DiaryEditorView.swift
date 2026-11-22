import SwiftUI
import UIKit

/// 直す日記の項目（sheet(item:) のため）
private struct DiaryEntryTarget: Identifiable {
    let pageIndex: Int
    let entryId: String
    var id: String { entryId }
}

private struct DiaryHeadlineTarget: Identifiable {
    let pageIndex: Int
    var id: Int { pageIndex }
}

/// 旅行日記を作る画面（3.8）。1日1ページ。
///
/// 写真と一言は自動で入る。項目を押すと一言・写真を直せ、「＋」で足せる（1ページ4つまで）。
/// 日記は自分だけのもの（同行者には送らない）
struct DiaryEditorView: View {
    @StateObject private var model: MemoryEditorModel
    @ObservedObject private var proStore = ProStore.shared

    @State private var page = 0
    @State private var editingEntry: DiaryEntryTarget?
    @State private var editingHeadline: DiaryHeadlineTarget?
    @State private var addingTo: DiaryHeadlineTarget?
    @State private var showsPro = false
    @State private var confirmsRebuild = false
    @State private var share: MemoryShareItems?
    @State private var toast: String?
    @State private var isExporting = false

    init(plan: TravelPlan) {
        _model = StateObject(wrappedValue: MemoryEditorModel(plan: plan, kind: .diary))
    }

    private var showsWatermark: Bool { !proStore.isPurchased }

    private func context(page index: Int) -> MemoryCanvasContext {
        MemoryCanvasContext(project: model.project, images: model.images, showsWatermark: showsWatermark,
                            interactive: true,
                            onTapEntry: { id in editingEntry = DiaryEntryTarget(pageIndex: index, entryId: id) },
                            onTapHeadline: { editingHeadline = DiaryHeadlineTarget(pageIndex: index) })
    }

    var body: some View {
        Group {
            switch model.phase {
            case .loading(let text): MemoryLoadingView(text: text)
            case .denied: MemoryPermissionView()
            case .ready: editor
            }
        }
        .navigationTitle(model.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if model.phase == .ready {
                    Menu {
                        Button { Task { await save() } } label: {
                            Label("全ページを写真に保存", systemImage: "square.and.arrow.down")
                        }
                        Button { prepareShare() } label: { Label("送る・投稿する", systemImage: "square.and.arrow.up") }
                    } label: {
                        if isExporting { ProgressView() } else { Text("書き出す").bold() }
                    }
                    .disabled(isExporting)
                }
            }
        }
        .task { await model.start() }
        .sheet(item: $editingEntry) { target in entrySheet(target) }
        .sheet(item: $editingHeadline) { target in headlineSheet(target) }
        .sheet(item: $addingTo) { target in
            MemoryPhotoPickerSheet(candidates: candidates(onPage: target.pageIndex), includesVideos: true) { assetId, isVideo, date in
                model.update { project in
                    guard project.pages.indices.contains(target.pageIndex) else { return }
                    let entry = DiaryEntry(time: date, photo: MemoryPhoto(assetId: assetId, isVideo: isVideo, date: date))
                    project.pages[target.pageIndex].entries.append(entry)
                    project.pages[target.pageIndex].entries.sort { ($0.time ?? .distantFuture) < ($1.time ?? .distantFuture) }
                }
                Task { await model.loadImages() }
            }
        }
        .sheet(isPresented: $showsPro) { ProSheet(highlighted: nil) }
        .sheet(item: $share) { item in ShareSheet(items: item.items) }
        .confirmationDialog("写真と一言を選び直しますか？", isPresented: $confirmsRebuild, titleVisibility: .visible) {
            Button("選び直す", role: .destructive) { model.rebuildDiary() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("書いた一言も、自動で入れたものに戻ります")
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(model.project.pages.indices), id: \.self) { index in
                    ScaledCanvas(size: model.project.aspect.canvasSize) {
                        MemoryCanvas(templateId: model.project.templateId, context: context(page: index), pageIndex: index)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Text("項目を押すと、一言や写真を直せます")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            HStack(spacing: 0) {
                MemoryToolButton(title: "項目を足す", systemImage: "plus.square.on.square") {
                    guard model.project.pages.indices.contains(page) else { return }
                    if model.project.pages[page].entries.count >= DiaryFormat.maxEntries {
                        show("1ページに入るのは\(DiaryFormat.maxEntries)つまでです")
                    } else {
                        addingTo = DiaryHeadlineTarget(pageIndex: page)
                    }
                }
                Menu {
                    ForEach(MemoryTemplate.templates(for: .diary)) { template in
                        Button {
                            if template.isPro && !proStore.isPurchased { showsPro = true } else {
                                model.update { $0.templateId = template.id }
                            }
                        } label: {
                            if template.id == model.project.templateId {
                                Label(template.name, systemImage: "checkmark")
                            } else {
                                Text(template.isPro && !proStore.isPurchased ? "\(template.name)（Pro）" : template.name)
                            }
                        }
                    }
                } label: {
                    toolLabel("スタイル", systemImage: "paintpalette")
                }
                Menu {
                    ForEach(MemoryAspect.allCases) { aspect in
                        Button { model.update { $0.aspect = aspect } } label: {
                            if aspect == model.project.aspect { Label(aspect.label, systemImage: "checkmark") } else { Text(aspect.label) }
                        }
                    }
                } label: {
                    toolLabel("比率", systemImage: "aspectratio")
                }
                MemoryToolButton(title: "選び直す", systemImage: "wand.and.stars") { confirmsRebuild = true }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func toolLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 18, weight: .semibold))
            Text(title).font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// そのページの日に撮った写真・動画
    private func candidates(onPage index: Int) -> [TripPhotoCandidate] {
        guard model.project.pages.indices.contains(index) else { return model.candidates }
        let date = model.project.pages[index].date
        let sameDay = model.candidates.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        return sameDay.isEmpty ? model.candidates : sameDay
    }

    // MARK: - 項目を直す

    private func entrySheet(_ target: DiaryEntryTarget) -> some View {
        DiaryEntryEditor(
            entry: model.project.pages[safe: target.pageIndex]?.entries.first { $0.id == target.entryId },
            image: { model.images[$0] },
            candidates: candidates(onPage: target.pageIndex),
            onSave: { entry in
                model.update { project in
                    guard project.pages.indices.contains(target.pageIndex),
                          let i = project.pages[target.pageIndex].entries.firstIndex(where: { $0.id == entry.id }) else { return }
                    project.pages[target.pageIndex].entries[i] = entry
                }
                Task { await model.loadImages() }
            },
            onDelete: {
                model.update { project in
                    guard project.pages.indices.contains(target.pageIndex) else { return }
                    project.pages[target.pageIndex].entries.removeAll { $0.id == target.entryId }
                }
            })
    }

    private func headlineSheet(_ target: DiaryHeadlineTarget) -> some View {
        DiaryHeadlineEditor(text: model.project.pages[safe: target.pageIndex]?.headline ?? "") { text in
            model.update { project in
                guard project.pages.indices.contains(target.pageIndex) else { return }
                project.pages[target.pageIndex].headline = text
            }
        }
    }

    // MARK: - 書き出し

    private func save() async {
        isExporting = true
        let files = model.renderFiles(showsWatermark: showsWatermark)
        let saved = await TripPhotoLibrary.save(files: files)
        isExporting = false
        show(saved ? "\(files.count)ページを写真に保存しました" : "保存できませんでした。設定で写真への追加を許可してください")
    }

    private func prepareShare() {
        let files = model.renderFiles(showsWatermark: showsWatermark)
        guard !files.isEmpty else { return }
        share = MemoryShareItems(items: files + ["\(model.project.title) #Travory"])
    }

    private func show(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { toast = nil } }
    }
}

/// 日記の1項目を直す
private struct DiaryEntryEditor: View {
    @State private var entry: DiaryEntry
    let image: (String) -> UIImage?
    let candidates: [TripPhotoCandidate]
    let onSave: (DiaryEntry) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picking = false

    init(entry: DiaryEntry?, image: @escaping (String) -> UIImage?, candidates: [TripPhotoCandidate],
         onSave: @escaping (DiaryEntry) -> Void, onDelete: @escaping () -> Void) {
        _entry = State(initialValue: entry ?? DiaryEntry())
        self.image = image
        self.candidates = candidates
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("一言") {
                    TextField("例：初めての沖縄そば！", text: $entry.text, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("写真") {
                    if let photo = entry.photo, let img = image(photo.assetId) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(height: 180).frame(maxWidth: .infinity).clipped()
                            .listRowInsets(EdgeInsets())
                    }
                    Button(entry.photo == nil ? "写真を入れる" : "写真を変える") { picking = true }
                    if entry.photo != nil {
                        Button("写真を外す", role: .destructive) { entry.photo = nil }
                    }
                }
                Section {
                    Button("この項目を消す", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle(DiaryFormat.timeText(entry.time).isEmpty ? "項目" : DiaryFormat.timeText(entry.time))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        onSave(entry)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $picking) {
                MemoryPhotoPickerSheet(candidates: candidates, includesVideos: true) { assetId, isVideo, date in
                    entry.photo = MemoryPhoto(assetId: assetId, isVideo: isVideo, date: date)
                    if let date { entry.time = date }
                }
            }
        }
    }
}

/// その日のひとことを書く
private struct DiaryHeadlineEditor: View {
    @State var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("例：はじめての沖縄、最高のスタート！", text: $text, axis: .vertical)
                    .lineLimit(2...3)
                    .focused($focused)
            }
            .navigationTitle("この日のひとこと")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        onSave(text)
                        dismiss()
                    }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
