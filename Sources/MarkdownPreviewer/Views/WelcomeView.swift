import SwiftUI

struct WelcomeView: View {
    let openAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Markdown Previewer")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("A fast macOS reading surface for large Markdown files, Mermaid diagrams, and multi-file tab workflows.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: openAction) {
                    Text("Open Markdown files")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressScaleButtonStyle())

                Text("Command-O")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.mutedInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.panelSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.line.opacity(0.6), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(title: "Large-file aware", detail: "Reads files through a memory-mapped loader before rendering so opening huge notes stays responsive.")
                FeatureRow(title: "Mermaid built in", detail: "Mermaid code fences render directly inside the preview pane without extra setup.")
                FeatureRow(title: "Tab deduplication", detail: "Opening an already-visible file focuses its tab instead of creating another copy.")
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.panelSurface)
    }
}

private struct FeatureRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
