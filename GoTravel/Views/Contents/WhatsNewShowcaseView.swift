import SwiftUI

/// アップデート後に一度だけ出す、全画面の「こんなことができます」（3.8〜）。
///
/// 文字だけの一覧（`WhatsNewView`）だと読まれずに閉じられやすいので、大きな絵と短い文で1ページずつ見せる。
/// どのバージョンでこれを出すかは `WhatsNew.showcase`。絵はテーマに左右されないよう、Travory の青とオレンジで固定
struct WhatsNewShowcaseView: View {
    let content: WhatsNew
    /// 「思い出をつくってみる」を押したとき（思い出タブを開く）
    var onTryMemories: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var showFeedbackForm = false

    private static let blue = Color(red: 0.16, green: 0.42, blue: 0.95)
    private static let orange = Color(red: 0.98, green: 0.55, blue: 0.22)

    private struct Page: Identifiable {
        let id: Int
        let eyebrow: String
        let title: String
        let body: String
        var hint: String? = nil
    }

    /// 並びの順（id はページの番号。`visual(for:)` で絵を決める）
    private var pages: [Page] {
        [
            Page(id: 0, eyebrow: "NEW",
                 title: "旅の写真が、\n1枚の作品に",
                 body: "旅行中に撮った写真から、写真コラージュ・旅行ポスター・旅行日記をつくれます。よく撮れた写真を選んで並べるので、あとは文字を直すだけ。ストーリーや投稿にそのまま載せられます。",
                 hint: "思い出タブ →「旅の思い出をつくる」"),
            Page(id: 1, eyebrow: "NEW",
                 title: "旅行計画がなくても、\nつくれます",
                 body: "名前と期間を決めるか、使いたい写真を選ぶだけで、思い出の1枚やダイジェスト動画をつくれます。計画を立てずに出かけた旅や、日帰りのおでかけにも。",
                 hint: "思い出タブ →「自由に作る」"),
            Page(id: 2, eyebrow: "かんたん",
                 title: "右下の＋から、\nすぐ作れます",
                 body: "思い出タブの＋から、写真コラージュ・ポスター・日記・ダイジェスト・アルバムを選べます。場所保存の＋も同じ形になりました。"),
            Page(id: 3, eyebrow: "無料",
                 title: "みんなの写真が、\n1つのアルバムに",
                 body: "共有した旅行のアルバムで「共有する」を押すと、同行者が撮った写真も同じアルバムに集まります。旅行のあとに写真を送り合わなくて大丈夫です。",
                 hint: "共有した旅行のアルバムを開く"),
            Page(id: 4, eyebrow: "かんたん",
                 title: "リンクを送るだけで、\n旅行に招待",
                 body: "旅行の共有画面から招待を送ると、相手は届いたリンクを押すだけで参加の画面が開きます。コードを打ち込む必要はありません。",
                 hint: "旅行計画 → 共有"),
            Page(id: 5, eyebrow: "旅のあとも",
                 title: "旅が終わっても、\nまた楽しめる",
                 body: "旅行の次の日の夜に、旅のダイジェスト動画のお知らせが届きます。12月からは、その年の旅をまとめてふり返れます。"),
            Page(id: 6, eyebrow: "見やすく",
                 title: "飛行機や新幹線も、\n「移動」の形で",
                 body: "予約から行程に入れた乗り物を、「東京 → 新大阪」の移動1件で出せるようになりました。出発と到着の2件にしたときも、間に乗り物と乗っている時間が出ます。",
                 hint: "予約の「行程にも追加する」で選べます"),
            Page(id: 7, eyebrow: "もっと正確に",
                 title: "予約の読み取りを\n見直しました",
                 body: "往復や乗り継ぎの航空券、バス・船の予約も読めるようになりました。違う値を入れないよう、自信のない項目は空けておきます。"),
        ]
    }

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.93, green: 0.96, blue: 1.0), .white],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Version \(content.version) の新機能")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Self.blue)
                    Spacer()
                    if !isLast {
                        Button("スキップ") { dismiss() }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .frame(height: 44)

                TabView(selection: $page) {
                    ForEach(pages) { item in
                        pageView(item).tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
        }
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $showFeedbackForm) { FeedbackFormView() }
    }

    // MARK: - ページ

    private func pageView(_ item: Page) -> some View {
        VStack(spacing: 0) {
            visual(for: item.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 10) {
                Text(item.eyebrow)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Self.orange))
                Text(item.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(red: 0.07, green: 0.09, blue: 0.14))
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.3, green: 0.33, blue: 0.4))
                    .fixedSize(horizontal: false, vertical: true)
                if let hint = item.hint {
                    Label(hint, systemImage: "hand.tap.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Self.blue)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func visual(for id: Int) -> some View {
        switch id {
        case 0: ShowcaseMemoriesVisual()
        case 1: ShowcaseFreeMemoryVisual()
        case 2: ShowcaseAddMenuVisual()
        case 3: ShowcaseSharedAlbumVisual(blue: Self.blue, orange: Self.orange)
        case 4: ShowcaseInviteVisual(blue: Self.blue, orange: Self.orange)
        case 5: ShowcaseAfterTripVisual(blue: Self.blue, orange: Self.orange)
        case 6: ShowcaseMoveVisual(blue: Self.blue, orange: Self.orange)
        default: ShowcaseReadingVisual(blue: Self.blue, orange: Self.orange)
        }
    }

    // MARK: - 下のボタン

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(pages) { item in
                    Capsule()
                        .fill(item.id == page ? Self.blue : Self.blue.opacity(0.2))
                        .frame(width: item.id == page ? 22 : 7, height: 7)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)

            if isLast {
                Button {
                    onTryMemories()
                    dismiss()
                } label: {
                    Label("思い出をつくってみる", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Self.orange))
                }
                HStack(spacing: 20) {
                    Button("はじめる") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Self.blue)
                    Button("ご意見・ご要望を送る") { showFeedbackForm = true }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text("次へ")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Self.blue))
                }
                // 最後のページと高さをそろえる（ボタンの位置が跳ねないように）
                Text(" ").font(.subheadline)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

