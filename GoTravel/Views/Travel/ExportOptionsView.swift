import SwiftUI

/// 書き出す前に、何を入れるかを選ぶ。画像とテキストで共通。
///
/// 日程・予約・持ち物をいつも全部出すと、渡したくないものまで含まれる。
/// とくに予約番号は扱いが違うので、形式ごとに既定を変えている。
struct ExportOptionsView: View {

    enum Format {
        case image
        case text

        var title: String {
            switch self {
            case .image: return "画像で送る"
            case .text: return "テキストで送る"
            }
        }

        /// 画像はSNSに上げられて出回りうるので、予約番号は既定で入れない。
        /// テキストは渡す相手を選んで送るものなので、既定で入れる
        var includesConfirmationNumbersByDefault: Bool {
            self == .text
        }

        var confirmationCaution: String {
            switch self {
            case .image: return "画像に残るので、渡す相手にご注意ください"
            case .text: return "渡す相手にご注意ください"
            }
        }
    }

    let plan: TravelPlan
    let format: Format
    let accentColor: Color
    /// 選んだ内容で作ったもの（画像またはテキスト）を返す
    let onExport: ([Any]) -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var includesSchedule = true
    @State private var includesReservations = true
    @State private var includesPacking = true
    @State private var includesConfirmationNumbers = false
    @State private var isRendering = false

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }

    private var scheduleItemCount: Int {
        plan.daySchedulesInRange.reduce(0) { $0 + $1.scheduleItems.count }
    }

    /// 予約と持ち物は1枚にまとめるので、どちらか入っていれば1枚
    private var hasExtrasPage: Bool {
        (includesReservations && !plan.reservations.isEmpty)
            || (includesPacking && !plan.packingItems.isEmpty)
    }

    private var pageCount: Int {
        (includesSchedule ? 1 : 0) + (hasExtrasPage ? 1 : 0)
    }

    /// テキストは1つにまとまるので、枚数ではなく有無だけ見る
    private var canExport: Bool {
        format == .text ? (includesSchedule || hasExtrasPage) : pageCount > 0
    }

    private var exportButtonTitle: String {
        guard canExport else { return "入れるものを選んでください" }
        return format == .text ? "テキストを書き出す" : "\(pageCount)枚を書き出す"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark
                    ? themeManager.currentTheme.backgroundDark
                    : themeManager.currentTheme.backgroundLight)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        options
                        noticeText
                        exportButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle(format.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                includesConfirmationNumbers = format.includesConfirmationNumbersByDefault
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(accent)
                }
            }
        }
    }

    private var options: some View {
        VStack(spacing: 0) {
            toggleRow("日程", detail: "\(plan.dayCount)日間・\(scheduleItemCount)件", isOn: $includesSchedule)

            Divider().padding(.leading, 14)

            toggleRow("予約", detail: "\(plan.reservations.count)件", isOn: $includesReservations)
                .disabled(plan.reservations.isEmpty)
                .opacity(plan.reservations.isEmpty ? 0.5 : 1)

            if includesReservations && !plan.reservations.isEmpty {
                Divider().padding(.leading, 32)

                Toggle(isOn: $includesConfirmationNumbers) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("予約番号も入れる")
                            .font(.subheadline)
                            .foregroundColor(textColor)
                        Text(format.confirmationCaution)
                            .font(.caption2)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }
                .tint(accent)
                .padding(.vertical, 12)
                .padding(.leading, 32)
                .padding(.trailing, 14)
            }

            Divider().padding(.leading, 14)

            toggleRow("持ち物リスト", detail: "\(plan.packingItems.count)件", isOn: $includesPacking)
                .disabled(plan.packingItems.isEmpty)
                .opacity(plan.packingItems.isEmpty ? 0.5 : 1)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
    }

    private func toggleRow(_ label: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        }
        .tint(accent)
        .padding(14)
    }

    @ViewBuilder
    private var noticeText: some View {
        if format == .image {
            Label("予約と持ち物は1枚にまとまります", systemImage: "info.circle")
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var exportButton: some View {
        Button(action: export) {
            Text(exportButtonTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(canExport
                                 ? ThemePreset.readableText(on: accent)
                                 : themeManager.currentTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canExport ? accent : accent.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
        .disabled(!canExport || isRendering)
    }

    @MainActor
    private func export() {
        guard canExport else { return }

        if format == .text {
            let text = TravelPlanTextExporter.fullItinerary(
                for: plan,
                includesSchedule: includesSchedule,
                includesReservations: includesReservations,
                includesPacking: includesPacking,
                includesConfirmationNumbers: includesConfirmationNumbers
            )
            onExport([text])
            dismiss()
            return
        }

        isRendering = true

        var images: [UIImage] = []

        if includesSchedule {
            let card = TravelPlanFullShareCard(plan: plan, accentColor: accentColor)
            if let image = render(card) { images.append(image) }
        }

        if hasExtrasPage {
            let card = TravelPlanExtrasShareCard(
                plan: plan,
                accentColor: accentColor,
                includesReservations: includesReservations,
                includesPacking: includesPacking,
                includesConfirmationNumbers: includesConfirmationNumbers
            )
            if let image = render(card) { images.append(image) }
        }

        isRendering = false
        guard !images.isEmpty else { return }
        onExport(images)
        dismiss()
    }

    @MainActor
    private func render<Content: View>(_ content: Content) -> UIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        return renderer.uiImage
    }
}
