import AppKit
import SwiftUI

struct PreviewPaneView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Group {
            if let tab = controller.selectedTab {
                ObservedPreviewSurface(controller: controller, tab: tab)
            } else {
                WelcomeView(openAction: controller.openPanel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.panelSurface)
    }
}

private struct ObservedPreviewSurface: View {
    @ObservedObject var controller: AppController
    @ObservedObject var tab: DocumentTab

    private var outdatedCount: Int {
        controller.outdatedTabs.count
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()
                .overlay(Theme.line)

            ZStack(alignment: .top) {
                PreviewWebView(controller: controller, tab: tab)
                    .background(Theme.panelSurface)

                if tab.isLoading {
                    RenderProgressBar()
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if tab.needsReloadPrompt {
                        FileSyncIndicatorLight(status: tab.fileSyncStatus)
                    }
                }

                HStack(spacing: Theme.Spacing.sm) {
                    Text(tab.fileDetailsText)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mutedInk)
                        .lineLimit(1)

                    if tab.needsReloadPrompt {
                        FileSyncStatusLine(status: tab.fileSyncStatus)
                    }
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button(action: controller.toggleAutoReload) {
                Image(systemName: controller.isAutoReloadEnabled ? "bolt.fill" : "bolt.slash")
            }
            .buttonStyle(IconButtonStyle(isProminent: controller.isAutoReloadEnabled))
            .help(controller.isAutoReloadEnabled
                ? "Auto-reload is on: saving the file updates this preview"
                : "Auto-reload is off: press ⌘R after saving")
            .accessibilityLabel(controller.isAutoReloadEnabled ? "Disable auto-reload" : "Enable auto-reload")

            reloadButton

            Button(action: controller.revealSelectedInFinder) {
                Image(systemName: "folder")
            }
            .buttonStyle(IconButtonStyle())
            .help("Reveal this file in Finder")
            .accessibilityLabel("Reveal in Finder")

            Button(action: controller.toggleZenMode) {
                Image(systemName: controller.isZenModeEnabled
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(IconButtonStyle(isProminent: controller.isZenModeEnabled))
            .help(controller.isZenModeEnabled ? "Exit zen mode (⌘Z)" : "Hide both sidebars (⌘Z)")
            .accessibilityLabel(controller.isZenModeEnabled ? "Exit zen mode" : "Enter zen mode")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.panelSurface)
    }

    /*
     * One reload control for the whole session: it reports how many open files
     * are stale, not just whether the visible one is, because ⌘R refreshes all
     * of them.
     */
    private var reloadButton: some View {
        Button(action: { controller.reloadOutdatedTabs() }) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))

                if outdatedCount > 0 {
                    Text("\(outdatedCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
            }
            .frame(height: Theme.controlHitSize)
            .padding(.horizontal, outdatedCount > 0 ? Theme.Spacing.sm : 0)
            .frame(minWidth: Theme.controlHitSize)
        }
        .buttonStyle(
            ReloadButtonStyle(
                isProminent: outdatedCount > 0,
                tint: tab.fileSyncStatus.indicatorColor
            )
        )
        .help(reloadHelpText)
        .accessibilityLabel(reloadHelpText)
    }

    private var reloadHelpText: String {
        switch outdatedCount {
        case 0:
            return "Re-render the current file (⌘R)"
        case 1:
            return "1 open file changed on disk. Reload it (⌘R)"
        default:
            return "\(outdatedCount) open files changed on disk. Reload them all (⌘R)"
        }
    }
}

private struct ReloadButtonStyle: ButtonStyle {
    var isProminent: Bool
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isProminent ? tint : Theme.inkSoft)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(fill(for: configuration))
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func fill(for configuration: Configuration) -> Color {
        if isProminent {
            return tint.opacity(configuration.isPressed ? 0.26 : 0.16)
        }

        return configuration.isPressed ? Theme.line.opacity(0.4) : .clear
    }
}

/*
 * A hairline at the top of the preview rather than a floating badge: rendering
 * a large file should not put a translucent panel on top of the text being read.
 */
private struct RenderProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private let height: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = proxy.size.width
            let segmentWidth = max(80, trackWidth * 0.28)

            Rectangle()
                .fill(Theme.accent.opacity(reduceMotion ? 0.5 : 0.85))
                .frame(width: reduceMotion ? trackWidth : segmentWidth, height: height)
                .offset(x: offset(trackWidth: trackWidth, segmentWidth: segmentWidth))
                .animation(animation, value: isAnimating)
        }
        .frame(height: height)
        .background(Theme.accent.opacity(0.12))
        .accessibilityLabel("Rendering")
        .onAppear {
            isAnimating = true
        }
    }

    private func offset(trackWidth: CGFloat, segmentWidth: CGFloat) -> CGFloat {
        guard !reduceMotion else {
            return 0
        }

        return isAnimating ? trackWidth - segmentWidth : 0
    }

    private var animation: Animation? {
        guard !reduceMotion else {
            return nil
        }

        return .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
    }
}