// MARK: - 絵：旅の思い出をつくる（本物のテンプレートを、見本の写真で描く）

private struct ShowcaseMemoriesVisual: View {
    @State private var collage: UIImage?
    @State private var poster: UIImage?
    @State private var diary: UIImage?

    var body: some View {
        GeometryReader { geo in
            let h = min(geo.size.height * 0.92, geo.size.width * 0.95)
            let w = h * 1080 / 1920
            ZStack {
                card(diary).frame(width: w * 0.82, height: h * 0.82)
                    .rotationEffect(.degrees(9)).offset(x: w * 0.62, y: h * 0.04)
                card(poster).frame(width: w * 0.82, height: h * 0.82)
                    .rotationEffect(.degrees(-9)).offset(x: -w * 0.62, y: h * 0.04)
                card(collage).frame(width: w, height: h)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task { render() }
    }

    private func card(_ image: UIImage?) -> some View {
        ZStack {
            Color.white
            if let image { Image(uiImage: image).resizable().scaledToFill() }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }

    @MainActor
    private func render() {
        guard collage == nil else { return }
        let (images, photos) = ShowcaseSamplePhotos.make(count: 6)
        var base = MemoryProject(planId: "showcase", kind: .photoDump, templateId: "", aspect: .story)
        base.photos = photos
        base.subtitle = "2026.11.15 – 11.17"
        base.badge = "3 DAYS"

        var dump = base
        dump.title = "Okinawa Trip"; dump.note = "Good Memories ♡"; dump.detail = "Okinawa"
        collage = draw("dump.polaroid", dump, images)

        var posterProject = base
        posterProject.kind = .poster
        posterProject.title = "Okinawa"; posterProject.note = "A Journey to Remember"
        posterProject.detail = "26.2124° N  ·  127.6792° E"
        poster = draw("poster.editorial", posterProject, images)

        var diaryProject = base
        diaryProject.kind = .diary
        diaryProject.title = "Okinawa Trip"
        let start = Date()
        diaryProject.pages = [DiaryPage(dayNumber: 1, date: start, headline: "はじめての沖縄、最高のスタート！", entries: [
            DiaryEntry(time: start, text: "初めての沖縄そば！", photo: photos[0]),
            DiaryEntry(time: start.addingTimeInterval(9000), text: "海が綺麗すぎた…", photo: photos[1]),
            DiaryEntry(time: start.addingTimeInterval(18000), text: "寄り道したカフェ", photo: photos[2]),
            DiaryEntry(time: start.addingTimeInterval(27000), text: "夕日を見ながらドライブ", photo: photos[3]),
        ])]
        diary = draw("diary.scrapbook", diaryProject, images)
    }

    @MainActor
    private func draw(_ templateId: String, _ project: MemoryProject, _ images: [String: UIImage]) -> UIImage? {
        var project = project
        project.templateId = templateId
        let context = MemoryCanvasContext(project: project, images: images, showsWatermark: false)
        let renderer = ImageRenderer(content: MemoryCanvas(templateId: templateId, context: context))
        renderer.scale = 0.5
        return renderer.uiImage
    }
}

/// 見本の写真（空・夕焼け・緑の色の重なり）。本物の写真は入れない
enum ShowcaseSamplePhotos {
    static func make(count: Int) -> ([String: UIImage], [MemoryPhoto]) {
        let palettes: [[UIColor]] = [
            [UIColor(red: 0.45, green: 0.75, blue: 0.98, alpha: 1), UIColor(red: 0.1, green: 0.65, blue: 0.75, alpha: 1), UIColor(red: 0.95, green: 0.9, blue: 0.75, alpha: 1)],
            [UIColor(red: 0.98, green: 0.6, blue: 0.3, alpha: 1), UIColor(red: 0.85, green: 0.3, blue: 0.4, alpha: 1), UIColor(red: 0.2, green: 0.15, blue: 0.3, alpha: 1)],
            [UIColor(red: 0.6, green: 0.85, blue: 0.95, alpha: 1), UIColor(red: 0.2, green: 0.55, blue: 0.3, alpha: 1), UIColor(red: 0.85, green: 0.8, blue: 0.6, alpha: 1)],
        ]
        var images: [String: UIImage] = [:]
        var photos: [MemoryPhoto] = []
        for i in 0..<count {
            let colors = palettes[i % palettes.count]
            let size = CGSize(width: 600, height: i % 2 == 0 ? 450 : 750)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            images["showcase\(i)"] = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: colors.map(\.cgColor) as CFArray, locations: [0, 0.6, 1]) {
                    ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                }
                UIColor.white.withAlphaComponent(0.6).setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: size.width * 0.65, y: size.height * 0.12, width: 80, height: 80))
            }
            photos.append(MemoryPhoto(assetId: "showcase\(i)", date: Date()))
        }
        return (images, photos)
    }

    /// 色の重なりの絵（SwiftUI。アルバムなどの小さな絵に）
    static func gradient(_ index: Int) -> LinearGradient {
        let sets: [[Color]] = [
            [Color(red: 0.45, green: 0.75, blue: 0.98), Color(red: 0.1, green: 0.65, blue: 0.75)],
            [Color(red: 0.98, green: 0.6, blue: 0.3), Color(red: 0.85, green: 0.3, blue: 0.4)],
            [Color(red: 0.6, green: 0.85, blue: 0.95), Color(red: 0.2, green: 0.55, blue: 0.3)],
            [Color(red: 0.98, green: 0.8, blue: 0.5), Color(red: 0.95, green: 0.5, blue: 0.35)],
            [Color(red: 0.55, green: 0.5, blue: 0.95), Color(red: 0.25, green: 0.3, blue: 0.7)],
            [Color(red: 0.4, green: 0.85, blue: 0.75), Color(red: 0.1, green: 0.5, blue: 0.6)],
        ]
        let colors = sets[index % sets.count]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - 絵：同行者と写真を見せ合う

private struct ShowcaseSharedAlbumVisual: View {
    let blue: Color
    let orange: Color

    private let people: [(String, Color)] = [
        ("R", Color(red: 0.16, green: 0.42, blue: 0.95)),
        ("A", Color(red: 0.98, green: 0.55, blue: 0.22)),
        ("K", Color(red: 0.2, green: 0.7, blue: 0.5)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("沖縄 3泊4日").font(.headline)
                    Text("3人の写真 · 42枚").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: -8) {
                    ForEach(people.indices, id: \.self) { i in avatar(i, size: 30) }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(0..<9, id: \.self) { i in
                    ShowcaseSamplePhotos.gradient(i)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .bottomTrailing) { avatar(i % 3, size: 20).padding(5) }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white).shadow(color: .black.opacity(0.1), radius: 16, y: 8))
        .frame(maxWidth: 340)
        .frame(maxHeight: .infinity)
    }

    private func avatar(_ index: Int, size: CGFloat) -> some View {
        Text(people[index].0)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(people[index].1))
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }
}

