import SwiftUI
import PDFKit

/// 旅のしおりを作る画面（Travory Pro）。デザインと入れるものを選び、PDF を作って見せる
struct TravelBookletView: View {
    let plan: TravelPlan

    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var style: TravelBooklet.Style = .simple
    @State private var options = TravelBooklet.Options()
    @State private var isWorking = false
    @State private var output: TravelBookletRenderer.Output?
    @State private var errorMessage: String?

    private var pageCount: Int {
        TravelBooklet.pages(for: plan, options: options, userId: authVM.userId).count
    }

    private var hasMaps: Bool {
        plan.daySchedulesInRange.flatMap(\.scheduleItems).contains(where: \.hasCoordinate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(TravelBooklet.Style.allCases) { candidate in
                                styleCard(candidate)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("デザイン")
                } footer: {
                    Text(style.summary)
                }

                Section {
                    Toggle("表紙", isOn: $options.includesCover)
                    Toggle("日程", isOn: $options.includesSchedule)
                    if hasMaps {
                        Toggle("日ごとの地図", isOn: $options.includesMaps)
                            .disabled(!options.includesSchedule)
                    }
                    Toggle("持ち物・お土産", isOn: $options.includesPacking)
                    Toggle("費用", isOn: $options.includesCosts)
                    Toggle("メモ", isOn: $options.includesMemos)
                } header: {
                    Text("入れるもの")
                } footer: {
                    Text("A5 の冊子・全\(pageCount)ページ。お土産は「みんなに見せる」品だけ、メモは「みんなで見る」メモだけが入ります。予約番号は入りません。")
                }
            }
            .navigationTitle("旅のしおり")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("作る") { Task { await make() } }
                            .fontWeight(.semibold)
                            .disabled(pageCount == 0)
                    }
                }
            }
            .navigationDestination(item: $output) { output in
                BookletPreviewView(output: output)
            }
            .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil },
                                                            set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    /// デザインの見本（表紙を小さくしたもの）
    private func styleCard(_ candidate: TravelBooklet.Style) -> some View {
        let context = BookletContext(plan: plan, style: candidate,
                                     palette: BookletPalette.make(candidate, theme: themeManager.currentTheme),
                                     userId: authVM.userId, coverImage: TravelBookletRenderer.coverImage(for: plan),
                                     maps: [:], pageCount: 1)
        let scale: CGFloat = 0.26
        return Button {
            style = candidate
        } label: {
            VStack(spacing: 6) {
                BookletPageView(page: .cover, pageNumber: 1, context: context)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: TravelBooklet.pageSize.width * scale,
                           height: TravelBooklet.pageSize.height * scale, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(style == candidate ? Color.accentColor : Color.secondary.opacity(0.3),
                                lineWidth: style == candidate ? 3 : 1))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                Text(candidate.name)
                    .font(.caption.weight(style == candidate ? .semibold : .regular))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("デザイン：\(candidate.name)")
        .accessibilityAddTraits(style == candidate ? .isSelected : [])
    }

    private func make() async {
        isWorking = true
        defer { isWorking = false }
        do {
            output = try await TravelBookletRenderer.render(plan: plan, options: options, style: style,
                                                            theme: themeManager.currentTheme, userId: authVM.userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// 作ったしおりを見て、送る・印刷する
private struct BookletPreviewView: View {
    let output: TravelBookletRenderer.Output

    var body: some View {
        PDFPreview(url: output.url)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("\(output.pageCount)ページ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: output.url) {
                        Label("送る・印刷", systemImage: "square.and.arrow.up")
                    }
                }
            }
    }
}

private struct PDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
