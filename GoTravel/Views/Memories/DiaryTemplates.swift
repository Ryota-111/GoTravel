import SwiftUI

// MARK: - 旅行日記のページ（3.8）
//
// 1日を1ページに。見出しに「Day 1」と日付、その日のひとこと。
// 写真と一言を、時刻の順に4つまで並べる（`DiaryPage.entries`）

enum DiaryFormat {
    static let maxEntries = 4

    static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd (EEE)"
        return formatter.string(from: date)
    }

    static func timeText(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }
}

/// 編集中は打ち込める欄、書き出すときは文字（3.8。日記を、そのページの上で直せるように）
struct DiaryInlineText: View {
    let text: Binding<String>?
    let value: String
    let placeholder: String
    let font: Font
    var lineLimit = 3

    var body: some View {
        if let text {
            TextField(placeholder, text: text, axis: .vertical)
                .font(font)
                .lineLimit(1...lineLimit)
                .foregroundStyle(MemoryColor.ink)
                .tint(MemoryColor.ink)
        } else {
            Text(value)
                .font(font)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.6)
                .foregroundStyle(MemoryColor.ink)
        }
    }
}

/// 日記の写真を押す（写真を選ぶ）・長押し（外す・項目を消す）
struct DiaryPhotoActions: ViewModifier {
    let context: MemoryCanvasContext
    let pageIndex: Int
    let entry: DiaryEntry

    func body(content: Content) -> some View {
        if context.interactive {
            content
                .contentShape(Rectangle())
                .onTapGesture { context.onTapEntryPhoto?(pageIndex, entry.id) }
                .contextMenu {
                    Button { context.onTapEntryPhoto?(pageIndex, entry.id) } label: {
                        Label(entry.photo == nil ? "写真を入れる" : "写真を変える", systemImage: "photo")
                    }
                    if entry.photo != nil {
                        Button { context.onRemoveEntryPhoto?(pageIndex, entry.id) } label: {
                            Label("写真を外す", systemImage: "photo.badge.minus")
                        }
                    }
                    Button(role: .destructive) { context.onDeleteEntry?(pageIndex, entry.id) } label: {
                        Label("この項目を消す", systemImage: "trash")
                    }
                }
        } else {
            content
        }
    }
}

/// スクラップブック：紙の地に、ポラロイドを左右交互に貼る
struct ScrapbookDiaryTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    /// 縦の短い比率（投稿・正方形）では、文字と飾りも縮める（重ならないように。6割まで）
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    let pageIndex: Int

    private var page: DiaryPage? {
        context.project.pages.indices.contains(pageIndex) ? context.project.pages[pageIndex] : nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperBackground()
            if let page {
                header(page)
                entries(page)
                Text("\(context.project.title) ♡")
                    .font(MemoryFont.hand(72 * t, for: context.project.title))
                    .foregroundStyle(MemoryColor.ink)
                    .placedText(x: 0.45, y: 0.94, width: 0.5, in: size, alignment: .trailing, rotation: -8)
            }
        }
    }

    private func header(_ page: DiaryPage) -> some View {
        ZStack(alignment: .topLeading) {
            Text("Day \(page.dayNumber)")
                .font(MemoryFont.hand(120 * t))
                .foregroundStyle(MemoryColor.ink)
                .placedText(x: 0.06, y: 0.055, width: 0.5, in: size, rotation: -4)
            Text(DiaryFormat.dateText(page.date))
                .font(MemoryFont.mono(30 * t))
                .foregroundStyle(MemoryColor.ink)
                .placedText(x: 0.45, y: 0.05, width: 0.5, in: size, alignment: .trailing)
            Image(systemName: "sun.max")
                .font(.system(size: 92 * t, weight: .light))
                .foregroundStyle(MemoryColor.ink)
                .position(x: size.width * 0.86, y: size.height * 0.125)
            DiaryInlineText(text: context.headlineText?(pageIndex), value: page.headline,
                            placeholder: "この日のひとことを書く", font: MemoryFont.japaneseHand(64 * t), lineLimit: 2)
                .placedText(x: 0.07, y: 0.15, width: 0.72, in: size)
        }
    }

    private func entries(_ page: DiaryPage) -> some View {
        let items = Array(page.entries.prefix(DiaryFormat.maxEntries))
        // 写真が横に細長くならないよう、1項目の高さを広く取り、ポラロイドの下の余白を小さくする（4:3 に近く）
        let top: CGFloat = 0.2, bottom: CGFloat = 0.9
        let row = (bottom - top) / CGFloat(max(DiaryFormat.maxEntries, 1))
        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                let left = index.isMultiple(of: 2)
                let y = top + row * CGFloat(index)
                PolaroidPhoto(photo: entry.photo, context: context, border: 14 * t, bottomRatio: 2.2)
                    .allowsHitTesting(false)
                    .modifier(DiaryPhotoActions(context: context, pageIndex: pageIndex, entry: entry))
                    .placed(x: left ? 0.06 : 0.53, y: y + row * 0.01, width: 0.41, height: row * 0.98, in: size,
                            rotation: left ? -3 : 3)
                VStack(alignment: .leading, spacing: 8) {
                    Text(DiaryFormat.timeText(entry.time))
                        .font(MemoryFont.hand(56 * t))
                    DiaryInlineText(text: context.entryText?(pageIndex, entry.id), value: entry.text,
                                    placeholder: "一言を書く", font: MemoryFont.japaneseHand(42 * t))
                    Path { path in
                        path.move(to: .zero)
                        path.addLine(to: CGPoint(x: size.width * 0.36, y: 0))
                    }
                    .stroke(MemoryColor.ink.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                    .frame(height: 2)
                }
                .foregroundStyle(MemoryColor.ink)
                .placedText(x: left ? 0.52 : 0.07, y: y + row * 0.45, width: 0.41, in: size)
            }
        }
    }
}

