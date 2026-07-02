import SwiftUI

extension DocumentTab.FileSyncStatus {
    var indicatorColor: Color {
        switch self {
        case .upToDate:
            return Theme.line
        case .changedOnDisk:
            return Theme.signalChanged
        case .missingFromDisk:
            return Theme.signalMissing
        }
    }

    var summaryText: String? {
        switch self {
        case .upToDate:
            return nil
        case .changedOnDisk:
            return "Changed on disk"
        case .missingFromDisk:
            return "Missing on disk"
        }
    }

    var reloadHelpText: String {
        switch self {
        case .upToDate:
            return "Reload the current tab"
        case .changedOnDisk:
            return "The file changed on disk. Reload to preview the latest content."
        case .missingFromDisk:
            return "The file moved or was deleted. Reload to refresh the preview state."
        }
    }
}

struct FileSyncIndicatorLight: View {
    let status: DocumentTab.FileSyncStatus
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(status.indicatorColor)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(status.indicatorColor.opacity(0.2), lineWidth: max(1, size * 0.75))
                    .scaleEffect(1.7)
            )
            .accessibilityHidden(true)
    }
}

struct FileSyncStatusLine: View {
    let status: DocumentTab.FileSyncStatus

    var body: some View {
        if let summaryText = status.summaryText {
            HStack(spacing: 8) {
                FileSyncIndicatorLight(status: status, size: 7)
                Text(summaryText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(status.indicatorColor)
                    .lineLimit(1)
            }
        }
    }
}
