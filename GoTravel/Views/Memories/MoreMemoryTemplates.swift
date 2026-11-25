import SwiftUI

// MARK: - 足したテンプレート（3.8）
//
// 写真コラージュ：グリッド・チケット・フォトブース・ジャーナル
// 旅行ポスター：ポストカード・文字の切り抜き・スプリット・デュオトーン

// MARK: - 写真コラージュ：グリッド（9枚）

struct GridCollageTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    var body: some View {
        // 正方形の 3×3 を真ん中に置き、題をすぐ上、ひとことをすぐ下に（縦に長い比率で上に寄らないように）
        let side = min(size.width * 0.9, size.height * 0.72)
        let top = (size.height - side) / 2
        return ZStack(alignment: .topLeading) {
            Color.white

            HStack(alignment: .firstTextBaseline) {
                Text(project.title)
                    .font(MemoryFont.serif(64 * t, weight: .semibold, for: project.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .memoryEditable(.title, context)
                Spacer()
                Text(project.subtitle)
                    .font(MemoryFont.mono(24 * t))
                    .memoryEditable(.subtitle, context)
            }
            .foregroundStyle(MemoryColor.ink)
            .frame(width: side)
            .position(x: size.width / 2, y: top - 56 * t)

            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { column in
                            MemoryPhotoView(photo: context.photo(row * 3 + column), context: context)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .position(x: size.width / 2, y: size.height / 2)

            Text(project.note)
                .font(MemoryFont.hand(64 * t, for: project.note))
                .foregroundStyle(MemoryColor.ink)
                .memoryEditable(.note, context)
                .frame(width: side)
                .position(x: size.width / 2, y: top + side + 64 * t)
        }
    }
}

// MARK: - 写真コラージュ：チケット（搭乗券の見出し）

struct TicketCollageTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }
    private let navy = Color(red: 0.11, green: 0.2, blue: 0.36)

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperBackground(base: Color(red: 0.93, green: 0.94, blue: 0.95))

            ticket
                .placed(x: 0.05, y: 0.04, width: 0.9, height: 0.25, in: size)

            MemoryPhotoView(photo: context.photo(0), context: context)
                .clipShape(RoundedRectangle(cornerRadius: 18 * t))
                .placed(x: 0.05, y: 0.31, width: 0.9, height: 0.33, in: size)
            HStack(spacing: 16) {
                ForEach(1..<4, id: \.self) { index in
                    MemoryPhotoView(photo: context.photo(index), context: context)
                        .clipShape(RoundedRectangle(cornerRadius: 14 * t))
                }
            }
            .placed(x: 0.05, y: 0.66, width: 0.9, height: 0.19, in: size)

            Text(project.note)
                .font(MemoryFont.hand(72 * t, for: project.note))
                .foregroundStyle(navy)
                .memoryEditable(.note, context)
                .placedText(x: 0.05, y: 0.92, width: 0.9, in: size, alignment: .center)
        }
    }

    private var ticket: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14 * t) {
                HStack {
                    Image(systemName: "airplane")
                    Text("BOARDING PASS")
                        .tracking(6)
                }
                .font(MemoryFont.mono(24 * t))
                .foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill(navy))

                Text("DESTINATION").font(MemoryFont.mono(18 * t)).foregroundStyle(MemoryColor.softInk)
                Text(project.title.uppercased())
                    .font(MemoryFont.serif(86 * t, weight: .bold, for: project.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .memoryEditable(.title, context)
                HStack(spacing: 40) {
                    field("DATE", project.subtitle, edit: .subtitle)
                    field("DURATION", project.badge, edit: nil)
                }
            }
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity, alignment: .leading)

            // ミシン目
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: 0, y: 1000))
            }
            .stroke(MemoryColor.softInk.opacity(0.5), style: StrokeStyle(lineWidth: 3, dash: [10, 10]))
            .frame(width: 3)

            VStack(spacing: 12 * t) {
                Text("SEAT").font(MemoryFont.mono(18 * t)).foregroundStyle(MemoryColor.softInk)
                Text("01A").font(MemoryFont.serif(56 * t, weight: .bold))
                Image(systemName: "barcode")
                    .font(.system(size: 90 * t))
            }
            .frame(width: size.width * 0.2)
        }
        .foregroundStyle(navy)
        .background(RoundedRectangle(cornerRadius: 28 * t).fill(Color.white))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }

    private func field(_ label: String, _ value: String, edit: MemoryTextField?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(MemoryFont.mono(18 * t)).foregroundStyle(MemoryColor.softInk)
            Text(value)
                .font(MemoryFont.mono(28 * t))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .modifier(OptionalEditable(field: edit, context: context))
        }
    }
}

