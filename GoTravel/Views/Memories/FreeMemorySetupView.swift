import SwiftUI
import PhotosUI

/// 旅行計画なしで思い出を作る（3.8）。名前と、使う写真（期間か、自分で選んだ写真）を決める。
///
/// 見た目は、作るもの（コラージュ・ポスター・日記）と同じ「紙と墨」にそろえる。
/// 画面ぜんたいに紙の地を敷き、見出しは筆記体の英字＋小さな和文、日付は等幅の英数字、名前は手書き風の和文。
/// 上に、選んだ写真を紙に貼ったような見本を出し、決めるたびに変わるようにする（何ができるかが先に分かるように）。
/// 決めたら `FreeMemoryStore` に保存して `onCreate` を呼ぶ。作る画面へ移るのは呼んだ側
struct FreeMemorySetupView: View {
    /// 何を作るか（「写真コラージュ」「旅のダイジェスト」など。ボタンと説明に使う）
    let purpose: String
    let onCreate: (FreeMemory) -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Source: CaseIterable, Identifiable {
        case period, pick
        var id: Self { self }
        var title: String { self == .period ? "期間で選ぶ" : "写真を選ぶ" }
        var english: String { self == .period ? "by dates" : "by photos" }
        var caption: String { self == .period ? "その間に撮った写真から\n自動でえらぶ" : "使いたい写真を\n自分でえらぶ" }
        var icon: String { self == .period ? "calendar" : "photo.on.rectangle.angled" }
    }

    @State private var title = ""
    @State private var place = ""
    @State private var source: Source = .period
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    /// 期間に撮った写真・動画の数、見本の写真、撮った場所
    @State private var period: (count: Int, previewIds: [String], latitude: Double?, longitude: Double?)?
    @State private var pickerItems: [PhotosPickerItem] = []
    /// 選んだ写真の日の範囲と、撮った場所
    @State private var picked: (start: Date, end: Date, latitude: Double?, longitude: Double?)?
    /// 小さく読んだ写真（カメラロールの id ごと）
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var denied = false
    @FocusState private var focused: Bool

