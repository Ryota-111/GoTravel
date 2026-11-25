import UIKit

/// 画面の文に入れる端末の呼び名（3.8）。
/// iPad で「iPhone のカレンダー」と出ていたため、iPad では「iPad」にする
enum DeviceWord {
    static var name: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }
}
