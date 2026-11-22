import SwiftUI
import UIKit

// MARK: - 旅の思い出をつくる：テンプレートの共通部品（3.8）
//
// テンプレートは、組み立ての大きさ（幅 1080pt。`MemoryAspect.canvasSize`）で描き、
// 画面では縮めて見せ、書き出すときは2倍の解像度で画像にする（`MemoryRenderer`）。
// 文字の大きさは Dynamic Type に合わせない（書き出す画像の見た目を、人によって変えない）

/// テンプレートが描くときに使うもの
struct MemoryCanvasContext {
    var project: MemoryProject
    /// 写真（カメラロールの id → 読んだ画像）
    var images: [String: UIImage]
    /// 右下に小さく「Travory」と入れる（Pro でないとき）
    var showsWatermark: Bool
    /// 編集中に選んでいる写真（枠を強調する）
    var selectedPhotoId: String? = nil
    /// 編集中か（写真・文字を押せる）
    var interactive = false
    var onTapPhoto: ((String) -> Void)? = nil
    var onTapText: ((MemoryTextField) -> Void)? = nil
    /// 日記：項目・その日のひとことを押したとき
    var onTapEntry: ((String) -> Void)? = nil
    var onTapHeadline: (() -> Void)? = nil

    /// i 番目の写真（足りなければ nil）
    func photo(_ index: Int) -> MemoryPhoto? {
        project.photos.indices.contains(index) ? project.photos[index] : nil
    }
}

/// 押して直せる文字
enum MemoryTextField: String, Identifiable {
    case title, subtitle, note, detail
    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: return "タイトル"
        case .subtitle: return "日付・小さな文字"
        case .note: return "ひとこと"
        case .detail: return "添え書き"
        }
    }
}

// MARK: - 書体

enum MemoryFont {
    /// 筆記体（「Okinawa Trip」）。日本語は書けないので、日本語の文なら手書き風の和文にする
    static func script(_ size: CGFloat, for text: String = "") -> Font {
        hasJapanese(text) ? .custom("Yomogi-Regular", fixedSize: size * 0.62) : .custom("GreatVibes-Regular", fixedSize: size)
    }

    /// 手書きの英字（「Good Memories」）。日本語なら手書き風の和文
    static func hand(_ size: CGFloat, for text: String = "") -> Font {
        hasJapanese(text) ? .custom("Yomogi-Regular", fixedSize: size * 0.82) : .custom("Caveat-Regular", fixedSize: size)
    }

    /// 見出しのセリフ体（「OKINAWA」）。日本語なら明朝
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular, for text: String = "") -> Font {
        hasJapanese(text)
            ? .system(size: size * 0.8, weight: weight, design: .serif)
            : .custom("PlayfairDisplay-Regular", fixedSize: size).weight(weight)
    }

    /// 手書き風の和文（日記の本文）
    static func japaneseHand(_ size: CGFloat) -> Font { .custom("Yomogi-Regular", fixedSize: size) }

    /// 等幅の英数字（日付・緯度経度）
    static func mono(_ size: CGFloat) -> Font { .custom("SpaceMono-Bold", fixedSize: size) }

    /// 本文のゴシック
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("ZenKakuGothicNew-Regular", fixedSize: size).weight(weight)
    }

    static func hasJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
    }
}

// MARK: - 色

enum MemoryColor {
    /// 紙の地
    static let paper = Color(red: 0.965, green: 0.945, blue: 0.91)
    static let paperShadow = Color(red: 0.88, green: 0.85, blue: 0.80)
    /// 紙に書いたような墨色
    static let ink = Color(red: 0.13, green: 0.13, blue: 0.15)
    static let softInk = Color(red: 0.35, green: 0.34, blue: 0.33)
    static let stamp = Color(red: 0.30, green: 0.33, blue: 0.40)
}

// MARK: - 紙の地

/// 少しざらついた紙。粒は決まった並びで描く（書き出すたびに模様が変わらないように）。
/// 粒の模様は1枚の画像として一度だけ作り、並べて敷く（描き直しのたびに数千の粒を打ち直すと、編集の反応が遅くなるため）
struct PaperBackground: View {
    var base: Color = MemoryColor.paper

    var body: some View {
        ZStack {
            base
            Image(uiImage: Self.grainTile)
                .resizable(resizingMode: .tile)
            RadialGradient(colors: [.clear, MemoryColor.paperShadow.opacity(0.35)],
                           center: .center, startRadius: 300, endRadius: 1300)
        }
    }

