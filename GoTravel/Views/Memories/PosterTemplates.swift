import SwiftUI

// MARK: - 旅行ポスター（3.8）
//
// 写真1枚を主役にする。地名（英字・大文字）、ひとこと、期間・日数、緯度経度を自動で入れる

/// エディトリアル：写真を全面に、上に大きな地名、下の紙の帯に期間と日数
struct EditorialPosterTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    /// 縦の短い比率（投稿・正方形）では、文字と飾りも縮める（重ならないように。6割まで）
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MemoryColor.paper

            MemoryPhotoView(photo: context.photo(0), context: context)
                .placed(x: 0, y: 0, width: 1, height: 0.84, in: size)

            // 上は文字を読めるように明るく、下は紙の帯へなじませる
            LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0)], startPoint: .top, endPoint: .bottom)
                .placed(x: 0, y: 0, width: 1, height: 0.3, in: size)
                .allowsHitTesting(false)
            LinearGradient(colors: [MemoryColor.paper.opacity(0), MemoryColor.paper], startPoint: .top, endPoint: .bottom)
                .placed(x: 0, y: 0.7, width: 1, height: 0.14, in: size)
                .allowsHitTesting(false)

            HStack(spacing: 24) {
                Rectangle().frame(height: 2)
                Text(project.detail)
                    .font(MemoryFont.mono(26 * t))
                    .fixedSize()
                    .memoryEditable(.detail, context)
                Rectangle().frame(height: 2)
            }
            .foregroundStyle(MemoryColor.ink)
            .placedText(x: 0.07, y: 0.045, width: 0.86, in: size, alignment: .center)

            Text(project.title.uppercased())
                .font(MemoryFont.serif(196 * t, weight: .bold, for: project.title))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(MemoryColor.ink)
                .memoryEditable(.title, context)
                .placedText(x: 0.05, y: 0.115, width: 0.9, in: size, alignment: .center)

            Text(project.note)
                .font(MemoryFont.script(96 * t, for: project.note))
                .foregroundStyle(MemoryColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .memoryEditable(.note, context)
                .placedText(x: 0.1, y: 0.18, width: 0.8, in: size, alignment: .center, rotation: -4)

            TravelStamp(top: project.title, bottom: "JAPAN", symbol: "sun.max", color: MemoryColor.ink.opacity(0.85), size: 260 * t)
                .rotationEffect(.degrees(-14))
                .position(x: size.width * 0.8, y: size.height * 0.7)

            VStack(spacing: 26) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRAVEL DATE").font(MemoryFont.mono(22 * t)).tracking(4)
                        Text(project.subtitle)
                            .font(MemoryFont.serif(50 * t, for: project.subtitle))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .memoryEditable(.subtitle, context)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("DURATION").font(MemoryFont.mono(22 * t)).tracking(4)
                        Text(project.badge).font(MemoryFont.serif(50 * t))
                    }
                }
                Rectangle().frame(height: 1.5)
                Text("EXPLORE  ·  EAT  ·  ENJOY")
                    .font(MemoryFont.mono(24 * t))
                    .tracking(8)
            }
            .foregroundStyle(MemoryColor.ink)
            .placedText(x: 0.08, y: 0.915, width: 0.84, in: size, alignment: .center)
        }
    }
}

/// フレーム：白い額に写真、下に地名とひとこと
struct FramePosterTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    /// 縦の短い比率（投稿・正方形）では、文字と飾りも縮める（重ならないように。6割まで）
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.97, green: 0.965, blue: 0.955)

            MemoryPhotoView(photo: context.photo(0), context: context)
                .padding(26)
                .background(Color.white)
                .overlay(Rectangle().stroke(MemoryColor.ink.opacity(0.85), lineWidth: 2))
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 12)
                .placed(x: 0.09, y: 0.08, width: 0.82, height: 0.6, in: size)

            VStack(spacing: 18) {
                Text(project.title.uppercased())
                    .font(MemoryFont.serif(110 * t, weight: .semibold, for: project.title))
                    .tracking(14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .memoryEditable(.title, context)
                Text(project.note)
                    .font(MemoryFont.script(78 * t, for: project.note))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .memoryEditable(.note, context)
                Text(project.subtitle)
                    .font(MemoryFont.mono(28 * t))
                    .tracking(4)
                    .memoryEditable(.subtitle, context)
                Text(project.detail)
                    .font(MemoryFont.mono(22 * t))
                    .foregroundStyle(MemoryColor.softInk)
                    .memoryEditable(.detail, context)
            }
            .foregroundStyle(MemoryColor.ink)
            .placedText(x: 0.08, y: 0.8, width: 0.84, in: size, alignment: .center)
        }
    }
}

