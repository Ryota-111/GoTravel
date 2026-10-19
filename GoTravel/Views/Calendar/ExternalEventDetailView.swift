import SwiftUI
import EventKit
import EventKitUI

/// iPhone のカレンダーの予定の詳細（3.0）。iOS のカレンダーと同じ画面を出す。
///
/// Travory の予定ではないので、Travory の詳細画面は無い。押しても何も起きないと
/// 壊れているように見えるため、カレンダーアプリと同じ詳細（場所・メモ・通知など）を見られるようにする。
/// 自分のカレンダーの予定なら、ここから直すこともできる（祝日などは読むだけ）
struct ExternalEventDetailView: UIViewControllerRepresentable {
    let event: EKEvent
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = EKEventViewController()
        controller.event = event
        controller.allowsEditing = event.calendar.allowsContentModifications
        controller.allowsCalendarPreview = true
        controller.delegate = context.coordinator
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { _ in onDone() }
        )
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, EKEventViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            onDone()
        }
    }
}