/// ジャーナル：白い地に、時間の流れを縦の線で示す
struct JournalDiaryTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    /// 縦の短い比率（投稿・正方形）では、文字と飾りも縮める（重ならないように。6割まで）
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    let pageIndex: Int

    private var page: DiaryPage? {
        context.project.pages.indices.contains(pageIndex) ? context.project.pages[pageIndex] : nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.99, green: 0.985, blue: 0.975)
            if let page {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Day \(page.dayNumber)")
                            .font(MemoryFont.serif(96 * t, weight: .semibold))
                        Spacer()
                        Text(DiaryFormat.dateText(page.date))
                            .font(MemoryFont.mono(26 * t))
                    }
                    DiaryInlineText(text: context.headlineText?(pageIndex), value: page.headline,
                                    placeholder: "この日のひとことを書く", font: MemoryFont.sans(44 * t), lineLimit: 2)
                    Rectangle().frame(height: 2)
                }
                .foregroundStyle(MemoryColor.ink)
                .placedText(x: 0.07, y: 0.11, width: 0.86, in: size)

                timeline(page)

                Text(context.project.title.uppercased())
                    .font(MemoryFont.mono(24 * t))
                    .tracking(8)
                    .foregroundStyle(MemoryColor.softInk)
                    .placedText(x: 0.07, y: 0.955, width: 0.86, in: size, alignment: .center)
            }
        }
    }

    private func timeline(_ page: DiaryPage) -> some View {
        let items = Array(page.entries.prefix(DiaryFormat.maxEntries))
        let top: CGFloat = 0.23, bottom: CGFloat = 0.92
        let row = (bottom - top) / CGFloat(max(DiaryFormat.maxEntries, 1))
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(MemoryColor.ink.opacity(0.25))
                .placed(x: 0.105, y: top, width: 0.004, height: row * CGFloat(max(items.count, 1)) - row * 0.2, in: size)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                let y = top + row * CGFloat(index)
                Circle()
                    .fill(MemoryColor.ink)
                    .frame(width: 26 * t, height: 26 * t)
                    .position(x: size.width * 0.107, y: size.height * (y + row * 0.08))
                VStack(alignment: .leading, spacing: 10) {
                    Text(DiaryFormat.timeText(entry.time))
                        .font(MemoryFont.mono(32 * t))
                    DiaryInlineText(text: context.entryText?(pageIndex, entry.id), value: entry.text,
                                    placeholder: "一言を書く", font: MemoryFont.sans(38 * t), lineLimit: 4)
                }
                .foregroundStyle(MemoryColor.ink)
                .placedText(x: 0.15, y: y + row * 0.3, width: 0.4, in: size)
                MemoryPhotoView(photo: entry.photo, context: context)
                    .allowsHitTesting(false)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .modifier(DiaryPhotoActions(context: context, pageIndex: pageIndex, entry: entry))
                    .placed(x: 0.58, y: y + row * 0.03, width: 0.35, height: row * 0.86, in: size)
            }
        }
    }
}
