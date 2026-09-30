import AppKit
import SwiftUI

enum Theme {
    /*
     * Every token is a dynamic NSColor rather than a fixed one, so a system
     * appearance switch repaints the chrome without any view observing it. The
     * alternative — reading @Environment(\.colorScheme) at each call site — puts
     * a branch in every view for a value that never differs between them.
     */

    // The preview pane shares preview.css's paper so the page and its chrome
    // read as one surface; the sidebars sit one step darker to recede.
    static let panelSurface = dynamic(light: 0xFCFBF8, dark: 0x1C1B19)
    static let sidebarSurface = dynamic(light: 0xF4F2ED, dark: 0x171614)
    static let rowHover = dynamic(light: 0xECE9E3, dark: 0x201E1B)
    static let rowSelected = dynamic(light: 0xE5E1D9, dark: 0x2A2825)

    static let line = dynamic(light: 0xE6E2DA, dark: 0x33302B)
    static let ink = dynamic(light: 0x26231F, dark: 0xE6E1D8)
    static let inkSoft = dynamic(light: 0x57524A, dark: 0xBDB6AB)
    static let mutedInk = dynamic(light: 0x8A8378, dark: 0x8C857A)

    /*
     * The accent lightens after dark instead of keeping its daylight value,
     * which would fail contrast against every dark surface here. Lightening it
     * flips which label colour it can carry, which is what `onAccent` tracks.
     */
    static let accent = dynamic(light: 0xA2622F, dark: 0xDC9A64)
    static let accentSoft = dynamic(light: 0xF1E6D9, dark: 0x3A2C20)
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x1C1B19)
    static let signalChanged = dynamic(light: 0xB97836, dark: 0xE0A44E)
    static let signalMissing = dynamic(light: 0xB3493E, dark: 0xE8746A)

    /// Committed radius scale. Pick from these rather than inlining values.
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
    }

    /// Committed spacing ladder. Outer container padding matches inner gap.
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
    }

    /// Minimum comfortable hit area for a control.
    static let controlHitSize: CGFloat = 28

    /// Shared by the toolbar and both sidebar headers so their baselines line up.
    static let headerHeight: CGFloat = 44

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        let lightColor = NSColor(hex: light)
        let darkColor = NSColor(hex: dark)

        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet square icon button used across the sidebars and toolbar.
struct IconButtonStyle: ButtonStyle {
    var isProminent = false
    var tint = Theme.accent
    // Off for a label that sizes itself, such as an icon with a count beside it.
    var isSquare = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isProminent ? tint : Theme.inkSoft)
            .frame(
                width: isSquare ? Theme.controlHitSize : nil,
                height: isSquare ? Theme.controlHitSize : nil
            )
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(background(for: configuration))
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func background(for configuration: Configuration) -> Color {
        if isProminent {
            return tint.opacity(configuration.isPressed ? 0.24 : 0.15)
        }

        return configuration.isPressed ? Theme.line.opacity(0.4) : .clear
    }
}

/// Quiet section label at the top of a sidebar.
struct SidebarHeading: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.mutedInk)
    }
}