/// 押して直せる文字（直せない欄もあるとき）
private struct OptionalEditable: ViewModifier {
    let field: MemoryTextField?
    let context: MemoryCanvasContext
    func body(content: Content) -> some View {
        if let field { content.memoryEditable(field, context) } else { content }
    }
}

// MARK: - 写真コラージュ：フォトブース（縦長の帯を2本）

struct PhotoBoothCollageTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperBackground(base: Color(red: 0.98, green: 0.92, blue: 0.9))

            Text(project.title)
                .font(MemoryFont.script(120 * t, for: project.title))
                .foregroundStyle(MemoryColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .memoryEditable(.title, context)
                .placedText(x: 0.05, y: 0.08, width: 0.9, in: size, alignment: .center)

            strip(from: 0)
                .placed(x: 0.1, y: 0.15, width: 0.36, height: 0.72, in: size, rotation: -4)
            strip(from: 3)
                .placed(x: 0.54, y: 0.17, width: 0.36, height: 0.72, in: size, rotation: 3)

            TapeStrip(color: Color(red: 0.98, green: 0.8, blue: 0.82))
                .rotationEffect(.degrees(-8))
                .position(x: size.width * 0.28, y: size.height * 0.155)
            TapeStrip(color: Color(red: 0.8, green: 0.88, blue: 0.96))
                .rotationEffect(.degrees(10))
                .position(x: size.width * 0.72, y: size.height * 0.175)

            HStack {
                Text(project.note)
                    .font(MemoryFont.hand(66 * t, for: project.note))
                    .memoryEditable(.note, context)
                Spacer()
                Text(project.subtitle)
                    .font(MemoryFont.mono(24 * t))
                    .memoryEditable(.subtitle, context)
            }
            .foregroundStyle(MemoryColor.ink)
            .placedText(x: 0.07, y: 0.93, width: 0.86, in: size)
        }
    }

    /// 白い帯に3コマ
    private func strip(from start: Int) -> some View {
        VStack(spacing: 18 * t) {
            ForEach(start..<start + 3, id: \.self) { index in
                MemoryPhotoView(photo: context.photo(index), context: context)
            }
        }
        .padding(24 * t)
        .padding(.bottom, 40 * t)
        .background(Color.white)
        .shadow(color: .black.opacity(0.2), radius: 14, x: 4, y: 10)
    }
}

// MARK: - 写真コラージュ：ジャーナル（手帳に貼った3枚）

