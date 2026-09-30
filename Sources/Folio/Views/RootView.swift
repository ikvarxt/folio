import SwiftUI

struct RootView: View {
    private enum PreferenceKey {
        static let tabSidebarWidth = "tabSidebarWidth"
        static let outlineSidebarWidth = "outlineSidebarWidth"
    }

    @ObservedObject var controller: AppController

    /*
     * Widest on a fresh install rather than the middle of the range: the file
     * list and the outline are the reason this is a three-pane window at all,
     * and a first-run reader has no idea the dividers can be dragged. Once one
     * is moved the choice sticks, including across a zen-mode round trip, which
     * removes the sidebars from the hierarchy entirely.
     */
    @AppStorage(PreferenceKey.tabSidebarWidth)
    private var tabSidebarWidth = Double(SidebarMetrics.tabWidthRange.upperBound)

    @AppStorage(PreferenceKey.outlineSidebarWidth)
    private var outlineSidebarWidth = Double(SidebarMetrics.outlineWidthRange.upperBound)

    var body: some View {
        GeometryReader { geometry in
            let layout = layout(forWindowWidth: geometry.size.width)

            HStack(spacing: 0) {
                if !controller.isZenModeEnabled {
                    TabSidebarView(controller: controller)
                        .frame(width: layout.tabWidth)

                    SidebarDivider(
                        growthDirection: 1,
                        widthRange: SidebarMetrics.tabWidthRange,
                        displayedWidth: layout.tabWidth,
                        width: $tabSidebarWidth
                    )
                }

                PreviewPaneView(controller: controller)
                    .frame(maxWidth: .infinity)

                if !controller.isZenModeEnabled {
                    SidebarDivider(
                        growthDirection: -1,
                        widthRange: SidebarMetrics.outlineWidthRange,
                        displayedWidth: layout.outlineWidth,
                        width: $outlineSidebarWidth
                    )

                    TableOfContentsSidebarView(controller: controller) { anchorID in
                        controller.scrollSelectedTab(to: anchorID)
                    }
                    .frame(width: layout.outlineWidth)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .animation(.easeInOut(duration: 0.18), value: controller.isZenModeEnabled)
        .background(Theme.sidebarSurface)
        .onDrop(of: [.fileURL, .plainText], isTargeted: $controller.isDropTargeted) { providers in
            controller.openDroppedItems(providers)
        }
        .overlay {
            if controller.isDropTargeted {
                DropTargetHighlight()
            }
        }
        .animation(.easeOut(duration: 0.12), value: controller.isDropTargeted)
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            controller.loadLaunchArgumentsIfNeeded()
        }
    }

    private func layout(forWindowWidth windowWidth: CGFloat) -> SidebarLayout {
        SidebarLayout(
            availableWidth: windowWidth,
            tabWidth: controller.isZenModeEnabled ? 0 : CGFloat(tabSidebarWidth),
            outlineWidth: controller.isZenModeEnabled ? 0 : CGFloat(outlineSidebarWidth)
        )
    }
}

private struct DropTargetHighlight: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
            .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.accentSoft.opacity(0.35))
            )
            .padding(Theme.Spacing.xs)
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}
