import SwiftUI

// MARK: - テンプレートの一覧（3.8）

struct MemoryTemplate: Identifiable, Hashable {
    let id: String
    let kind: MemoryKind
    let name: String
    /// Travory Pro で使えるもの（無料のテンプレートは印つきで書き出せる）
    let isPro: Bool
    /// 使う写真の数
    let photoCount: Int
    /// 地が暗いか（右下の印を白くする）
    var isDark = false

    static let all: [MemoryTemplate] = [
        MemoryTemplate(id: "dump.polaroid", kind: .photoDump, name: "ポラロイド", isPro: false, photoCount: 6),
        MemoryTemplate(id: "dump.film", kind: .photoDump, name: "フィルム", isPro: false, photoCount: 4),
        MemoryTemplate(id: "dump.magazine", kind: .photoDump, name: "マガジン", isPro: true, photoCount: 4),
        MemoryTemplate(id: "dump.minimal", kind: .photoDump, name: "ミニマル", isPro: true, photoCount: 3),
        MemoryTemplate(id: "dump.grid", kind: .photoDump, name: "グリッド", isPro: false, photoCount: 9),
        MemoryTemplate(id: "dump.ticket", kind: .photoDump, name: "チケット", isPro: true, photoCount: 4),
        MemoryTemplate(id: "dump.booth", kind: .photoDump, name: "フォトブース", isPro: true, photoCount: 6),
        MemoryTemplate(id: "dump.journal", kind: .photoDump, name: "ジャーナル", isPro: true, photoCount: 3),
        MemoryTemplate(id: "poster.editorial", kind: .poster, name: "エディトリアル", isPro: false, photoCount: 1),
        MemoryTemplate(id: "poster.frame", kind: .poster, name: "フレーム", isPro: false, photoCount: 1),
        MemoryTemplate(id: "poster.vintage", kind: .poster, name: "ヴィンテージ", isPro: true, photoCount: 1),
        MemoryTemplate(id: "poster.cover", kind: .poster, name: "マガジン表紙", isPro: true, photoCount: 1, isDark: true),
        MemoryTemplate(id: "poster.postcard", kind: .poster, name: "ポストカード", isPro: false, photoCount: 1),
        MemoryTemplate(id: "poster.textmask", kind: .poster, name: "文字の切り抜き", isPro: true, photoCount: 1),
        MemoryTemplate(id: "poster.split", kind: .poster, name: "スプリット", isPro: true, photoCount: 1, isDark: true),
        MemoryTemplate(id: "poster.duotone", kind: .poster, name: "デュオトーン", isPro: true, photoCount: 1, isDark: true),
        MemoryTemplate(id: "diary.scrapbook", kind: .diary, name: "スクラップブック", isPro: false, photoCount: 4),
        MemoryTemplate(id: "diary.journal", kind: .diary, name: "ジャーナル", isPro: true, photoCount: 4),
    ]

    static func templates(for kind: MemoryKind) -> [MemoryTemplate] { all.filter { $0.kind == kind } }
    static func template(id: String) -> MemoryTemplate? { all.first { $0.id == id } }
}

// MARK: - 描き分け

/// テンプレートを1枚描く（組み立ての大きさ）。日記は `pageIndex` のページ
struct MemoryCanvas: View {
    let templateId: String
    let context: MemoryCanvasContext
    var pageIndex = 0

    private var size: CGSize { context.project.aspect.canvasSize }