struct JournalCollageTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperBackground()
            // 方眼の線
            Canvas { context, canvasSize in
                var path = Path()
                stride(from: CGFloat(0), through: canvasSize.height, by: 60).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                }
                stride(from: CGFloat(0), through: canvasSize.width, by: 60).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                }
                context.stroke(path, with: .color(Color.blue.opacity(0.06)), lineWidth: 1.5)
            }

            Text(project.title)
                .font(MemoryFont.hand(120 * t, for: project.title))
                .foregroundStyle(MemoryColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .memoryEditable(.title, context)
                .placedText(x: 0.06, y: 0.08, width: 0.62, in: size, rotation: -3)
            Text(project.subtitle)
                .font(MemoryFont.mono(26 * t))
                .foregroundStyle(MemoryColor.softInk)
                .memoryEditable(.subtitle, context)
                .placedText(x: 0.07, y: 0.13, width: 0.6, in: size)

            TravelStamp(top: project.detail.isEmpty ? project.title : project.detail, bottom: project.badge,
                        symbol: "airplane", color: Color(red: 0.75, green: 0.3, blue: 0.25), size: 230 * t)
                .rotationEffect(.degrees(12))
                .position(x: size.width * 0.82, y: size.height * 0.1)

            PolaroidPhoto(photo: context.photo(0), context: context)
                .placed(x: 0.08, y: 0.18, width: 0.58, height: 0.3, in: size, rotation: -4)
            PolaroidPhoto(photo: context.photo(1), context: context)
                .placed(x: 0.46, y: 0.42, width: 0.48, height: 0.25, in: size, rotation: 5)
            PolaroidPhoto(photo: context.photo(2), context: context)
                .placed(x: 0.07, y: 0.6, width: 0.5, height: 0.26, in: size, rotation: -2)

            TapeStrip()
                .rotationEffect(.degrees(-25))
                .position(x: size.width * 0.15, y: size.height * 0.185)
            FlightPath()
                .scaleEffect(t)
                .rotationEffect(.degrees(15))
                .position(x: size.width * 0.8, y: size.height * 0.75)

            Text(project.note)
                .font(MemoryFont.hand(72 * t, for: project.note))
                .foregroundStyle(MemoryColor.ink)
                .memoryEditable(.note, context)
                .placedText(x: 0.45, y: 0.92, width: 0.5, in: size, alignment: .trailing, rotation: -5)
        }
    }
}

// MARK: - 旅行ポスター：ポストカード（Greetings from）

struct PostcardPosterTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }
    private let red = Color(red: 0.85, green: 0.27, blue: 0.2)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.97, green: 0.94, blue: 0.87)

            MemoryPhotoView(photo: context.photo(0), context: context)
                .overlay(Color.black.opacity(0.12).allowsHitTesting(false))
                .overlay(Rectangle().stroke(Color.white, lineWidth: 14).allowsHitTesting(false))
                .placed(x: 0.05, y: 0.04, width: 0.9, height: 0.78, in: size)

            VStack(spacing: -10 * t) {
                Text("Greetings from")
                    .font(MemoryFont.script(110 * t))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 8)
                Text(project.title.uppercased())
                    .font(MemoryFont.serif(210 * t, weight: .black, for: project.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .foregroundStyle(.white)
                    .shadow(color: red.opacity(0.9), radius: 0, x: 10 * t, y: 10 * t)
                    .memoryEditable(.title, context)
            }
            .placedText(x: 0.06, y: 0.42, width: 0.88, in: size, alignment: .center, rotation: -4)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.note)
                        .font(MemoryFont.hand(64 * t, for: project.note))
                        .memoryEditable(.note, context)
                    Text(project.subtitle)
                        .font(MemoryFont.mono(26 * t))
                        .memoryEditable(.subtitle, context)
                }
                Spacer()
                // 切手
                VStack(spacing: 6) {
                    Image(systemName: "sun.max.fill").font(.system(size: 60 * t))
                    Text(project.badge).font(MemoryFont.mono(18 * t))
                }
                .foregroundStyle(red)
                .frame(width: 150 * t, height: 170 * t)
                .background(Rectangle().stroke(red, style: StrokeStyle(lineWidth: 4, dash: [6, 6])))
                .rotationEffect(.degrees(4))
            }
            .foregroundStyle(MemoryColor.ink)
            .placedText(x: 0.07, y: 0.91, width: 0.86, in: size)
        }
    }
}

// MARK: - 旅行ポスター：文字の切り抜き（地名の形に写真を切り抜く）

