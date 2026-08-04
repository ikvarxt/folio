import SwiftUI

struct RootView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        HSplitView {
            if !controller.isZenModeEnabled {
                TabSidebarView(controller: controller)
                    .frame(minWidth: 200, idealWidth: 240, maxWidth: 320)
            }

            HSplitView {
                PreviewPaneView(controller: controller)
                    .frame(minWidth: 460)

                if !controller.isZenModeEnabled {
                    TableOfContentsSidebarView(controller: controller) { anchorID in
                        controller.scrollSelectedTab(to: anchorID)
                    }
                    .frame(minWidth: 190, idealWidth: 220, maxWidth: 300)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: controller.isZenModeEnabled)
        .background(Theme.windowCanvas)
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            controller.loadLaunchArgumentsIfNeeded()
        }
    }
}
