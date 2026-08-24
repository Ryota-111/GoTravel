import SwiftUI
import MapKit

struct AddPlanView: View {

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    /// 履歴の元データ。既存の予定をそのままテンプレートとして再利用する
    var historyPlans: [Plan] = []
    var onSave: (Plan) -> Void

    // Wizard state
    @State private var currentStep: Int = 0
    @State private var isGoingForward: Bool = true
    @State private var showDiscardConfirm: Bool = false
    @State private var showHistoryPicker: Bool = false
    @State private var expandedField: DateField?
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isDescriptionFocused: Bool

    // Form data
    @State private var selectedPlanType: PlanType = .outing
    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var places: [PlannedPlace] = []
    @State private var dailyDate: Date = Date()
    @State private var dailyTime: Date = Date()
    @State private var description: String = ""
    @State private var linkURL: String = ""

    // Map state
    @State private var showMapPicker: Bool = false
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @State private var selectedMapResult: MKMapItem?
    @State private var mapVisibleRegion: MKCoordinateRegion?

    // MARK: - Computed Properties
    // 0:種別+タイトル / 1:日付 / 2:場所 / 3:内容+リンク（日常のみ）
    private var totalSteps: Int { selectedPlanType == .outing ? 3 : 4 }
    private var isLastStep: Bool { currentStep == totalSteps - 1 }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return !title.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return selectedPlanType == .outing ? startDate <= endDate : true
        default: return true
        }
    }

    /// タイトルさえ入っていれば残りは任意なので、いつでも保存できる
    private var canSaveNow: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && (selectedPlanType == .daily || startDate <= endDate)
    }

    // MARK: - History

    /// 同じタイトルの予定をまとめた履歴の1件
    private struct HistoryEntry: Identifiable {
        let id: String        // 正規化したタイトル
        let plan: Plan        // プリフィル元となる最新の予定
        let count: Int        // 作成回数
        let lastUsed: Date
    }

    private static let historyLimit = 20

    /// 過去の予定をタイトルでまとめ、よく使う順に並べる
    private var historyEntries: [HistoryEntry] {
        let grouped = Dictionary(grouping: historyPlans) { plan in
            plan.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        let entries = grouped.compactMap { key, plans -> HistoryEntry? in
            // historyPlans は開始日の降順で渡されるため、先頭が最新の予定
            guard !key.isEmpty, let latest = plans.first else { return nil }
            let lastUsed = plans.map(\.startDate).max() ?? latest.startDate
            return HistoryEntry(id: key, plan: latest, count: plans.count, lastUsed: lastUsed)
        }

        return entries
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.lastUsed > rhs.lastUsed
            }
            .prefix(Self.historyLimit)
            .map { $0 }
    }

    // 入力途中の内容があるか（誤操作による破棄を防ぐ）
    private var hasUnsavedInput: Bool {
        currentStep > 0
            || !title.trimmingCharacters(in: .whitespaces).isEmpty
            || !places.isEmpty
            || !description.trimmingCharacters(in: .whitespaces).isEmpty
            || !linkURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Theme-Adaptive Colors

    // おでかけ=青・日常=オレンジ で全テーマ統一
    private func planColorFor(_ type: PlanType) -> Color {
        type == .outing ? themeManager.currentTheme.outingPlanColor : themeManager.currentTheme.dailyPlanColor
    }

    private var effectivePlanColor: Color { planColorFor(selectedPlanType) }

    /// 文字の色。背景を明るい面に統一したので、種別で出し分ける必要がなくなった。
    /// 以前はおでかけ=青／日常=オレンジのべた塗りで明るさが正反対になり、
    /// テーマごとに文字色を場合分けしていた
    private var uiAccentColor: Color {
        themeManager.currentTheme.adaptiveText(for: colorScheme)
    }

    /// 明るい面に種別色をふわりと流すだけにする。
    /// 面ごと塗ると、選んだ種別で画面の明暗が入れ替わってしまう
    private var backgroundGradient: some View {
        let base = colorScheme == .dark
            ? themeManager.currentTheme.backgroundDark
            : themeManager.currentTheme.backgroundLight

        return ZStack {
            base

            RadialGradient(
                colors: [effectivePlanColor.opacity(colorScheme == .dark ? 0.30 : 0.16), .clear],
                center: UnitPoint(x: 0.06, y: 0),
                startRadius: 0,
                endRadius: 430
            )

            RadialGradient(
                colors: [effectivePlanColor.opacity(colorScheme == .dark ? 0.16 : 0.09), .clear],
                center: UnitPoint(x: 1, y: 0.92),
                startRadius: 0,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.35), value: selectedPlanType)
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isGoingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isGoingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 0) {
                headerView
                progressView
                stepContentView
                navigationButtons
            }
        }
        .fullScreenCover(isPresented: $showMapPicker) { mapPickerView }
        .sheet(isPresented: $showHistoryPicker) { historyPickerView }
        .navigationBarHidden(true)
        .interactiveDismissDisabled(hasUnsavedInput)
        .confirmationDialog("入力内容を破棄しますか？", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("破棄する", role: .destructive) {
                presentationMode.wrappedValue.dismiss()
            }
            Button("編集を続ける", role: .cancel) {}
        } message: {
            Text("作成途中のプランは保存されません")
        }
        .onChange(of: startDate) { _, newValue in
            // 開始日を終了日より後にした場合は終了日を自動で追従させる
            if endDate < newValue {
                endDate = newValue
            }
        }
    }

    // MARK: - Header
    //
    // 中央のタイトルは外した。「新しいプラン」と出しても、
    // 今どの質問に答えているかは分からない。見出しは各ステップが持つ
    private var headerView: some View {
        HStack {
            Button(action: {
                if currentStep > 0 {
                    goBack()
                } else if hasUnsavedInput {
                    showDiscardConfirm = true
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                // 最初のステップだけ閉じる。以降は1つ前へ戻す
                Image(systemName: currentStep > 0 ? "chevron.left" : "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(uiAccentColor)
                    .frame(width: 38, height: 38)
                    .background(uiAccentColor.opacity(0.08), in: Circle())
            }
            .accessibilityLabel(currentStep > 0 ? "前の質問へ" : "閉じる")

            Spacer()

            // 名前さえ入れば途中のステップを飛ばして保存できる
            if canSaveNow {
                Button(action: savePlan) {
                    Text("保存")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(ThemePreset.readableText(on: effectivePlanColor))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(effectivePlanColor, in: Capsule())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: canSaveNow)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Progress Indicator
    private var progressView: some View {
        HStack(spacing: 5) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? effectivePlanColor : uiAccentColor.opacity(0.14))
                    .frame(height: 4)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: totalSteps)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Step Heading
    //
    // 質問文そのものを見出しにする。中央タイトルと小さな問いかけの二段構えは、
    // どちらも主役になれていなかった
    private func stepHeading(_ stepName: String, question: String, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ステップ \(currentStep + 1) · \(stepName)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(effectivePlanColor)

            Text(question)
                .font(.system(size: 27, weight: .heavy))
                .foregroundColor(uiAccentColor)
                .fixedSize(horizontal: false, vertical: true)

            if let sub {
                Text(sub)
                    .font(.system(size: 14))
                    .foregroundColor(uiAccentColor.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    // MARK: - Step Content
    private var stepContentView: some View {
        ZStack {
            switch currentStep {
            case 0: step0TypeAndTitle
            case 1: step1Date
            case 2: step2Places
            case 3: step3DescriptionAndLink
            default: EmptyView()
            }
        }
        .id(currentStep)
        .transition(stepTransition)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation Buttons
    //
    // 「戻る」と「次へ」を同じ大きさで下に並べると、進む先が主役に見えない。
    // 戻るはヘッダー左の ‹ に移し、下は主ボタン1つだけにした
    private var navigationButtons: some View {
        VStack(spacing: 10) {
            Button(action: goForward) {
                HStack(spacing: 6) {
                    if isLastStep {
                        Image(systemName: selectedPlanType == .outing ? "airplane.departure" : "calendar.badge.clock")
                        Text("保存")
                    } else {
                        Text("次へ")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(canProceed ? ThemePreset.readableText(on: effectivePlanColor) : uiAccentColor.opacity(0.35))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(canProceed ? AnyShapeStyle(effectivePlanColor) : AnyShapeStyle(uiAccentColor.opacity(0.08)))
                )
                .shadow(
                    color: canProceed ? effectivePlanColor.opacity(colorScheme == .dark ? 0 : 0.32) : .clear,
                    radius: 14,
                    x: 0,
                    y: 7
                )
                .animation(.easeInOut(duration: 0.2), value: canProceed)
            }
            .disabled(!canProceed)

            // 任意の項目は、入れずに進めることが分かるようにしておく
            if isOptionalStep && !isLastStep {
                Button(action: goForward) {
                    Text("この項目をとばす")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(uiAccentColor.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 26)
    }

    /// 場所と、内容・リンクは入れなくても保存できる
    private var isOptionalStep: Bool {
        currentStep == 2 || currentStep == 3
    }

    private func goBack() {
        isGoingForward = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep -= 1
        }
    }

    private func goForward() {
        guard !isLastStep else {
            savePlan()
            return
        }
        isGoingForward = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep += 1
        }
    }

    // MARK: - Step 0: Type + Title
    private var step0TypeAndTitle: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeading(
                    "種類と名前",
                    question: "何のプランを\n作りますか？",
                    sub: "選んだ種類で、この先の質問が変わります。"
                )

                VStack(spacing: 10) {
                    typeCard(type: .outing, icon: "figure.walk", title: "おでかけ", subtitle: "旅行・お出かけ計画")
                    typeCard(type: .daily, icon: "house.fill", title: "日常", subtitle: "日常のタスク・用事")
                }
                .padding(.horizontal, 20)

                // 箱をやめて直接書く。文字を大きくすると、
                // ここが今答える場所だと一目で分かる
                VStack(alignment: .leading, spacing: 10) {
                    Text("名前")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(uiAccentColor.opacity(0.5))

                    ZStack(alignment: .leading) {
                        if title.isEmpty {
                            Text(selectedPlanType == .outing ? "大阪旅行" : "ジム")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(uiAccentColor.opacity(0.22))
                        }
                        TextField("", text: $title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(uiAccentColor)
                            .focused($isTitleFocused)
                            .submitLabel(.next)
                            .onSubmit {
                                if canProceed { goForward() }
                            }
                    }

                    // 入れ終わったことが下線の色で分かる
                    Rectangle()
                        .fill(title.isEmpty ? uiAccentColor.opacity(0.15) : effectivePlanColor)
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.2), value: title.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                historyEntryButton

                Spacer(minLength: 20)
            }
        }
    }

    /// 履歴が1件もないうちはボタン自体を出さない
    @ViewBuilder
    private var historyEntryButton: some View {
        if !historyEntries.isEmpty {
            Button(action: { showHistoryPicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("履歴から作成")
                            .font(.headline)
                        Text("よく使う予定を選んですぐ作成")
                            .font(.caption)
                            .opacity(0.7)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .opacity(0.5)
                }
                .foregroundColor(uiAccentColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(uiAccentColor.opacity(0.1))
                .cornerRadius(16)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
        }
    }

    /// 選ぶとそのカードがベタ塗りに変わる。
    /// 正方形2枚を横に並べていたときより、選んだ結果が先に見える
    private func typeCard(type: PlanType, icon: String, title: String, subtitle: String) -> some View {
        let isSelected = selectedPlanType == type
        let cardColor = planColorFor(type)
        let onColor = ThemePreset.readableText(on: cardColor)

        return Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedPlanType = type
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(isSelected ? onColor.opacity(0.22) : cardColor.opacity(0.14))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? onColor : cardColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(isSelected ? onColor : uiAccentColor)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? onColor.opacity(0.75) : uiAccentColor.opacity(0.5))
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? onColor : uiAccentColor.opacity(0.2))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(cardColor) : AnyShapeStyle(uiAccentColor.opacity(0.05)))
            )
            .shadow(
                color: isSelected && colorScheme != .dark ? cardColor.opacity(0.28) : .clear,
                radius: 12,
                x: 0,
                y: 6
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Step 1: Date / DateTime
    @ViewBuilder
    private var step1Date: some View {
        if selectedPlanType == .outing {
            outingDateStep
        } else {
            dailyDateTimeStep
        }
    }

    private var outingDateStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeading("日程", question: "いつ行きますか？")

            // 同じ体裁の行を2本置くと、開始と終了のつながりが読めない。
            // 1枚にまとめて、間に矢印を置く
            VStack(spacing: 0) {
                dateField(.start, label: "開始", date: $startDate)

                Divider()
                    .background(uiAccentColor.opacity(0.08))
                    .padding(.leading, 16)

                dateField(.end, label: "終了", date: $endDate, range: startDate...)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardSurface)
            )
            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.06), radius: 12, x: 0, y: 5)
            .padding(.horizontal, 20)

            Group {
                if endDate < startDate {
                    Label("終了日は開始日以降にしてください", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.currentTheme.error)
                } else {
                    Text(nightsText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(effectivePlanColor)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    /// 「2泊3日の日程になります」。選んだ日付が何日間になるのかを、
    /// その場で返す
    private var nightsText: String {
        let nights = Calendar.current.dayDifference(from: startDate, to: endDate)
        return nights <= 0 ? "日帰りの予定です" : "\(nights)泊\(nights + 1)日の日程になります"
    }

    private var dailyDateTimeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeading("日時", question: "いつですか？")

            VStack(spacing: 0) {
                dateField(.dailyDate, label: "日付", date: $dailyDate)

                Divider()
                    .background(uiAccentColor.opacity(0.08))
                    .padding(.leading, 16)

                dateField(.dailyTime, label: "時間", date: $dailyTime, components: .hourAndMinute)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardSurface)
            )
            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.06), radius: 12, x: 0, y: 5)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private var cardSurface: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    /// 日付そのものを大きく出す。ラベルは小さく上に添える。
    ///
    /// 標準の compact ピッカーは自前の表示と二重になるため置いていない
    /// （隠そうとすると、灰色の日付ボタンがそのまま残る）。
    /// 行を押したらカレンダーがその場で開く形にする
    private func dateField(
        _ field: DateField,
        label: String,
        date: Binding<Date>,
        range: PartialRangeFrom<Date>? = nil,
        components: DatePickerComponents = .date
    ) -> some View {
        let isExpanded = expandedField == field

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    expandedField = isExpanded ? nil : field
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(uiAccentColor.opacity(0.5))

                        Text(fieldValueText(date.wrappedValue, components: components))
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(uiAccentColor)

                        if components == .date {
                            Text(Self.weekdayFormatter.string(from: date.wrappedValue))
                                .font(.system(size: 12))
                                .foregroundColor(uiAccentColor.opacity(0.5))
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isExpanded ? effectivePlanColor : uiAccentColor.opacity(0.35))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Group {
                    if components == .hourAndMinute {
                        DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                    } else if let range {
                        DatePicker("", selection: date, in: range, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    } else {
                        DatePicker("", selection: date, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                }
                .labelsHidden()
                .tint(effectivePlanColor)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .transition(.opacity)
            }
        }
    }

    /// 開いているカレンダーは常に1つだけにする
    private enum DateField {
        case start, end, dailyDate, dailyTime
    }

    private func fieldValueText(_ date: Date, components: DatePickerComponents) -> String {
        components == .hourAndMinute
            ? DateFormatter.japaneseTime.string(from: date)
            : Self.monthDayFormatter.string(from: date)
    }

    private static let monthDayFormatter = japaneseFormatter("M月d日")
    private static let weekdayFormatter = japaneseFormatter("EEEE")

    private static func japaneseFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = format
        return formatter
    }

    // MARK: - Step 2: Places
    private var step2Places: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeading(
                "場所",
                question: selectedPlanType == .outing ? "行きたい場所は\nありますか？" : "行く場所は\nありますか？",
                sub: selectedPlanType == .outing ? "いくつでも追加できます。" : "あとから追加もできます。"
            )

            ScrollView {
                VStack(spacing: 10) {
                    if places.isEmpty {
                        HStack {
                            Image(systemName: "mappin.slash")
                                .foregroundColor(uiAccentColor.opacity(0.4))
                            Text("まだ場所が追加されていません")
                                .font(.subheadline)
                                .foregroundColor(uiAccentColor.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(uiAccentColor.opacity(0.07))
                        .cornerRadius(16)
                    } else {
                        ForEach(places) { place in
                            placeRow(place)
                        }
                    }

                    Button(action: { showMapPicker = true }) {
                        Label("場所を追加", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(uiAccentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(effectivePlanColor.opacity(0.25))
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func placeRow(_ place: PlannedPlace) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(effectivePlanColor)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.headline)
                    .foregroundColor(uiAccentColor)
                if let address = place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(uiAccentColor.opacity(0.6))
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(action: { deletePlace(place) }) {
                Image(systemName: "trash")
                    .foregroundColor(themeManager.currentTheme.error)
                    .padding(8)
            }
        }
        .padding(16)
        .background(uiAccentColor.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Step 3: Description + Link (daily only, optional)
    private var step3DescriptionAndLink: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeading(
                    "内容とリンク",
                    question: "何をしますか？",
                    sub: "どちらも任意です。このまま保存できます。"
                )

                ZStack(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("例：英語の課題をやる、ジムで30分走る")
                            .foregroundColor(uiAccentColor.opacity(0.3))
                            .font(.body)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $description)
                        .font(.body)
                        .foregroundColor(uiAccentColor)
                        .frame(height: 140)
                        .scrollContentBackground(.hidden)
                        .focused($isDescriptionFocused)
                }
                .padding(16)
                .background(uiAccentColor.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .foregroundColor(uiAccentColor.opacity(0.6))
                    ZStack(alignment: .leading) {
                        if linkURL.isEmpty {
                            Text("https://example.com")
                                .foregroundColor(uiAccentColor.opacity(0.3))
                        }
                        TextField("", text: $linkURL)
                            .foregroundColor(uiAccentColor)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                }
                .padding(20)
                .background(uiAccentColor.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal, 20)

                Spacer(minLength: 20)
            }
        }
    }

    // MARK: - History Picker View
    private var historyPickerView: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(historyEntries) { entry in
                            Button(action: { applyHistory(entry) }) {
                                historyRow(entry)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("履歴から作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { showHistoryPicker = false }
                        .foregroundColor(uiAccentColor)
                }
            }
        }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        let color = planColorFor(entry.plan.planType)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: entry.plan.planType == .daily ? "house.fill" : "figure.walk")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.plan.title)
                    .font(.headline)
                    .foregroundColor(uiAccentColor)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text("\(entry.count)回")
                    Text("最終 \(DateFormatter.japaneseMonthDay.string(from: entry.lastUsed))")
                    if !entry.plan.places.isEmpty {
                        Text("場所\(entry.plan.places.count)件")
                    }
                }
                .font(.caption)
                .foregroundColor(uiAccentColor.opacity(0.6))
            }

            Spacer(minLength: 0)

            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(color)
        }
        .padding(14)
        .background(uiAccentColor.opacity(0.1))
        .cornerRadius(16)
    }

    /// 履歴の内容をフォームに流し込み、日付ステップから再開する
    private func applyHistory(_ entry: HistoryEntry) {
        let source = entry.plan
        let calendar = Calendar.current
        let today = Date()

        selectedPlanType = source.planType
        title = source.title
        places = source.places
        description = source.description ?? ""
        linkURL = source.linkURL ?? ""

        // 日付は引き継がない（毎回変わるため）
        startDate = today
        endDate = today
        dailyDate = today

        // 時刻は時分だけ引き継ぎ、今日の日付上に組み立て直す
        if let previousTime = source.time {
            let components = calendar.dateComponents([.hour, .minute], from: previousTime)
            dailyTime = calendar.date(
                bySettingHour: components.hour ?? 0,
                minute: components.minute ?? 0,
                second: 0,
                of: today
            ) ?? today
        }

        showHistoryPicker = false
        isGoingForward = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = 1   // 種別とタイトルは決まっているので日付ステップへ
        }
    }

    // MARK: - Map Picker View
    private var mapPickerView: some View {
        NavigationView {
            ZStack {
                Map(position: $mapPosition, selection: $selectedMapResult) {
                    ForEach(searchResults, id: \.self) { result in
                        Marker(item: result)
                            .tint(themeManager.currentTheme.error)
                    }
                }
                .safeAreaInset(edge: .top) { mapSearchBarView }
                .safeAreaInset(edge: .bottom) {
                    if let selectedResult = selectedMapResult {
                        mapSelectedResultDetailView(selectedResult)
                    }
                }
                .onMapCameraChange { context in
                    mapVisibleRegion = context.region
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { showMapPicker = false }
                }
            }
        }
    }

    private var mapSearchBarView: some View {
        TextField("場所を検索", text: $searchText)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .onSubmit { Task { await performMapSearch() } }
    }

    private func performMapSearch() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        // 施設だけに絞ると住所で検索できないため住所も対象にする
        request.resultTypes = [.pointOfInterest, .address]

        // 表示中の狭い範囲に限定すると遠方の場所が一切ヒットしない。
        // 近くを優先しつつ遠方も拾えるよう、中心だけ引き継いで範囲は広く取る
        request.region = MKCoordinateRegion(
            center: mapVisibleRegion?.center
                ?? CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
        )
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            searchResults = response.mapItems
            if let first = searchResults.first {
                withAnimation {
                    mapPosition = .region(MKCoordinateRegion(
                        center: first.placemark.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
            searchText = ""
        } catch {}
    }

    private func mapSelectedResultDetailView(_ result: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name ?? "名称なし")
                        .font(.title2.weight(.bold))
                    if let category = result.pointOfInterestCategory?.rawValue {
                        Text(category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let address = result.placemark.title {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(themeManager.currentTheme.error)
                        .font(.title3)
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let phoneNumber = result.phoneNumber {
                HStack(spacing: 8) {
                    Image(systemName: "phone.circle.fill")
                        .foregroundStyle(themeManager.currentTheme.success)
                        .font(.title3)
                    Text(phoneNumber).font(.subheadline)
                    Spacer()
                    Button {
                        if let url = URL(string: "tel:\(phoneNumber.replacingOccurrences(of: " ", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("電話").font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(themeManager.currentTheme.success)
                            .foregroundStyle(.white).cornerRadius(8)
                    }
                }
            }

            if let url = result.url {
                HStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(themeManager.currentTheme.actionFill)
                        .font(.title3)
                    Text(url.host ?? "Website").font(.subheadline).lineLimit(1)
                    Spacer()
                    Button { UIApplication.shared.open(url) } label: {
                        Text("開く").font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(themeManager.currentTheme.actionFill)
                            .foregroundStyle(.white).cornerRadius(8)
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button { result.openInMaps() } label: {
                    Label("経路", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(themeManager.currentTheme.actionFill.opacity(0.12))
                        .foregroundStyle(themeManager.currentTheme.actionFill).cornerRadius(10)
                }
                Button { addPlaceFromMapResult(result) } label: {
                    Label("追加", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(themeManager.currentTheme.adaptiveText(for: colorScheme).opacity(0.12))
                        .foregroundStyle(themeManager.currentTheme.adaptiveText(for: colorScheme)).cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: -4)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func addPlaceFromMapResult(_ result: MKMapItem) {
        places.append(PlannedPlace(
            name: result.name ?? "名称不明",
            latitude: result.placemark.coordinate.latitude,
            longitude: result.placemark.coordinate.longitude,
            address: result.placemark.title
        ))
        selectedMapResult = nil
        showMapPicker = false
    }

    // MARK: - Helper Methods
    private func deletePlace(_ place: PlannedPlace) {
        places.removeAll { $0.id == place.id }
    }

    /// 未入力の内容は nil として保存する（詳細画面で空欄が表示されないように）
    private var trimmedDescription: String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// スキームが省略されたURLに https:// を補完する
    private func normalizedLinkURL() -> String? {
        let trimmed = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    private func savePlan() {
        let plan: Plan
        if selectedPlanType == .outing {
            plan = Plan(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: startDate,
                endDate: endDate < startDate ? startDate : endDate,
                places: places,
                planType: .outing
            )
        } else {
            plan = Plan(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: dailyDate,
                endDate: dailyDate,
                places: places,
                planType: .daily,
                time: dailyTime,
                description: trimmedDescription,
                linkURL: normalizedLinkURL()
            )
        }
        onSave(plan)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Preview
#Preview {
    AddPlanView { _ in }
}