    var body: some View {
        ZStack {
            switch templateId {
            case "dump.film": FilmDumpTemplate(context: context, size: size)
            case "dump.magazine": MagazineDumpTemplate(context: context, size: size)
            case "dump.minimal": MinimalDumpTemplate(context: context, size: size)
            case "dump.grid": GridCollageTemplate(context: context, size: size)
            case "dump.ticket": TicketCollageTemplate(context: context, size: size)
            case "dump.booth": PhotoBoothCollageTemplate(context: context, size: size)
            case "dump.journal": JournalCollageTemplate(context: context, size: size)
            case "poster.postcard": PostcardPosterTemplate(context: context, size: size)
            case "poster.textmask": TextMaskPosterTemplate(context: context, size: size)
            case "poster.split": SplitPosterTemplate(context: context, size: size)
            case "poster.duotone": DuotonePosterTemplate(context: context, size: size)
            case "poster.editorial": EditorialPosterTemplate(context: context, size: size)
            case "poster.frame": FramePosterTemplate(context: context, size: size)
            case "poster.vintage": VintagePosterTemplate(context: context, size: size)
            case "poster.cover": CoverPosterTemplate(context: context, size: size)
            case "diary.scrapbook": ScrapbookDiaryTemplate(context: context, size: size, pageIndex: pageIndex)
            case "diary.journal": JournalDiaryTemplate(context: context, size: size, pageIndex: pageIndex)
            default: PolaroidDumpTemplate(context: context, size: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay(alignment: .bottomTrailing) {
            if context.showsWatermark {
                MemoryWatermark(dark: !(MemoryTemplate.template(id: templateId)?.isDark ?? false))
            }
        }
        .environment(\.colorScheme, .light)
    }
}

/// 位置を割合で決めて置く（幅は W、縦は H に対する割合）
extension View {
    func placed(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, in size: CGSize, rotation: Double = 0) -> some View {
        let w = size.width * width, h = size.height * height
        return frame(width: w, height: h)
            .rotationEffect(.degrees(rotation))
            .position(x: size.width * x + w / 2, y: size.height * y + h / 2)
    }

    /// 幅だけ決め、左上の位置を割合で置く（高さは中身に合わせる）
    func placedText(x: CGFloat, y: CGFloat, width: CGFloat, in size: CGSize, alignment: Alignment = .leading,
                    rotation: Double = 0) -> some View {
        frame(width: size.width * width, alignment: alignment)
            .rotationEffect(.degrees(rotation))
            .position(x: size.width * (x + width / 2), y: size.height * y)
    }
}

// MARK: - 写真コラージュ：ポラロイド

struct PolaroidDumpTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    /// 縦の短い比率（投稿・正方形）では、文字と飾りも縮める（重ならないように。6割まで）
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    /// (x, y, 幅, 高さ, 傾き)。高さは縁を含む
    private let slots: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
        (0.05, 0.215, 0.52, 0.225, -5), (0.55, 0.175, 0.40, 0.265, 6),
        (0.03, 0.44, 0.45, 0.215, 4), (0.47, 0.425, 0.48, 0.235, -3),
        (0.09, 0.645, 0.53, 0.205, 2), (0.58, 0.665, 0.36, 0.165, -7)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperBackground()

            Text(project.subtitle)
                .font(MemoryFont.mono(30 * t))
                .foregroundStyle(MemoryColor.ink)
                .memoryEditable(.subtitle, context)
                .placedText(x: 0.45, y: 0.05, width: 0.5, in: size, alignment: .trailing)

            Text(project.title)
                .font(MemoryFont.script(150 * t, for: project.title))
                .foregroundStyle(MemoryColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .memoryEditable(.title, context)
                .placedText(x: 0.05, y: 0.12, width: 0.72, in: size, rotation: -7)

            FlightPath()
                .scaleEffect(t)
                .position(x: size.width * 0.82, y: size.height * 0.11)

            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                PolaroidPhoto(photo: context.photo(index), context: context)
                    .placed(x: slot.0, y: slot.1, width: slot.2, height: slot.3, in: size, rotation: slot.4)
            }

            TapeStrip()
                .rotationEffect(.degrees(-30))
                .position(x: size.width * 0.62, y: size.height * 0.18)
            TapeStrip(color: Color(red: 0.78, green: 0.88, blue: 0.86))
                .rotationEffect(.degrees(20))
                .position(x: size.width * 0.14, y: size.height * 0.655)

            Text(project.note)
                .font(MemoryFont.hand(84 * t, for: project.note))
                .foregroundStyle(MemoryColor.ink)
                .memoryEditable(.note, context)
                .placedText(x: 0.05, y: 0.9, width: 0.5, in: size, rotation: -6)

            PostmarkWaves()
                .scaleEffect(t)
                .position(x: size.width * 0.66, y: size.height * 0.86)
            TravelStamp(top: project.detail.isEmpty ? project.title : project.detail, bottom: project.badge, symbol: "sun.max",
                        size: 260 * t)
                .rotationEffect(.degrees(-12))
                .position(x: size.width * 0.8, y: size.height * 0.89)
        }
    }
}

// MARK: - 写真コラージュ：フィルム