/// ヴィンテージ：色を少し落として暖色をかぶせた写真と、大きな地名、3色の帯
struct VintagePosterTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    /// 縦の短い比率（投稿・正方形）では、文字と飾りも縮める（重ならないように。6割まで）
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    private let teal = Color(red: 0.12, green: 0.36, blue: 0.40)
    private let orange = Color(red: 0.89, green: 0.48, blue: 0.22)
    private let cream = Color(red: 0.96, green: 0.90, blue: 0.78)

    var body: some View {
        ZStack(alignment: .topLeading) {
            cream

            MemoryPhotoView(photo: context.photo(0), context: context)
                .saturation(0.72)
                .contrast(1.08)
                .overlay(orange.opacity(0.18).blendMode(.multiply).allowsHitTesting(false))
                .overlay(PaperBackground(base: .clear).opacity(0.6).allowsHitTesting(false))
                .placed(x: 0.06, y: 0.035, width: 0.88, height: 0.64, in: size)

            VStack(spacing: 12) {
                Text("VISIT")
                    .font(MemoryFont.mono(34 * t))
                    .tracking(22)
                    .foregroundStyle(orange)
                Text(project.title.uppercased())
                    .font(MemoryFont.serif(176 * t, weight: .black, for: project.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(teal)
                    .memoryEditable(.title, context)
                Text(project.note)
                    .font(MemoryFont.script(80 * t, for: project.note))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(teal)
                    .memoryEditable(.note, context)
            }
            .placedText(x: 0.06, y: 0.8, width: 0.88, in: size, alignment: .center)

            VStack(spacing: 10) {
                Rectangle().fill(orange).frame(height: 14)
                Rectangle().fill(teal).frame(height: 14)
                Text(project.subtitle)
                    .font(MemoryFont.mono(26 * t))
                    .tracking(6)
                    .foregroundStyle(teal)
                    .padding(.top, 8)
                    .memoryEditable(.subtitle, context)
            }
            .placedText(x: 0.06, y: 0.94, width: 0.88, in: size, alignment: .center)
        }
    }
}

/// マガジン表紙：写真を全面に、上に題字、左下に見出し
struct CoverPosterTemplate: View {
    let context: MemoryCanvasContext
    let size: CGSize
    /// 縦の短い比率（投稿・正方形）では、文字と飾りも縮める（重ならないように。6割まで）
    private var t: CGFloat { max(size.height / 1920, 0.6) }
    private var project: MemoryProject { context.project }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            MemoryPhotoView(photo: context.photo(0), context: context)
                .placed(x: 0, y: 0, width: 1, height: 1, in: size)

            LinearGradient(colors: [Color.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .placed(x: 0, y: 0, width: 1, height: 0.25, in: size)
                .allowsHitTesting(false)
            LinearGradient(colors: [.clear, Color.black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                .placed(x: 0, y: 0.55, width: 1, height: 0.45, in: size)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                Text("TRAVEL ISSUE  ·  \(project.subtitle)")
                    .font(MemoryFont.mono(24 * t))
                    .tracking(6)
                    .memoryEditable(.subtitle, context)
                Text(project.title.uppercased())
                    .font(MemoryFont.serif(220 * t, weight: .black, for: project.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .memoryEditable(.title, context)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 12)
            .placedText(x: 0.05, y: 0.1, width: 0.9, in: size)

            VStack(alignment: .leading, spacing: 18) {
                Text("\(project.badge) IN \(project.title.uppercased())")
                    .font(MemoryFont.serif(64 * t, weight: .bold, for: project.title))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                Text(project.note)
                    .font(MemoryFont.script(84 * t, for: project.note))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .memoryEditable(.note, context)
                Text(project.detail)
                    .font(MemoryFont.mono(24 * t))
                    .opacity(0.85)
                    .memoryEditable(.detail, context)
            }
            .foregroundStyle(.white)
            .placedText(x: 0.07, y: 0.84, width: 0.75, in: size)
        }
    }
}
