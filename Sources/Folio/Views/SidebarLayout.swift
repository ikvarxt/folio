import AppKit
import SwiftUI

enum SidebarMetrics {
    static let tabWidthRange: ClosedRange<CGFloat> = 200...320
    static let outlineWidthRange: ClosedRange<CGFloat> = 190...300
    static let previewMinWidth: CGFloat = 460

    /// Visible hairline plus the padding that makes it grabbable.
    static let dividerHitWidth: CGFloat = 8
}

/*
 * On-screen sidebar widths for one window size.
 *
 * Only the displayed widths bend when the window gets narrow; the stored
 * preference keeps whatever the reader dragged to, so widening the window puts
 * the sidebars back where they were instead of leaving them at the squeezed
 * size. Below the enforced 900pt window minimum there is nothing left to give
 * and the preview absorbs the shortfall.
 */
struct SidebarLayout: Equatable {
    let tabWidth: CGFloat
    let outlineWidth: CGFloat

    init(availableWidth: CGFloat, tabWidth: CGFloat, outlineWidth: CGFloat) {
        let requested = tabWidth + outlineWidth
        let dividerAllowance = requested > 0 ? SidebarMetrics.dividerHitWidth * 2 : 0
        let spare = availableWidth - SidebarMetrics.previewMinWidth - dividerAllowance

        guard requested > 0, spare < requested else {
            self.tabWidth = tabWidth
            self.outlineWidth = outlineWidth
            return
        }

        // Shrink both by the same proportion so neither sidebar collapses while
        // the other keeps its full width.
        let scale = max(0, spare) / requested

        self.tabWidth = Self.shrink(tabWidth, by: scale, floor: SidebarMetrics.tabWidthRange.lowerBound)
        self.outlineWidth = Self.shrink(outlineWidth, by: scale, floor: SidebarMetrics.outlineWidthRange.lowerBound)
    }

    private static func shrink(_ width: CGFloat, by scale: CGFloat, floor: CGFloat) -> CGFloat {
        min(max(width * scale, floor), width)
    }
}

/// Drag handle sitting between a sidebar and the preview.
struct SidebarDivider: View {
    /// `1` when the sidebar is to the left of the handle, `-1` when it is to the
    /// right, so dragging away from the sidebar always widens it.
    let growthDirection: CGFloat
    let widthRange: ClosedRange<CGFloat>
    /// The width actually on screen, which is what a drag has to continue from:
    /// starting at `width` instead would make the handle jump whenever
    /// `SidebarLayout` had shrunk the sidebar to fit the window.
    let displayedWidth: CGFloat

    @Binding var width: Double

    @State private var widthAtDragStart: CGFloat?
    @State private var isHovering = false
    @State private var isCursorPushed = false

    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(width: 1)
            .frame(width: SidebarMetrics.dividerHitWidth)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onHover { hovering in
                isHovering = hovering
                syncCursor()
            }
            /*
             * Zen mode tears this view out of the hierarchy, which can happen
             * while the resize cursor is pushed. Without this the whole window
             * keeps showing a resize cursor with no divider left to drag.
             */
            .onDisappear {
                isHovering = false
                widthAtDragStart = nil
                syncCursor()
            }
            .accessibilityHidden(true)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = widthAtDragStart ?? displayedWidth
                widthAtDragStart = start
                syncCursor()

                let dragged = start + value.translation.width * growthDirection
                width = Double(min(max(dragged, widthRange.lowerBound), widthRange.upperBound))
            }
            .onEnded { _ in
                widthAtDragStart = nil
                syncCursor()
            }
    }

    /*
     * `NSCursor` is a stack, so every push needs exactly one pop. Deriving the
     * wanted state from hover and drag and reconciling in one place keeps the
     * two from getting out of step when a drag ends outside the handle.
     */
    private func syncCursor() {
        let wantsResizeCursor = isHovering || widthAtDragStart != nil

        if wantsResizeCursor, !isCursorPushed {
            isCursorPushed = true
            NSCursor.resizeLeftRight.push()
        } else if !wantsResizeCursor, isCursorPushed {
            isCursorPushed = false
            NSCursor.pop()
        }
    }
}