struct FilmDumpTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    /// 縦の短い比率（投稿・正方形）では、文字と飾りも縮める（重ならないように。6割まで）
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperBackground(base: Color(red: 0.95, green: 0.93, blue: 0.89))

            VStack(alignment: .leading, spacing: 6) {
                Text(project.title)
                    .font(MemoryFont.serif(104 * t, weight: .semibold, for: project.title))
                    .italic()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .memoryEditable(.title, context)
                Text(project.subtitle)
                    .font(MemoryFont.mono(28 * t))
                    .memoryEditable(.subtitle, context)
            }
            .foregroundStyle(MemoryColor.ink)
            .placedText(x: 0.07, y: 0.085, width: 0.86, in: size)

            filmStrip
                .placed(x: 0.17, y: 0.16, width: 0.66, height: 0.72, in: size, rotation: -4)

            Text(project.note)
                .font(MemoryFont.hand(78 * t, for: project.note))
                .foregroundStyle(MemoryColor.ink)
                .memoryEditable(.note, context)
                .placedText(x: 0.45, y: 0.93, width: 0.5, in: size, alignment: .trailing, rotation: -4)
        }
    }

    private var filmStrip: some View {
        GeometryReader { geo in
            let hole = geo.size.width * 0.06
            HStack(spacing: 0) {
                sprockets(hole: hole, height: geo.size.height)
                VStack(spacing: hole * 0.8) {
                    ForEach(0..<4, id: \.self) { index in
                        MemoryPhotoView(photo: context.photo(index), context: context, placeholder: Color(white: 0.25))
                    }
                }
                .padding(.vertical, hole)
                sprockets(hole: hole, height: geo.size.height)
            }
            .background(Color(red: 0.09, green: 0.09, blue: 0.1))
            .shadow(color: .black.opacity(0.3), radius: 18, x: 6, y: 12)
        }
    }

    private func sprockets(hole: CGFloat, height: CGFloat) -> some View {
        // 大きさが決まる前（幅 0）に割ると無限大になり、整数にするところで落ちる
        let count = hole > 0 && height.isFinite ? max(Int(height / (hole * 1.9)), 0) : 0
        return VStack(spacing: hole * 0.9) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: hole * 0.2)
                    .fill(Color(white: 0.93))
                    .frame(width: hole, height: hole)
            }
        }
        .frame(width: hole * 2.2, height: height)
    }
}

// MARK: - 写真コラージュ：マガジン

struct MagazineDumpTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    /// 縦の短い比率（投稿・正方形）では、文字と飾りも縮める（重ならないように。6割まで）
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.985, green: 0.98, blue: 0.965)

            VStack(spacing: 14) {
                Text("TRAVEL MEMORIES")
                    .font(MemoryFont.mono(24 * t))
                    .tracking(10)
                Text(project.title.uppercased())
                    .font(MemoryFont.serif(116 * t, weight: .regular, for: project.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .memoryEditable(.title, context)
                Rectangle().fill(MemoryColor.ink).frame(height: 2)
            }
            .foregroundStyle(MemoryColor.ink)
            .placedText(x: 0.06, y: 0.08, width: 0.88, in: size, alignment: .center)

            MemoryPhotoView(photo: context.photo(0), context: context)
                .placed(x: 0.06, y: 0.15, width: 0.88, height: 0.39, in: size)

            HStack(spacing: 18) {
                ForEach(1..<4, id: \.self) { index in
                    MemoryPhotoView(photo: context.photo(index), context: context)
                }
            }
            .placed(x: 0.06, y: 0.56, width: 0.88, height: 0.2, in: size)

            VStack(spacing: 18) {
                Text(project.note)
                    .font(MemoryFont.serif(56 * t, for: project.note))
                    .italic()
                    .multilineTextAlignment(.center)
                    .memoryEditable(.note, context)
                HStack {
                    Rectangle().frame(height: 1.5)
                    Text(project.subtitle)
                        .font(MemoryFont.mono(24 * t))
                        .fixedSize()
                        .memoryEditable(.subtitle, context)
                    Rectangle().frame(height: 1.5)
                }
            }
            .foregroundStyle(MemoryColor.ink)
            .placedText(x: 0.08, y: 0.86, width: 0.84, in: size, alignment: .center)
        }
    }
}

// MARK: - 写真コラージュ：ミニマル

struct MinimalDumpTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    /// 縦の短い比率（投稿・正方形）では、文字と飾りも縮める（重ならないように。6割まで）
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.975, green: 0.972, blue: 0.965)

            Text(project.title.uppercased())
                .font(MemoryFont.serif(54 * t, weight: .medium, for: project.title))
                .tracking(18)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(MemoryColor.ink)
                .memoryEditable(.title, context)
                .placedText(x: 0.08, y: 0.07, width: 0.84, in: size, alignment: .center)

            MemoryPhotoView(photo: context.photo(0), context: context)
                .placed(x: 0.08, y: 0.12, width: 0.84, height: 0.47, in: size)
            MemoryPhotoView(photo: context.photo(1), context: context)
                .placed(x: 0.08, y: 0.615, width: 0.405, height: 0.24, in: size)
            MemoryPhotoView(photo: context.photo(2), context: context)
                .placed(x: 0.515, y: 0.615, width: 0.405, height: 0.24, in: size)

            VStack(spacing: 10) {
                Text(project.note)
                    .font(MemoryFont.hand(60 * t, for: project.note))
                    .memoryEditable(.note, context)
                Text(project.subtitle)
                    .font(MemoryFont.mono(24 * t))
                    .tracking(4)
                    .memoryEditable(.subtitle, context)
            }
            .foregroundStyle(MemoryColor.softInk)
            .placedText(x: 0.08, y: 0.92, width: 0.84, in: size, alignment: .center)
        }
    }
}