// MARK: - 絵：招待のリンク

private struct ShowcaseInviteVisual: View {
    let blue: Color
    let orange: Color

    var body: some View {
        VStack(spacing: 18) {
            // 届いたメッセージ
            VStack(alignment: .leading, spacing: 8) {
                Text("「沖縄 3泊4日」の旅行計画に招待します！")
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "airplane").foregroundStyle(blue)
                        Text("Travory への招待").font(.subheadline.weight(.semibold))
                    }
                    Text("押すと、参加の画面が開きます").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.95, green: 0.96, blue: 0.98)))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(color: .black.opacity(0.08), radius: 10, y: 4))
            .frame(maxWidth: 300, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.down")
                .font(.title3.weight(.bold))
                .foregroundStyle(blue.opacity(0.5))

            // 開いた参加の画面
            VStack(spacing: 10) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 30))
                    .foregroundStyle(blue)
                Text("沖縄 3泊4日").font(.headline)
                Text("TRAVEL-8K2M4Q7P")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(blue.opacity(0.1)))
                Text("参加する")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(orange))
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22).fill(.white).shadow(color: .black.opacity(0.1), radius: 16, y: 8))
            .frame(maxWidth: 260)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: 340)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - 絵：旅のあと（ダイジェストのお知らせ・1年のふり返り）

