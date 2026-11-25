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
    /// 写真を選んでいる項目
    @State private var choosingPhoto: DiaryEntryTarget?
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

    /// ページの上でそのまま直す（3.8）。文字は打ったそばから保存する
    private func context(page index: Int) -> MemoryCanvasContext {
        var context = MemoryCanvasContext(project: model.project, images: model.images, showsWatermark: showsWatermark,
                                          interactive: true)
        context.headlineText = { page in
            Binding(get: { model.project.pages[safe: page]?.headline ?? "" },
                    set: { value in model.update { if $0.pages.indices.contains(page) { $0.pages[page].headline = value } } })
        }
        context.entryText = { page, id in
            Binding(get: { model.project.pages[safe: page]?.entries.first { $0.id == id }?.text ?? "" },
                    set: { value in
                        model.update { project in
                            guard project.pages.indices.contains(page),
                                  let i = project.pages[page].entries.firstIndex(where: { $0.id == id }) else { return }
                            project.pages[page].entries[i].text = value
                        }
                    })
        }
        context.onTapEntryPhoto = { page, id in
            dismissKeyboard()
            choosingPhoto = DiaryEntryTarget(pageIndex: page, entryId: id)
        }
        context.onRemoveEntryPhoto = { page, id in
            model.update { project in
                guard project.pages.indices.contains(page),
                      let i = project.pages[page].entries.firstIndex(where: { $0.id == id }) else { return }
                project.pages[page].entries[i].photo = nil
            }
        }
        context.onDeleteEntry = { page, id in
            withAnimation {
                model.update { project in
                    guard project.pages.indices.contains(page) else { return }
                    project.pages[page].entries.removeAll { $0.id == id }
                }
            }
        }
        return context
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
        .sheet(item: $choosingPhoto) { target in
            MemoryPhotoPickerSheet(candidates: candidates(onPage: target.pageIndex), includesVideos: true) { assetId, isVideo, date in
                model.update { project in
                    guard project.pages.indices.contains(target.pageIndex),
                          let i = project.pages[target.pageIndex].entries.firstIndex(where: { $0.id == target.entryId })
                    else { return }
                    project.pages[target.pageIndex].entries[i].photo = MemoryPhoto(assetId: assetId, isVideo: isVideo, date: date)
                    if let date { project.pages[target.pageIndex].entries[i].time = date }
                }
                Task { await model.loadImages() }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { dismissKeyboard() }.bold()
            }
        }
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

            Text("一言を押すとそのまま書けます。写真を押すと選び直せ、長押しで外す・消すができます")
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

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
