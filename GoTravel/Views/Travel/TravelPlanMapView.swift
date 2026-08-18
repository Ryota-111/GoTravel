import SwiftUI
import MapKit

// MARK: - Travel Plan Map View
/// 旅行計画のタイムスケジュールを地図上のピンとして表示する
struct TravelPlanMapView: View {

    // MARK: - Scope
    enum Scope: Hashable {
        case day(Int)
        case all
    }

    // MARK: - Mapped Item
    /// 座標を持つスケジュール項目に、日番号と時刻順の連番を付けたもの
    struct MappedScheduleItem: Identifiable, Equatable {
        let id: String
        let item: ScheduleItem
        let dayNumber: Int
        let order: Int
        let coordinate: CLLocationCoordinate2D

        static func == (lhs: MappedScheduleItem, rhs: MappedScheduleItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    private struct RouteSegment: Identifiable {
        let id: Int
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
    }

    /// 同一地点の項目をまとめたピン1つ分。重なって下の項目が見えなくなるのを防ぐ
    struct PinGroup: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let items: [MappedScheduleItem]

        var isSingle: Bool { items.count == 1 }

        /// 同じ日の項目だけで構成されているか（番号を色分けする必要があるかの判定）
        var isSameDay: Bool { Set(items.map(\.dayNumber)).count == 1 }

        var displayTitle: String {
            items.first?.item.location ?? items.first?.item.title ?? ""
        }
    }

    // MARK: - Properties
    let plan: TravelPlan

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    @State private var scope: Scope
    @State private var selectedGroupID: String?
    @State private var cameraPosition: MapCameraPosition

    /// 実際に使う絞り込み。行程表と並べているときは向こうの日に従う
    private var effectiveScope: Scope {
        if let linkedDay { return .day(linkedDay.wrappedValue) }
        return scope
    }

    /// 1点に集中した時でも地図が寄りすぎないようにする最小の表示範囲
    private static let minimumSpan: CLLocationDegrees = 0.01

    /// 日ごとの色。区別しやすさを優先した固定パレットを順に使う
    private static let dayColors: [Color] = [
        Color(red: 0.20, green: 0.55, blue: 0.90),
        Color(red: 0.95, green: 0.55, blue: 0.20),
        Color(red: 0.30, green: 0.72, blue: 0.45),
        Color(red: 0.75, green: 0.40, blue: 0.85),
        Color(red: 0.90, green: 0.35, blue: 0.45),
        Color(red: 0.20, green: 0.70, blue: 0.75)
    ]

    // MARK: - Initialization
    /// タブに埋め込むときは true。閉じるボタンを出さない
    var isEmbedded: Bool = false

    /// 行程表と上下に並べるモード。
    /// 日の選択と項目の選択は下の行程表に任せるので、
    /// 地図側の上部バー・日の切り替え・詳細パネルは出さない
    var isSplitMode: Bool = false

    /// 下の行程表と共有する日番号
    var linkedDay: Binding<Int>?

    /// 下の行程表と共有する選択中の項目。ScheduleItem の id を入れる
    var linkedItemID: Binding<String?>?