private struct ShowcaseAfterTripVisual: View {
    let blue: Color
    let orange: Color

    private var year: Int { Calendar.current.component(.year, from: Date()) }

    var body: some View {
        VStack(spacing: 16) {
            // お知らせ
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "airplane")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 8).fill(blue))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("旅のダイジェストを作りませんか").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("20:00").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("沖縄 3泊4日で撮った写真と動画を、2秒ずつつないだ動画にできます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.95)).shadow(color: .black.opacity(0.1), radius: 12, y: 6))

            // 1年のふり返り
            VStack(alignment: .leading, spacing: 14) {
                Text("\(String(year))年の旅をふり返る")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                HStack(spacing: 0) {
                    stat("5", "旅行")
                    stat("12", "日")
                    stat("7", "都道府県")
                    stat("318", "枚")
                }
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        ShowcaseSamplePhotos.gradient(i)
                            .frame(height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [blue, Color(red: 0.45, green: 0.3, blue: 0.9)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: blue.opacity(0.3), radius: 16, y: 8)
            )
        }
        .frame(maxWidth: 340)
        .frame(maxHeight: .infinity)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.bold))
            Text(label).font(.caption2)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 絵：予約の読み取り

private struct ShowcaseReadingVisual: View {
    let blue: Color
    let orange: Color

    private let rows: [(String, String, String)] = [
        ("airplane.departure", "行き", "HND 08:10 → OKA 10:55"),
        ("airplane.arrival", "帰り", "OKA 18:40 → HND 21:05"),
        ("bus.fill", "バス", "那覇空港 → 美ら海水族館"),
        ("ferry.fill", "船", "泊港 → 渡嘉敷港"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "text.viewfinder").foregroundStyle(blue)
                Text("予約を読み取りました").font(.subheadline.weight(.semibold))
                Spacer()
                Text("4件").font(.caption.weight(.bold)).foregroundStyle(blue)
            }
            .padding(.bottom, 12)
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    Image(systemName: rows[i].0)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(blue)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(blue.opacity(0.1)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(rows[i].1).font(.caption).foregroundStyle(.secondary)
                        Text(rows[i].2).font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.45))
                }
                .padding(.vertical, 9)
                if i < rows.count - 1 { Divider() }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white).shadow(color: .black.opacity(0.1), radius: 16, y: 8))
        .frame(maxWidth: 340)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - 絵：旅行計画なしで自由に作る（3.8）

