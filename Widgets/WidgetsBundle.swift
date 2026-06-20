import WidgetKit
import SwiftUI

@main
struct TodoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        if #available(iOS 16.1, *) {
            FocusActivityWidget()
        }
    }
}