    init(plan: TravelPlan,
         initialDay: Int,
         isEmbedded: Bool = false,
         isSplitMode: Bool = false,
         linkedDay: Binding<Int>? = nil,
         linkedItemID: Binding<String?>? = nil) {
        self.plan = plan
        self.isEmbedded = isEmbedded
        self.isSplitMode = isSplitMode
        self.linkedDay = linkedDay
        self.linkedItemID = linkedItemID
        _scope = State(initialValue: .day(initialDay))

        // 実際の範囲は onAppear でピンに合わせ直す
        let fallback = CLLocationCoordinate2D(
            latitude: plan.latitude ?? 36.2048,
            longitude: plan.longitude ?? 138.2529
        )
        let span = plan.latitude == nil
            ? MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            : MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(center: fallback, span: span)))
    }

    // MARK: - Computed Properties
    private var tripDuration: Int {
        let days = Calendar.current.dateComponents([.day], from: plan.startDate, to: plan.endDate).day ?? 0
        return max(days + 1, 1)
    }

    private var scopedDaySchedules: [DaySchedule] {
        plan.daySchedules
            .filter { effectiveScope == .all || effectiveScope == .day($0.dayNumber) }
            .sorted { $0.dayNumber < $1.dayNumber }
    }

    /// 表示対象のうち座標を持つ項目。連番は日ごとに1から振り直す
    private var mappedItems: [MappedScheduleItem] {
        var result: [MappedScheduleItem] = []

        for day in scopedDaySchedules {
            var order = 0
            for item in sortedByTime(day.scheduleItems) {
                guard let latitude = item.latitude, let longitude = item.longitude else { continue }
                order += 1
                result.append(
                    MappedScheduleItem(
                        id: item.id,
                        item: item,
                        dayNumber: day.dayNumber,
                        order: order,
                        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    )
                )
            }
        }
        return result
    }

    /// 同一座標の項目をまとめる。表示順は各グループの先頭項目の順序に従う
    private var pinGroups: [PinGroup] {
        var order: [String] = []
        var buckets: [String: [MappedScheduleItem]] = [:]

        for mapped in mappedItems {
            let key = Self.locationKey(mapped.coordinate)
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(mapped)
        }

        return order.compactMap { key in
            guard let items = buckets[key], let first = items.first else { return nil }
            return PinGroup(id: key, coordinate: first.coordinate, items: items)
        }
    }

    private var selectedGroup: PinGroup? {
        guard let selectedGroupID else { return nil }
        return pinGroups.first { $0.id == selectedGroupID }
    }

    /// 日をまたいで線がつながらないよう、日ごとに独立した経路として描く
    private var routeSegments: [RouteSegment] {
        Dictionary(grouping: mappedItems, by: \.dayNumber)
            .compactMap { dayNumber, items -> RouteSegment? in
                let sorted = items.sorted { $0.order < $1.order }
                guard sorted.count >= 2 else { return nil }
                return RouteSegment(
                    id: dayNumber,
                    coordinates: sorted.map(\.coordinate),
                    color: Self.dayColor(for: dayNumber)
                )
            }
            .sorted { $0.id < $1.id }
    }

    /// 場所が未設定で地図に出せない項目の数
    private var unmappableCount: Int {
        var count = 0
        for day in scopedDaySchedules {
            for item in day.scheduleItems where item.latitude == nil || item.longitude == nil {
                count += 1
            }
        }
        return count
    }

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var panelBackground: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : Color(.systemBackground)
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .top) {
            mapLayer

            if !isSplitMode {
                VStack(spacing: 10) {
                    topBar
                    scopeSelector
                    if unmappableCount > 0 {
                        unmappableNotice
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            if mappedItems.isEmpty {
                emptyOverlay
            }
        }
        .overlay(alignment: .bottom) {
            // 分割モードでは下の行程表が詳細の役目を持つので出さない
            if !isSplitMode, let selected = selectedGroup {
                detailPanel(selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            // 分割モードは上のバーを出さないので、ここだけ単独で置く
            if isSplitMode {
                fitAllButton
                    .padding(12)
            }
        }
        // 行程表で選ばれた項目にピンを合わせる
        .onChange(of: linkedItemID?.wrappedValue) { _, itemID in
            guard isSplitMode, let itemID else { return }
            focusPin(forItemID: itemID)
        }
        .onAppear { fitCameraToPins(animated: false) }
        .onChange(of: effectiveScope) { _, _ in
            selectedGroupID = nil
            fitCameraToPins(animated: true)
        }
    }

    // MARK: - Map Layer
    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            ForEach(routeSegments) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(
                        segment.color.opacity(0.85),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 7])
                    )
            }

            ForEach(pinGroups) { group in
                Annotation(group.displayTitle, coordinate: group.coordinate) {
                    pinView(group)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .ignoresSafeArea()
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedGroupID = nil
            }
        }
    }

    /// 単独なら丸ピン、同一地点に複数あるならカプセル型に番号を並べる
    @ViewBuilder
    private func pinView(_ group: PinGroup) -> some View {
        // 分割モードでは行程表側の選択に合わせて光らせる
        let isSelected: Bool = {
            if isSplitMode, let itemID = linkedItemID?.wrappedValue {
                return group.items.contains { $0.item.id == itemID }
            }
            return selectedGroupID == group.id
        }()

        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedGroupID = group.id
                // 下の行程表の該当行へ知らせる
                if isSplitMode {
                    linkedItemID?.wrappedValue = group.items.first?.item.id
                }
            }
        } label: {
            Group {
                if group.isSingle, let only = group.items.first {
                    singlePinLabel(only)
                } else {
                    groupPinLabel(group)
                }
            }
            .scaleEffect(isSelected ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(pinAccessibilityLabel(group))
    }

    private func singlePinLabel(_ mapped: MappedScheduleItem) -> some View {
        let color = Self.dayColor(for: mapped.dayNumber)

        return ZStack {
            Circle()
                .fill(color)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .shadow(color: color.opacity(0.45), radius: 4, x: 0, y: 2)

            Text("\(mapped.order)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func groupPinLabel(_ group: PinGroup) -> some View {
        // 番号が多いと横に伸びすぎるため、3件までを並べて残りは +N にまとめる
        let shown: [MappedScheduleItem] = Array(group.items.prefix(3))
        let overflow: Int = group.items.count - shown.count
        let isSameDay: Bool = group.isSameDay

        // 同じ日なら日の色で塗った上に白文字、日をまたぐなら白地に日ごとの色で番号を出す
        let fillColor: Color = isSameDay ? Self.dayColor(for: group.items[0].dayNumber) : Color(.systemBackground)
        let strokeColor: Color = isSameDay ? Color.white : Color.secondary.opacity(0.35)
        let separatorColor: Color = isSameDay ? Color.white.opacity(0.7) : Color.secondary
        let overflowColor: Color = isSameDay ? Color.white.opacity(0.85) : Color.secondary

        return HStack(spacing: 4) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, mapped in
                if index > 0 {
                    Text("・")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(separatorColor)
                }
                Text("\(mapped.order)")
                    .font(.system(size: 15, weight: .bold))
                    // 日をまたぐ場合は番号だけでは区別できないため日の色で塗り分ける
                    .foregroundStyle(isSameDay ? Color.white : Self.dayColor(for: mapped.dayNumber))
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(overflowColor)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Capsule().fill(fillColor))
        .overlay(Capsule().stroke(strokeColor, lineWidth: 2.5))
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    }

    private func pinAccessibilityLabel(_ group: PinGroup) -> String {
        if let only = group.items.first, group.isSingle {
            return "\(only.order)番目 \(only.item.title)"
        }
        return "\(group.displayTitle) \(group.items.count)件の予定"
    }

    // MARK: - Top Bar
    /// 全体が入るところまで戻す。ピンを追ってずれた後に元の見え方へ戻せる
    private var fitAllButton: some View {
        Button(action: {
            selectedGroupID = nil
            if isSplitMode { linkedItemID?.wrappedValue = nil }
            fitCameraToPins(animated: true)
        }) {
            Image(systemName: "scope")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(accentColor)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("全体を表示")
        .disabled(mappedItems.isEmpty)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            if !isEmbedded {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(accentColor)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("閉じる")
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(plan.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)
                Text("\(mappedItems.count)件の場所")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            Spacer(minLength: 0)

            fitAllButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Scope Selector
    private var scopeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                scopeChip(title: "全日程", scopeValue: .all, color: themeManager.currentTheme.primary)

                ForEach(1...tripDuration, id: \.self) { day in
                    scopeChip(title: "Day \(day)", scopeValue: .day(day), color: Self.dayColor(for: day))
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func scopeChip(title: String, scopeValue: Scope, color: Color) -> some View {
        let isSelected = scope == scopeValue

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scope = scopeValue
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(isSelected ? .white : accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule().fill(color)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Notices
    private var unmappableNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.slash")
                .font(.caption2)
            Text("場所未設定のため地図に表示できない予定が\(unmappableCount)件あります")
                .font(.caption2)
                .lineLimit(2)
        }
        .foregroundColor(themeManager.currentTheme.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 40))
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.6))

            Text("表示できる場所がありません")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)

            Text("スケジュールに場所を設定すると\nここに表示されます")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 40)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Detail Panel
    /// 同一地点の項目をすべて並べる。経路案内は座標が共通なのでパネルに1組だけ置く
    private func detailPanel(_ group: PinGroup) -> some View {
        let primaryColor = Self.dayColor(for: group.items[0].dayNumber)

        return VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            panelHeader(group)
                .padding(.horizontal, 20)

            if group.items.count > 3 {
                ScrollView {
                    panelItemList(group)
                }
                .frame(maxHeight: 220)
                .padding(.top, 12)
            } else {
                panelItemList(group)
                    .padding(.top, 12)
            }

            HStack(spacing: 10) {
                Button(action: {
                    openInAppleMaps(
                        name: group.displayTitle,
                        latitude: group.coordinate.latitude,
                        longitude: group.coordinate.longitude
                    )
                }) {
                    Label("経路案内", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(primaryColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    openInGoogleMaps(
                        latitude: group.coordinate.latitude,
                        longitude: group.coordinate.longitude
                    )
                }) {
                    Label("Google", systemImage: "globe")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(primaryColor.opacity(0.12))
                        .foregroundStyle(primaryColor)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(panelBackground)
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func panelHeader(_ group: PinGroup) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.displayTitle)
                    .font(.headline)
                    .foregroundColor(accentColor)
                    .lineLimit(2)

                if !group.isSingle {
                    Text("この場所に\(group.items.count)件の予定")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
            }

            Spacer(minLength: 0)

            Button(action: {
                withAnimation { selectedGroupID = nil }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(.systemGray3))
            }
            .accessibilityLabel("閉じる")
        }
    }

    private func panelItemList(_ group: PinGroup) -> some View {
        VStack(spacing: 8) {
            ForEach(group.items) { mapped in
                panelItemRow(mapped, showDayBadge: effectiveScope == .all || !group.isSameDay)
            }
        }
        .padding(.horizontal, 20)
    }

    private func panelItemRow(_ mapped: MappedScheduleItem, showDayBadge: Bool) -> some View {
        let color = Self.dayColor(for: mapped.dayNumber)
        let item = mapped.item

        return HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                Text("\(mapped.order)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if showDayBadge {
                        Text("Day \(mapped.dayNumber)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.14), in: Capsule())
                    }

                    Text(DateFormatter.japaneseTime.string(from: item.time))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(themeManager.currentTheme.secondaryText)

                    if let cost = item.cost, cost > 0 {
                        Text(formatCost(cost))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Camera
    /// 表示中のピンがすべて収まる範囲にカメラを合わせる
    /// 行程表で選ばれた項目のピンへ寄る
    private func focusPin(forItemID itemID: String) {
        guard let target = mappedItems.first(where: { $0.item.id == itemID }) else { return }

        selectedGroupID = pinGroups.first { group in
            group.items.contains { $0.item.id == itemID }
        }?.id

        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: target.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: Self.minimumSpan, longitudeDelta: Self.minimumSpan)
                )
            )
        }
    }

    private func fitCameraToPins(animated: Bool) {
        let items = mappedItems

        let region: MKCoordinateRegion
        if items.isEmpty {
            let center = CLLocationCoordinate2D(
                latitude: plan.latitude ?? 36.2048,
                longitude: plan.longitude ?? 138.2529
            )
            let span = plan.latitude == nil
                ? MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
                : MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            region = MKCoordinateRegion(center: center, span: span)
        } else {
            let latitudes = items.map(\.coordinate.latitude)
            let longitudes = items.map(\.coordinate.longitude)
            let minLat = latitudes.min() ?? 0
            let maxLat = latitudes.max() ?? 0
            let minLon = longitudes.min() ?? 0
            let maxLon = longitudes.max() ?? 0

            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            // ピンが画面端に張り付かないよう余白を持たせる
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.5, Self.minimumSpan),
                longitudeDelta: max((maxLon - minLon) * 1.5, Self.minimumSpan)
            )
            region = MKCoordinateRegion(center: center, span: span)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }

    // MARK: - Helpers
    private static func dayColor(for dayNumber: Int) -> Color {
        let index = max(dayNumber - 1, 0) % dayColors.count
        return dayColors[index]
    }

    /// 同一地点の判定キー。約1m相当（小数5桁）に丸めて誤差を吸収する
    private static func locationKey(_ coordinate: CLLocationCoordinate2D) -> String {
        let latitude = (coordinate.latitude * 100_000).rounded() / 100_000
        let longitude = (coordinate.longitude * 100_000).rounded() / 100_000
        return "\(latitude),\(longitude)"
    }

    /// 日付部分を無視して時刻だけで並べる（詳細画面のタイムラインと同じ順序）
    private func sortedByTime(_ items: [ScheduleItem]) -> [ScheduleItem] {
        let calendar = Calendar.current

        return items.sorted { item1, item2 in
            let components1 = calendar.dateComponents([.hour, .minute], from: item1.time)
            let components2 = calendar.dateComponents([.hour, .minute], from: item2.time)

            let minutes1 = (components1.hour ?? 0) * 60 + (components1.minute ?? 0)
            let minutes2 = (components2.hour ?? 0) * 60 + (components2.minute ?? 0)
            return minutes1 < minutes2
        }
    }

    private func formatCost(_ cost: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "¥\(formatter.string(from: NSNumber(value: cost)) ?? "0")"
    }

    private func openInAppleMaps(name: String, latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openInGoogleMaps(latitude: Double, longitude: Double) {
        let urlString = "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
