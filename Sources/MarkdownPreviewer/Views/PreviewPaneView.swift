import AppKit
import SwiftUI

struct PreviewPaneView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let tab = controller.selectedTab {
                    ObservedPreviewSurface(controller: controller, tab: tab)
                } else {
                    topBar

                    Divider()
                        .overlay(Theme.line)

                    WelcomeView(openAction: controller.openPanel)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.panelSurface)
    }

    private var topBar: some View {
        HStack {
            Text("Ready")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Spacer()

            zenButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.panelSurface)
    }

    private var zenButton: some View {
        Button(action: controller.toggleZenMode) {
            Text(controller.isZenModeEnabled ? "Exit Zen" : "Zen")
        }
        .buttonStyle(ToolbarCapsuleButtonStyle())
    }
}

private struct ObservedPreviewSurface: View {
    @ObservedObject var controller: AppController
    @ObservedObject var tab: DocumentTab

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(tab.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)

                        if tab.needsReloadPrompt {
                            FileSyncIndicatorLight(status: tab.fileSyncStatus)
                        }
                    }

                    HStack(spacing: 10) {
                        Text(tab.fileDetailsText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.mutedInk)

                        if tab.needsReloadPrompt {
                            FileSyncStatusLine(status: tab.fileSyncStatus)
                        }
                    }
                }

                Spacer()

                Button(action: controller.revealSelectedInFinder) {
                    Label("Reveal", systemImage: "folder")
                }
                .buttonStyle(ToolbarCapsuleButtonStyle())

                Button(action: controller.reloadSelectedTab) {
                    Label("Reload", systemImage: tab.needsReloadPrompt ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                }
                .buttonStyle(
                    ToolbarCapsuleButtonStyle(
                        isProminent: tab.needsReloadPrompt,
                        tint: tab.fileSyncStatus.indicatorColor
                    )
                )
                .help(tab.fileSyncStatus.reloadHelpText)

                Button(action: controller.toggleZenMode) {
                    Text(controller.isZenModeEnabled ? "Exit Zen" : "Zen")
                }
                .buttonStyle(ToolbarCapsuleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Theme.panelSurface)

            Divider()
                .overlay(Theme.line)

            ZStack(alignment: .topTrailing) {
                PreviewWebView(controller: controller, tab: tab)
                    .background(Theme.panelSurface)

                if tab.isLoading {
                    ProgressView("Rendering…")
                        .controlSize(.small)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(16)
                }
            }
        }
    }
}

private struct ToolbarCapsuleButtonStyle: ButtonStyle {
    var isProminent = false
    var tint = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(isProminent ? tint : Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Group {
                    if isProminent {
                        tint.opacity(configuration.isPressed ? 0.2 : 0.13)
                    } else {
                        Theme.sidebarSurface.opacity(configuration.isPressed ? 0.92 : 1)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isProminent ? tint.opacity(0.42) : Theme.line.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: isProminent ? tint.opacity(0.1) : .clear, radius: 6, y: 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
