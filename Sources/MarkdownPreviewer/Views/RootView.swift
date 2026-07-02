import SwiftUI

struct RootView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        HSplitView {
            if !controller.isZenModeEnabled {
                TabSidebarView(controller: controller)
                    .frame(minWidth: 250, idealWidth: 290, maxWidth: 360)
            }

            HSplitView {
                PreviewPaneView(controller: controller)
                    .frame(minWidth: 640)

                if !controller.isZenModeEnabled {
                    TableOfContentsSidebarView(controller: controller) { anchorID in
                        controller.scrollSelectedTab(to: anchorID)
                    }
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: controller.isZenModeEnabled)
        .background(Theme.windowCanvas)
        .frame(minWidth: 1100, minHeight: 720)
        .onAppear {
            controller.loadLaunchArgumentsIfNeeded()
        }
    }
}
