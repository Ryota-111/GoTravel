import SwiftUI

/// しおりの配色と文字（デザインごと）
struct BookletPalette {
    let paper: Color
    let ink: Color
    let subInk: Color
    let accent: Color
    let rule: Color
    let design: Font.Design

    static func make(_ style: TravelBooklet.Style, theme: ThemePreset) -> BookletPalette {
        switch style {
        case .simple:
            return BookletPalette(paper: .white, ink: Color(white: 0.1), subInk: Color(white: 0.42),
                                  accent: Color(white: 0.1), rule: Color(white: 0.82), design: .default)
        case .cute:
            // テーマの色を、紙の上で読める濃さに寄せて使う。デフォルトカラーの青は寄せると黒に近づき
            // シンプルと見分けがつかなくなるので、コーラルピンクにする
            let base = theme.type == .originalColor ? Color(red: 0.93, green: 0.42, blue: 0.5) : theme.actionFill
            let accent = ThemePreset.readableTintEitherWay(base, on: .white, minimum: 3.0)
            return BookletPalette(paper: Color(red: 1.0, green: 0.98, blue: 0.97), ink: Color(white: 0.16),
                                  subInk: Color(white: 0.42), accent: accent,
                                  rule: accent.opacity(0.25), design: .rounded)
        case .japanese:
            return BookletPalette(paper: Color(red: 0.97, green: 0.95, blue: 0.9), ink: Color(red: 0.16, green: 0.13, blue: 0.11),
                                  subInk: Color(red: 0.42, green: 0.37, blue: 0.32),
                                  accent: Color(red: 0.75, green: 0.22, blue: 0.17),
                                  rule: Color(red: 0.75, green: 0.22, blue: 0.17).opacity(0.3), design: .serif)
        }
    }

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: design)
    }
}

/// しおりを描くのに要るもの（写真と地図は先に用意しておく。描く処理は同期で行うため）
struct BookletContext {
    let plan: TravelPlan
    let style: TravelBooklet.Style
    let palette: BookletPalette
    let userId: String?
    let coverImage: UIImage?
    /// 日ごとの地図（番号つきの印を描き込んだもの）
    let maps: [Int: UIImage]
    let pageCount: Int
}

/// 1ページ
struct BookletPageView: View {
    let page: TravelBooklet.Page
    let pageNumber: Int
    let context: BookletContext

    private var p: BookletPalette { context.palette }
    private var plan: TravelPlan { context.plan }