private struct ShowcaseFreeMemoryVisual: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                polaroid(0).rotationEffect(.degrees(-9)).offset(x: -70, y: 8)
                polaroid(2).rotationEffect(.degrees(8)).offset(x: 70, y: 4)
                polaroid(1).rotationEffect(.degrees(-2)).offset(y: -6)
            }
            .frame(height: 190)
            Text("Make your own")
                .font(MemoryFont.script(38))
                .foregroundStyle(MemoryColor.ink)
            Text("SUMMER WEEKEND · 24 PHOTOS")
                .font(MemoryFont.mono(11))
                .foregroundStyle(MemoryColor.softInk)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: 340)
        .background(RoundedRectangle(cornerRadius: 22).fill(MemoryColor.paper)
            .shadow(color: .black.opacity(0.1), radius: 16, y: 8))
        .frame(maxHeight: .infinity)
    }

    private func polaroid(_ index: Int) -> some View {
        ShowcaseSamplePhotos.gradient(index)
            .frame(width: 112, height: 120)
            .padding(7)
            .padding(.bottom, 18)
            .background(Color.white)
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }
}

// MARK: - 絵：＋のメニュー（3.8）

private struct ShowcaseAddMenuVisual: View {
    private let rows: [(String, String, String)] = [
        ("photo collage", "写真コラージュ", "square.grid.2x2"),
        ("travel poster", "旅行ポスター", "photo.artframe"),
        ("travel diary", "旅行日記", "book.pages"),
        ("trip movie", "旅のダイジェスト", "play.rectangle.on.rectangle"),
        ("new album", "アルバム", "rectangle.stack.badge.plus"),
    ]

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: -3) {
                        Text(rows[i].0).font(MemoryFont.hand(16)).foregroundStyle(MemoryColor.softInk)
                        Text(rows[i].1).font(.system(size: 14, weight: .bold)).foregroundStyle(MemoryColor.ink)
                    }
                    .padding(.leading, 16).padding(.trailing, 14).padding(.vertical, 7)
                    .background(Capsule().fill(MemoryColor.paper))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                    Image(systemName: rows[i].2)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(MemoryColor.ink)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(MemoryColor.paper))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                        .padding(.trailing, 5)
                }
            }
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(MemoryColor.paper)
                .rotationEffect(.degrees(135))
                .frame(width: 56, height: 56)
                .background(Circle().fill(MemoryColor.ink))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .padding(24)
        .frame(maxWidth: 340, alignment: .trailing)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.06)))
        .frame(maxHeight: .infinity)
    }
}

// MARK: - 絵：予約を「移動」の形で（3.8）

private struct ShowcaseMoveVisual: View {
    let blue: Color
    let orange: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(time: "07:00", title: "羽田 → 那覇", detail: "NH993 · 座席 23A", icon: "airplane", end: "09:45")
            HStack(spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("飛行機").font(.system(size: 10, weight: .bold))
                    Text("2時間45分").font(.system(size: 10, weight: .semibold)).monospacedDigit()
                }
                .foregroundStyle(blue)
                .frame(width: 58, alignment: .trailing)
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(blue))
                    .padding(.leading, 6)
            }
            .padding(.vertical, 6)
            row(time: "10:30", title: "レンタカーを借りる", detail: "那覇空港", icon: "mappin.circle.fill", end: nil)
        }
        .padding(20)
        .frame(maxWidth: 340, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white).shadow(color: .black.opacity(0.1), radius: 16, y: 8))
        .frame(maxHeight: .infinity)
    }

    private func row(time: String, title: String, detail: String, icon: String, end: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(time).font(.system(size: 14, weight: .bold)).monospacedDigit()
                if let end { Text(end).font(.system(size: 12, weight: .semibold)).monospacedDigit().opacity(0.6) }
            }
            .foregroundStyle(.secondary)
            .frame(width: 46, alignment: .trailing)
            Circle().stroke(blue, lineWidth: 3).frame(width: 12, height: 12).padding(.top, 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Label(detail, systemImage: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(blue)
                    .labelStyle(.titleAndIcon)
            }
        }
    }
}