struct TextMaskPosterTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.98, green: 0.975, blue: 0.965)
            // 同じ写真を薄く敷き、文字の両側の空きも写真の雰囲気でつなげる
            MemoryPhotoView(photo: context.photo(0), context: context)
                .opacity(0.16)
                .allowsHitTesting(false)
                .placed(x: 0, y: 0, width: 1, height: 1, in: size)

            Text(project.detail)
                .font(MemoryFont.mono(24 * t))
                .tracking(6)
                .foregroundStyle(MemoryColor.softInk)
                .memoryEditable(.detail, context)
                .placedText(x: 0.05, y: 0.08, width: 0.9, in: size, alignment: .center)

            // 地名を90度回して縦いっぱいに大きく置き、その文字の形に写真を切り抜く（1つの言葉のまま読めるように）
            MemoryPhotoView(photo: context.photo(0), context: context)
                .mask {
                    GeometryReader { geo in
                        Text(project.title.uppercased())
                            .font(MemoryFont.serif(900 * t, weight: .black, for: project.title))
                            .lineLimit(1)
                            .minimumScaleFactor(0.05)
                            .frame(width: geo.size.height, height: geo.size.width)
                            .rotationEffect(.degrees(-90))
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
                .placed(x: 0.03, y: 0.12, width: 0.94, height: 0.7, in: size)

            VStack(spacing: 16) {
                Text(project.note)
                    .font(MemoryFont.script(84 * t, for: project.note))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .memoryEditable(.note, context)
                Text("\(project.subtitle)   ·   \(project.badge)")
                    .font(MemoryFont.mono(26 * t))
                    .tracking(4)
                    .memoryEditable(.subtitle, context)
            }
            .foregroundStyle(MemoryColor.ink)
            .placedText(x: 0.05, y: 0.87, width: 0.9, in: size, alignment: .center)
        }
    }
}

// MARK: - 旅行ポスター：スプリット（上に写真、下は色の面）

struct SplitPosterTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }
    private let block = Color(red: 0.95, green: 0.55, blue: 0.28)

    var body: some View {
        ZStack(alignment: .topLeading) {
            block
            MemoryPhotoView(photo: context.photo(0), context: context)
                .placed(x: 0, y: 0, width: 1, height: 0.58, in: size)

            VStack(alignment: .leading, spacing: 14 * t) {
                Text(project.detail)
                    .font(MemoryFont.mono(24 * t))
                    .tracking(4)
                    .memoryEditable(.detail, context)
                Text(project.title.uppercased())
                    .font(MemoryFont.serif(200 * t, weight: .black, for: project.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .memoryEditable(.title, context)
                Text(project.note)
                    .font(MemoryFont.script(90 * t, for: project.note))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .memoryEditable(.note, context)
                Rectangle().frame(height: 3).padding(.top, 10 * t)
                HStack {
                    Text(project.subtitle)
                        .memoryEditable(.subtitle, context)
                    Spacer()
                    Text(project.badge)
                }
                .font(MemoryFont.mono(28 * t))
            }
            .foregroundStyle(.white)
            .placedText(x: 0.07, y: 0.78, width: 0.86, in: size)
        }
    }
}

// MARK: - 旅行ポスター：デュオトーン（写真を2色に染める）

struct DuotonePosterTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }
    private let dark = Color(red: 0.12, green: 0.1, blue: 0.35)
    private let light = Color(red: 1.0, green: 0.55, blue: 0.55)

    var body: some View {
        ZStack(alignment: .topLeading) {
            dark
            MemoryPhotoView(photo: context.photo(0), context: context)
                .grayscale(1)
                .contrast(1.15)
                .colorMultiply(light)
                .overlay(dark.opacity(0.35).blendMode(.screen).allowsHitTesting(false))
                .placed(x: 0, y: 0, width: 1, height: 1, in: size)

            VStack(spacing: 18 * t) {
                Text(project.detail)
                    .font(MemoryFont.mono(24 * t))
                    .tracking(6)
                    .memoryEditable(.detail, context)
                Text(project.title.uppercased())
                    .font(MemoryFont.serif(200 * t, weight: .bold, for: project.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .memoryEditable(.title, context)
                Text(project.note)
                    .font(MemoryFont.script(90 * t, for: project.note))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .memoryEditable(.note, context)
            }
            .foregroundStyle(.white)
            .shadow(color: dark.opacity(0.4), radius: 14)
            .placedText(x: 0.05, y: 0.45, width: 0.9, in: size, alignment: .center)

            Text("\(project.subtitle)   ·   \(project.badge)")
                .font(MemoryFont.mono(26 * t))
                .tracking(4)
                .foregroundStyle(.white)
                .memoryEditable(.subtitle, context)
                .placedText(x: 0.05, y: 0.93, width: 0.9, in: size, alignment: .center)
        }
    }
}