    var body: some View {
        ZStack(alignment: .topLeading) {
            p.paper
            switch page {
            case .cover:
                cover
            default:
                VStack(alignment: .leading, spacing: 0) {
                    content
                    Spacer(minLength: 0)
                    footer
                }
                .padding(.horizontal, 32)
                .padding(.top, 34)
                .padding(.bottom, 22)
            }
        }
        .frame(width: TravelBooklet.pageSize.width, height: TravelBooklet.pageSize.height)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .cover:
            EmptyView()
        case let .day(dayNumber, itemIDs, showsMap, isContinued):
            dayPage(dayNumber: dayNumber, itemIDs: itemIDs, showsMap: showsMap, isContinued: isContinued)
        case let .packing(packingIDs, souvenirIDs):
            packingPage(packingIDs: packingIDs, souvenirIDs: souvenirIDs)
        case .costs:
            costsPage
        case let .memo(id):
            memoPage(id: id)
        }
    }

    // MARK: 表紙

    private var cover: some View {
        VStack(spacing: 0) {
            if let image = context.coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: TravelBooklet.pageSize.width, height: 300)
                    .clipped()
            } else {
                coverPattern.frame(height: 300)
            }
            VStack(spacing: 14) {
                Text(context.style == .japanese ? "旅のしおり" : "TRAVEL BOOKLET")
                    .font(p.font(11, .semibold))
                    .tracking(context.style == .japanese ? 6 : 4)
                    .foregroundColor(p.accent)
                Text(plan.title)
                    .font(p.font(30, .bold))
                    .foregroundColor(p.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Rectangle().fill(p.accent).frame(width: 36, height: 2)
                Text(dateRange)
                    .font(p.font(14, .medium))
                    .foregroundColor(p.ink)
                if !plan.destination.isEmpty {
                    Label(plan.destination, systemImage: "mappin.and.ellipse")
                        .font(p.font(13))
                        .foregroundColor(p.subInk)
                }
                Text("\(plan.dayCount)日間")
                    .font(p.font(12))
                    .foregroundColor(p.subInk)
            }
            .padding(.horizontal, 36)
            .padding(.top, 34)
            Spacer()
            Text("Travory で作成")
                .font(p.font(9))
                .foregroundColor(p.subInk.opacity(0.8))
                .padding(.bottom, 20)
        }
        .frame(width: TravelBooklet.pageSize.width, height: TravelBooklet.pageSize.height)
    }

    /// 写真の無い表紙の柄
    private var coverPattern: some View {
        ZStack {
            p.accent.opacity(context.style == .simple ? 0.08 : 0.14)
            if context.style == .cute {
                Canvas { gc, size in
                    var y: CGFloat = 12
                    var row = 0
                    while y < size.height {
                        var x: CGFloat = row.isMultiple(of: 2) ? 14 : 38
                        while x < size.width {
                            gc.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 9, height: 9)),
                                    with: .color(.white.opacity(0.7)))
                            x += 48
                        }
                        y += 26
                        row += 1
                    }
                }
            }
            Image(systemName: context.style == .japanese ? "mountain.2" : (context.style == .cute ? "heart.circle.fill" : "airplane"))
                .font(.system(size: 64, weight: .light))
                .foregroundColor(p.accent.opacity(0.5))
        }
    }

    private var dateRange: String {
        "\(TravelPlanTextExporter.dateString(plan.startDate)) 〜 \(TravelPlanTextExporter.dateString(plan.endDate))"
    }

    // MARK: 見出し・下の帯

    @ViewBuilder
    private func heading(_ title: String, sub: String? = nil) -> some View {
        if context.style == .cute {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(p.font(17, .bold))
                    .foregroundColor(p.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(p.accent.opacity(0.13)))
                if let sub {
                    Text(sub)
                        .font(p.font(12))
                        .foregroundColor(p.subInk)
                }
            }
            .padding(.bottom, 14)
        } else {
            plainHeading(title, sub: sub)
        }
    }

    private func plainHeading(_ title: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if context.style == .japanese {
                    Rectangle().fill(p.accent).frame(width: 4, height: 18)
                }
                Text(title)
                    .font(p.font(20, .bold))
                    .foregroundColor(context.style == .cute ? p.accent : p.ink)
                if let sub {
                    Text(sub)
                        .font(p.font(12))
                        .foregroundColor(p.subInk)
                }
            }
            Rectangle().fill(p.rule).frame(height: 1)
        }
        .padding(.bottom, 14)
    }

    private var footer: some View {
        HStack {
            Text(plan.title)
            Spacer()
            Text("\(pageNumber) / \(context.pageCount)")
        }
        .font(p.font(9))
        .foregroundColor(p.subInk)
    }

    // MARK: 日程

    private func dayPage(dayNumber: Int, itemIDs: [String], showsMap: Bool, isContinued: Bool) -> some View {
        let day = plan.daySchedulesInRange.first { $0.dayNumber == dayNumber }
        let all = TravelPlanTextExporter.sortedByTime(day?.scheduleItems ?? [])
        let items = itemIDs.compactMap { id in all.first { $0.id == id } }
        let numbers = Self.mapNumbers(all)
        return VStack(alignment: .leading, spacing: 0) {
            heading("Day \(dayNumber)\(isContinued ? "（つづき）" : "")",
                    sub: TravelPlanTextExporter.dateString(plan.date(forDay: dayNumber)))
            if showsMap, let map = context.maps[dayNumber] {
                Image(uiImage: map)
                    .resizable()
                    .scaledToFill()
                    .frame(width: TravelBooklet.pageSize.width - 64, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: context.style == .cute ? 14 : 4))
                    .padding(.bottom, 14)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    scheduleRow(item, number: numbers[item.id])
                }
            }
        }
    }

    /// 地図の印の番号（場所のある予定にだけ、上から順に振る）
    static func mapNumbers(_ items: [ScheduleItem]) -> [String: Int] {
        var result: [String: Int] = [:]
        var n = 0
        for item in items where item.hasCoordinate {
            n += 1
            result[item.id] = n
        }
        return result
    }

    private func scheduleRow(_ item: ScheduleItem, number: Int?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.timeRangeText)
                .font(p.font(11, .semibold))
                .foregroundColor(p.accent)
                .frame(width: 78, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if let number {
                        Text("\(number)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 15, height: 15)
                            .background(Circle().fill(p.accent))
                    }
                    Text(item.title)
                        .font(p.font(13, .semibold))
                        .foregroundColor(p.ink)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    if let location = item.location, !location.isEmpty {
                        Text(location).lineLimit(1)
                    }
                    if let cost = item.displayCost, cost > 0 {
                        Text(TravelPlanTextExporter.currency(cost))
                    }
                }
                .font(p.font(10))
                .foregroundColor(p.subInk)
                if item.hasNotes, let notes = item.notes {
                    Text(notes)
                        .font(p.font(10))
                        .foregroundColor(p.subInk)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: 持ち物・お土産

    private func packingPage(packingIDs: [String], souvenirIDs: [String]) -> some View {
        let packing = TravelBooklet.packingItems(of: plan, userId: context.userId).filter { packingIDs.contains($0.id) }
        let souvenirs = TravelBooklet.souvenirItems(of: plan).filter { souvenirIDs.contains($0.id) }
        return VStack(alignment: .leading, spacing: 0) {
            if !packing.isEmpty {
                heading("持ち物", sub: "\(packing.count)個")
                checklist(packing)
                    .padding(.bottom, 18)
            }
            if !souvenirs.isEmpty {
                heading("お土産", sub: "\(souvenirs.count)個")
                checklist(souvenirs)
            }
        }
    }

    private func checklist(_ items: [PackingItem]) -> some View {
        let half = (items.count + 1) / 2
        return HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(items.prefix(half)) { checkRow($0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(items.dropFirst(half)) { checkRow($0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 印刷してから書き込めるよう、チェック欄は空けておく
    private func checkRow(_ item: PackingItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            RoundedRectangle(cornerRadius: context.style == .cute ? 4 : 1.5)
                .stroke(p.ink.opacity(0.6), lineWidth: 1)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(p.font(11))
                    .foregroundColor(p.ink)
                    .lineLimit(1)
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(p.font(9))
                        .foregroundColor(p.subInk)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: 費用

    private var costsPage: some View {
        let totals = TravelBooklet.dayTotals(of: plan)
        let total = TravelBooklet.costTotal(of: plan)
        return VStack(alignment: .leading, spacing: 0) {
            heading("費用")
            VStack(spacing: 9) {
                ForEach(totals, id: \.dayNumber) { row in
                    HStack {
                        Text("Day \(row.dayNumber)")
                        Text(TravelPlanTextExporter.dateString(plan.date(forDay: row.dayNumber)))
                            .foregroundColor(p.subInk)
                        Spacer()
                        Text(TravelPlanTextExporter.currency(row.total))
                    }
                    .font(p.font(12))
                    .foregroundColor(p.ink)
                }
            }
            Rectangle().fill(p.rule).frame(height: 1).padding(.vertical, 12)
            HStack {
                Text(TravelPlanTextExporter.costTotalLabel(for: plan))
                Spacer()
                Text(TravelPlanTextExporter.currency(total))
            }
            .font(p.font(15, .bold))
            .foregroundColor(p.ink)
            if plan.splitCount > 1 {
                HStack {
                    Text("1人あたり（\(plan.splitCount)人）")
                    Spacer()
                    Text(TravelPlanTextExporter.currency((total / Double(plan.splitCount)).rounded()))
                }
                .font(p.font(13, .semibold))
                .foregroundColor(p.accent)
                .padding(.top, 8)
            }
        }
    }

    // MARK: メモ

    private func memoPage(id: String) -> some View {
        let memo = plan.sharedMemos.first { $0.id == id }
        return VStack(alignment: .leading, spacing: 0) {
            heading(memo?.displayTitle ?? "メモ")
            Text(memo?.body ?? "")
                .font(p.font(12))
                .foregroundColor(p.ink)
                .lineSpacing(5)
                .lineLimit(26)
        }
    }
}
