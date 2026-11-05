import WidgetKit
import SwiftUI

@main
struct GoTravelWidgetBundle: WidgetBundle {
    var body: some Widget {
        GoTravelWidget()
        // 旅行中のライブアクティビティ（ロック画面・Dynamic Island・Apple Watch）
        TravelLiveActivityWidget()
    }
}