    // 紙と墨の色（作るものと同じ）。暗い画面でも紙のまま見せる
    private let ink = MemoryColor.ink
    private let softInk = MemoryColor.softInk
    private let card = Color.white.opacity(0.72)
    /// マスキングテープの色
    private let tape = Color(red: 0.86, green: 0.78, blue: 0.62)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                heading
                preview
                nameFields
                sourceCards
                if source == .period { periodPanel } else { pickPanel }
                if denied { deniedNote }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 28)
            .animation(.snappy(duration: 0.28), value: source)
            .animation(.snappy(duration: 0.28), value: pickedIds)
        }
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(ink)
        .background(PaperBackground().ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { createBar }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
                    .font(MemoryFont.sans(15, weight: .medium))
                    .foregroundStyle(ink)
            }
        }
        .environment(\.colorScheme, .light)
        .task {
            denied = !(await TripPhotoLibrary.authorize())
            refreshPeriod()
        }
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue { endDate = newValue }
            refreshPeriod()
        }
        .onChange(of: endDate) { _, _ in refreshPeriod() }
        .onChange(of: pickerItems) { _, _ in
            let ids = pickedIds
            picked = ids.isEmpty ? nil : FreeMemoryStore.summary(of: ids)
            Task { await loadThumbnails(ids) }
        }
    }

    // MARK: - 上：見出し

    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Make a memory")
                .font(MemoryFont.script(40))
            HStack(spacing: 8) {
                Rectangle().fill(softInk.opacity(0.5)).frame(width: 22, height: 1)
                Text("旅行を選ばずに、自由に\(purpose)を作る")
                    .font(MemoryFont.sans(12, weight: .medium))
                    .foregroundStyle(softInk)
            }
            .padding(.leading, 4)
        }
    }

    // MARK: - 見本（紙に写真を貼ったような）

    /// 見本に出す写真
    private var previewIds: [String] {
        source == .period ? (period?.previewIds ?? []) : pickedIds
    }

    private var preview: some View {
        let ids = Array(spreadForPreview(previewIds).prefix(3))
        return ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(MemoryColor.paper)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
            VStack(spacing: 12) {
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        polaroid(id: index < ids.count ? ids[index] : nil, index: index)
                    }
                }
                .frame(height: 140)
                VStack(spacing: 2) {
                    Text(displayTitle)
                        .font(MemoryFont.script(36, for: displayTitle))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.opacity)
                    Text(previewCaption)
                        .font(MemoryFont.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(softInk)
                        .contentTransition(.numericText())
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        // 上の両端にマスキングテープ
        .overlay(alignment: .topLeading) { tapeStrip.rotationEffect(.degrees(-28)).offset(x: -14, y: 6) }
        .overlay(alignment: .topTrailing) { tapeStrip.rotationEffect(.degrees(28)).offset(x: 14, y: 6) }
        .rotationEffect(.degrees(-0.8))
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: ids)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("見本：\(displayTitle)、\(previewCaption)")
    }

    private var tapeStrip: some View {
        Rectangle()
            .fill(tape.opacity(0.75))
            .frame(width: 64, height: 18)
            .overlay(Rectangle().fill(.white.opacity(0.15)).frame(height: 1), alignment: .top)
    }

    /// 少し傾けた写真1枚。写真が無いところは空き枠
    private func polaroid(id: String?, index: Int) -> some View {
        let angle: Double = [-9, 7, -2][index]
        let offset: CGFloat = [-82, 82, 0][index]
        let lift: CGFloat = [10, 12, -2][index]
        return VStack(spacing: 0) {
            Group {
                if let id, let image = thumbnails[id] {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Rectangle()
                        .fill(MemoryColor.paperShadow.opacity(0.45))
                        .overlay {
                            Image(systemName: index == 2 ? "sparkles" : "photo")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(softInk.opacity(0.5))
                        }
                }
            }
            .frame(width: 96, height: 96)
            .clipped()
            // 下の白いふち（ポラロイドの下の広いところ）。幅を決めないと横いっぱいに広がる
            Color.clear.frame(width: 96, height: 20)
        }
        .padding(6)
        .background(Color.white)
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .rotationEffect(.degrees(angle))
        .offset(x: offset, y: lift)
        .zIndex(index == 2 ? 1 : 0)
    }

    /// 見本には、選んだ写真の最初・最後・真ん中を出す（同じ場面ばかりにならないように）
    private func spreadForPreview(_ ids: [String]) -> [String] {
        guard ids.count > 3 else { return ids }
        return [ids[0], ids[ids.count - 1], ids[ids.count / 2]]
    }

    private var displayTitle: String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let trimmedPlace = place.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPlace.isEmpty { return trimmedPlace }
        return "\(Calendar.current.component(.month, from: rangeStart))月の思い出"
    }

    private var previewCaption: String {
        let range = MemoryBuilder.dateRangeText(start: rangeStart, end: rangeEnd)
        switch source {
        case .period:
            guard let period, period.count > 0 else { return range }
            return "\(range)  ·  \(period.count) PHOTOS"
        case .pick:
            guard !pickedIds.isEmpty else { return "SELECT YOUR PHOTOS" }
            return "\(range)  ·  \(pickedIds.count) PHOTOS"
        }
    }

    private var rangeStart: Date { source == .pick ? (picked?.start ?? startDate) : startDate }
    private var rangeEnd: Date { source == .pick ? (picked?.end ?? endDate) : endDate }

    // MARK: - 名前

    /// 見出し。筆記体の英字に、小さな和文を添える
    private func sectionHeading(_ english: String, _ japanese: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(english)
                .font(MemoryFont.hand(26))
            Text(japanese)
                .font(MemoryFont.sans(11, weight: .medium))
                .foregroundStyle(softInk)
        }
        .padding(.leading, 2)
    }

    private var nameFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Title", "名前と場所")
            VStack(alignment: .leading, spacing: 0) {
                TextField("", text: $title,
                          prompt: Text("例：週末の鎌倉").foregroundStyle(softInk.opacity(0.45)))
                    .font(MemoryFont.japaneseHand(24))
                    .focused($focused)
                    .submitLabel(.done)
                    .padding(.vertical, 12)
                // 罫線（ノートの線のように）
                Rectangle().fill(softInk.opacity(0.25)).frame(height: 1)
                HStack(spacing: 8) {
                    Image(systemName: "mappin")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(softInk)
                    TextField("", text: $place,
                              prompt: Text("場所（なくても大丈夫）").foregroundStyle(softInk.opacity(0.45)))
                        .font(MemoryFont.sans(15))
                        .focused($focused)
                        .submitLabel(.done)
                }
                .padding(.vertical, 12)
                Rectangle().fill(softInk.opacity(0.25)).frame(height: 1)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - どう選ぶか

    private var sourceCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("Photos", "使う写真")
            HStack(spacing: 12) {
                ForEach(Source.allCases) { item in
                    sourceCard(item)
                }
            }
        }
    }

    private func sourceCard(_ item: Source) -> some View {
        let selected = source == item
        let fore = selected ? MemoryColor.paper : ink
        return Button {
            focused = false
            source = item
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .regular))
                        .opacity(selected ? 1 : 0.35)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.english)
                        .font(MemoryFont.hand(20))
                        .opacity(0.75)
                    Text(item.title)
                        .font(.system(size: 15, weight: .bold))
                    Text(item.caption)
                        .font(MemoryFont.sans(10.5))
                        .opacity(0.7)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .foregroundStyle(fore)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? ink : card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ink.opacity(selected ? 0 : 0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(selected ? 0.22 : 0.05), radius: selected ? 10 : 3, y: selected ? 5 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - 期間で選ぶ

    private var periodPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 10) {
                dateChip("FROM", selection: $startDate, range: Date.distantPast...Date())
                Text("—")
                    .font(MemoryFont.mono(14))
                    .foregroundStyle(softInk)
                    .padding(.bottom, 8)
                dateChip("TO", selection: $endDate, range: startDate...max(startDate, Date()))
            }
            if let ids = period?.previewIds, !ids.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                            miniPolaroid(id, angle: index.isMultiple(of: 2) ? -2.5 : 2)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
            }
            statusLine(periodMessage, isProblem: periodProblem)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ink.opacity(0.1), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// 日付1つ。上に等幅の小さな見出し、下に押すと選べる日付
    private func dateChip(_ label: String, selection: Binding<Date>, range: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(MemoryFont.mono(9))
                .tracking(1.5)
                .foregroundStyle(softInk)
            DatePicker(label, selection: selection, in: range, displayedComponents: .date)
                .labelsHidden()
                .tint(ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodDays: Int { FreeMemoryStore.dayCount(from: startDate, to: endDate) }

    private var periodProblem: Bool {
        periodDays > FreeMemory.maxDays || (period?.count ?? 0) == 0
    }

    private var periodMessage: String {
        if periodDays > FreeMemory.maxDays { return "期間は\(FreeMemory.maxDays)日までにしてください" }
        guard let period else { return "写真を数えています…" }
        if period.count == 0 { return "この期間に撮った写真がありません" }
        return "\(periodDays)日間に撮った \(period.count)枚から、よく撮れたものを選びます"
    }

    private func refreshPeriod() {
        guard !denied else { return }
        let found = FreeMemoryStore.photos(from: startDate, to: endDate)
        period = found
        Task { await loadThumbnails(found.previewIds) }
    }

    // MARK: - 写真を選ぶ

    private var pickedIds: [String] { pickerItems.compactMap(\.itemIdentifier) }

    @ViewBuilder
    private var pickPanel: some View {
        if pickedIds.isEmpty {
            emptyPicker
        } else {
            pickedGrid
        }
    }

    /// まだ選んでいないとき。点線の枠を押すと、写真の選択が開く
    private var emptyPicker: some View {
        photosPicker {
            VStack(spacing: 8) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 30, weight: .light))
                    .padding(.bottom, 4)
                Text("Choose photos")
                    .font(MemoryFont.script(32))
                Text("写真を選ぶ")
                    .font(.system(size: 14, weight: .bold))
                Text("100枚まで・撮った日が\(FreeMemory.maxDays)日以内のもの")
                    .font(MemoryFont.sans(11))
                    .foregroundStyle(softInk)
            }
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(card))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// 選んだ写真を、白いふちの写真として3列で並べる。最初のマスで足す。右上の × で外す
    private var pickedGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                statusLine(pickedMessage, isProblem: pickedProblem)
                Spacer(minLength: 8)
                Button("すべて外す") { pickerItems.removeAll() }
                    .font(MemoryFont.sans(11, weight: .medium))
                    .foregroundStyle(softInk)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                photosPicker {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                        .aspectRatio(0.84, contentMode: .fit)
                        .overlay {
                            VStack(spacing: 2) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .light))
                                Text("add")
                                    .font(MemoryFont.hand(18))
                            }
                            .foregroundStyle(ink)
                        }
                }
                ForEach(Array(pickedIds.enumerated()), id: \.element) { index, id in
                    pickedTile(id, angle: [-2.0, 1.5, -1.0, 2.0][index % 4])
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ink.opacity(0.1), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// 選んだ写真1枚。白いふちで少し傾け、右上に外す印
    private func pickedTile(_ id: String, angle: Double) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { thumbnailImage(id) }
                .clipped()
            Color.clear.frame(height: 12)
        }
        .padding(4)
        .background(Color.white)
        .shadow(color: .black.opacity(0.16), radius: 3, y: 1.5)
        .rotationEffect(.degrees(angle))
        .overlay(alignment: .topTrailing) {
            Button {
                pickerItems.removeAll { $0.itemIdentifier == id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(MemoryColor.paper)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(ink))
                    .offset(x: 6, y: -6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("この写真を外す")
        }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private func photosPicker<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        PhotosPicker(selection: $pickerItems, maxSelectionCount: 100, selectionBehavior: .ordered,
                     matching: .any(of: [.images, .videos]), photoLibrary: .shared(), label: label)
            .buttonStyle(.plain)
    }

    private var pickedDays: Int {
        guard let picked else { return 0 }
        return FreeMemoryStore.dayCount(from: picked.start, to: picked.end)
    }

    private var pickedProblem: Bool { picked == nil || pickedDays > FreeMemory.maxDays }

    private var pickedMessage: String {
        guard picked != nil else { return "写真を読めませんでした。もう一度選んでください" }
        if pickedDays > FreeMemory.maxDays { return "撮った日が\(FreeMemory.maxDays)日に収まるように選んでください" }
        return "\(pickedIds.count)枚・\(pickedDays)日間"
    }

    // MARK: - 写真の小さな絵

    /// 期間の写真の見本1枚（小さな白いふちの写真）
    private func miniPolaroid(_ id: String, angle: Double) -> some View {
        VStack(spacing: 0) {
            thumbnailImage(id)
                .frame(width: 56, height: 56)
                .clipped()
            Color.clear.frame(width: 56, height: 8)
        }
        .padding(3)
        .background(Color.white)
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        .rotationEffect(.degrees(angle))
    }

    @ViewBuilder
    private func thumbnailImage(_ id: String) -> some View {
        if let image = thumbnails[id] {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Rectangle().fill(MemoryColor.paperShadow.opacity(0.5))
        }
    }

    private func loadThumbnails(_ ids: [String]) async {
        for id in ids where thumbnails[id] == nil {
            if let image = await TripPhotoLibrary.image(assetId: id, maxPixel: 300) {
                thumbnails[id] = image
            }
        }
    }

    // MARK: - そのほか

    private func statusLine(_ text: String, isProblem: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: isProblem ? "exclamationmark.circle" : "checkmark")
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(MemoryFont.sans(11.5, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(isProblem ? Color(red: 0.78, green: 0.38, blue: 0.2) : softInk)
    }

    private var deniedNote: some View {
        Label("写真へのアクセスが許可されていません。設定アプリの「Travory」→「写真」で許可すると作れます。",
              systemImage: "lock")
            .font(MemoryFont.sans(12))
            .foregroundStyle(softInk)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(card))
    }

    // MARK: - 下：作る

    private var createBar: some View {
        Button { create() } label: {
            HStack(spacing: 10) {
                Text("\(purpose)を作る")
                    .font(.system(size: 16, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(MemoryColor.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Capsule().fill(canCreate ? ink : ink.opacity(0.25)))
            .shadow(color: .black.opacity(canCreate ? 0.25 : 0), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!canCreate)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(
            LinearGradient(colors: [MemoryColor.paper.opacity(0), MemoryColor.paper.opacity(0.95), MemoryColor.paper],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .animation(.easeInOut(duration: 0.2), value: canCreate)
    }

    private var canCreate: Bool {
        guard !denied else { return false }
        switch source {
        case .period: return !periodProblem
        case .pick: return !pickedIds.isEmpty && !pickedProblem
        }
    }

    private func create() {
        let ids = source == .pick ? pickedIds : []
        let latitude = source == .pick ? picked?.latitude : period?.latitude
        let longitude = source == .pick ? picked?.longitude : period?.longitude
        let memory = FreeMemory(id: FreeMemory.idPrefix + UUID().uuidString, title: displayTitle,
                                place: place.trimmingCharacters(in: .whitespacesAndNewlines),
                                startDate: Calendar.current.startOfDay(for: rangeStart),
                                endDate: Calendar.current.startOfDay(for: rangeEnd),
                                assetIds: ids, latitude: latitude, longitude: longitude, createdAt: Date())
        FreeMemoryStore.save(memory)
        onCreate(memory)
    }
}
