import AppKit
import SwiftUI

enum Theme {
    /*
     * Every token is a dynamic NSColor rather than a fixed one, so a system
     * appearance switch repaints the chrome without any view observing it. The
     * alternative — reading @Environment(\.colorScheme) at each call site — puts
     * a branch in every view for a value that never differs between them.
     */

    // Surfaces, warm cream rather than neutral grey. Lightness steps between
    // adjacent surfaces stay above 4% so nested panes stay distinguishable, and
    // the dark side keeps both the warm hue and that step size.
    static let windowCanvas = dynamic(light: 0xF4F2EC, dark: 0x1E1B18)
    static let sidebarSurface = dynamic(light: 0xEDEAE4, dark: 0x151311)
    static let panelSurface = dynamic(light: 0xFBFBF8, dark: 0x262220)
    static let rowHover = dynamic(light: 0xF6F4F0, dark: 0x221E1A)

    static let line = dynamic(light: 0xD7D0C6, dark: 0x453E36)
    static let ink = dynamic(light: 0x302D28, dark: 0xEDE7DE)
    static let inkSoft = dynamic(light: 0x524D45, dark: 0xC9C1B6)
    static let mutedInk = dynamic(light: 0x797266, dark: 0x9C9285)

    /*
     * The accent lightens after dark instead of keeping its daylight value: at
     * 0.19 relative luminance it would fail contrast against every dark surface
     * here. Lightening it flips which label colour it can carry, which is what
     * `onAccent` exists to track.
     */
    static let accent = dynamic(light: 0xA96838, dark: 0xE09A5F)
    static let accentSoft = dynamic(light: 0xF1E4D6, dark: 0x3A2A1D)
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x24201C)
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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isProminent ? tint : Theme.inkSoft)
            .frame(width: Theme.controlHitSize, height: Theme.controlHitSize)
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