    /// 紙の粒の模様（540 × 540。並べて敷く）
    static let grainTile: UIImage = {
        let side: CGFloat = 540
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            var generator = SeededRandom(seed: 7)
            for _ in 0..<Int(side * side / 900) {
                let x = CGFloat(generator.next()) * side
                let y = CGFloat(generator.next()) * side
                let r = CGFloat(generator.next()) * 1.6 + 0.4
                let dark = generator.next() > 0.5
                (dark ? UIColor.black : UIColor.white).withAlphaComponent(0.05).setFill()
                context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
    }()
}

/// 決まった並びの乱数（紙の粒・飾りの傾きを、毎回同じにする）
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

// MARK: - 写真の枠

/// 枠に写真を敷く。枠いっぱいに切り抜き、自分でずらした・広げた分を反映する（枠からはみ出さない範囲で）
struct MemoryPhotoView: View {
    let photo: MemoryPhoto?
    let context: MemoryCanvasContext
    var placeholder: Color = Color.black.opacity(0.08)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let photo, let image = context.images[photo.assetId] {
                    let fill = max(geo.size.width / max(image.size.width, 1),
                                   geo.size.height / max(image.size.height, 1)) * max(photo.scale, 1)
                    let width = image.size.width * fill
                    let height = image.size.height * fill
                    let maxX = max((width - geo.size.width) / 2, 0)
                    let maxY = max((height - geo.size.height) / 2, 0)
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: width, height: height)
                        .offset(x: min(max(photo.offset.width, -maxX), maxX),
                                y: min(max(photo.offset.height, -maxY), maxY))
                    if photo.isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: min(geo.size.width, geo.size.height) * 0.22))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 6)
                    }
                } else {
                    placeholder
                    Image(systemName: "photo")
                        .font(.system(size: min(geo.size.width, geo.size.height) * 0.2))
                        .foregroundStyle(Color.black.opacity(0.2))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .overlay {
            if context.interactive, let photo, photo.id == context.selectedPhotoId {
                Rectangle().stroke(Color.accentColor, lineWidth: 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if context.interactive, let photo { context.onTapPhoto?(photo.id) }
        }
    }
}

/// 押すと直せる文字（編集中だけ）
struct MemoryEditableText: ViewModifier {
    let field: MemoryTextField
    let context: MemoryCanvasContext

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { if context.interactive { context.onTapText?(field) } }
    }
}

extension View {
    func memoryEditable(_ field: MemoryTextField, _ context: MemoryCanvasContext) -> some View {
        modifier(MemoryEditableText(field: field, context: context))
    }
}

// MARK: - 飾り

/// ポラロイド写真（白い縁、下だけ広い）
struct PolaroidPhoto: View {
    let photo: MemoryPhoto?
    let context: MemoryCanvasContext
    var border: CGFloat = 22
    /// 下の余白（縁の何倍か）。日記のように写真を大きく見せたいところでは小さくする
    var bottomRatio: CGFloat = 3.2

    var body: some View {
        MemoryPhotoView(photo: photo, context: context)
            .padding(.horizontal, border)
            .padding(.top, border)
            .padding(.bottom, border * bottomRatio)
            .background(Color(white: 0.985))
            .shadow(color: .black.opacity(0.22), radius: 14, x: 4, y: 10)
    }
}

/// マスキングテープ
struct TapeStrip: View {
    var color: Color = Color(red: 0.93, green: 0.86, blue: 0.70)
    var body: some View {
        Rectangle()
            .fill(color.opacity(0.75))
            .frame(width: 150, height: 44)
            .overlay(Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 1))
    }
}

/// 旅のスタンプ（二重の丸に、場所の名前とマーク）
struct TravelStamp: View {
    var top: String
    var bottom: String
    var symbol: String = "airplane"
    var color: Color = MemoryColor.stamp
    var size: CGFloat = 260

    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: size * 0.022)
            Circle().stroke(color, lineWidth: size * 0.01).padding(size * 0.06)
            VStack(spacing: size * 0.03) {
                Text(top.uppercased())
                    .font(MemoryFont.serif(size * 0.12, weight: .bold, for: top))
                    .tracking(size * 0.012)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.22, weight: .regular))
                Text(bottom.uppercased())
                    .font(MemoryFont.mono(size * 0.07))
                    .tracking(size * 0.02)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, size * 0.16)
            .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .opacity(0.82)
    }
}

/// 飛行機と、そこまでの点線
struct FlightPath: View {
    var color: Color = MemoryColor.ink
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 120))
                path.addCurve(to: CGPoint(x: 200, y: 30), control1: CGPoint(x: 40, y: 20), control2: CGPoint(x: 120, y: 150))
            }
            .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [10, 12]))
            Image(systemName: "airplane")
                .font(.system(size: 64, weight: .regular))
                .rotationEffect(.degrees(-20))
                .foregroundStyle(color)
                .offset(x: 50, y: -20)
        }
        .frame(width: 220, height: 150)
    }
}

/// 消印の波線
struct PostmarkWaves: View {
    var color: Color = MemoryColor.stamp
    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { _ in
                Path { path in
                    path.move(to: .zero)
                    for i in 0..<6 {
                        let x = CGFloat(i) * 40
                        path.addQuadCurve(to: CGPoint(x: x + 40, y: 0), control: CGPoint(x: x + 20, y: i.isMultiple(of: 2) ? -12 : 12))
                    }
                }
                .stroke(color.opacity(0.6), lineWidth: 3)
                .frame(width: 240, height: 12)
            }
        }
    }
}

/// 右下の小さな印（Pro でないとき）
struct MemoryWatermark: View {
    var dark = true
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "airplane")
                .rotationEffect(.degrees(-20))
            Text("Travory")
        }
        .font(.system(size: 26, weight: .semibold, design: .rounded))
        .foregroundStyle((dark ? Color.black : Color.white).opacity(0.45))
        .padding(28)
    }
}

// MARK: - 縮めて見せる

/// 組み立ての大きさで描いたものを、与えられた幅に縮めて見せる
struct ScaledCanvas<Content: View>: View {
    let size: CGSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / size.width, geo.size.height / size.height)
            content()
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
    }
}
