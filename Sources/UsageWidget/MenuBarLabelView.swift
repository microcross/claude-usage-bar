import SwiftUI
import UsageWidgetUI

// Two template-image donut rings: session (left) and weekly (right).
// Rendered via Core Graphics because SwiftUI Shapes don't survive
// MenuBarExtra's template-image flattening (see MenuBarIcon).
struct MenuBarLabelView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        Image(nsImage: MenuBarIcon.image(
            session: model.session?.utilizationPct,
            weekly: model.weekly?.utilizationPct
        ))
    }
}
