import SwiftUI

enum Theme {
    // Surfaces, warm cream rather than neutral grey. Lightness steps between
    // adjacent surfaces stay above 4% so nested panes stay distinguishable.
    static let windowCanvas = Color(red: 0.957, green: 0.947, blue: 0.926)
    static let sidebarSurface = Color(red: 0.931, green: 0.919, blue: 0.894)
    static let panelSurface = Color(red: 0.986, green: 0.983, blue: 0.974)
    static let rowHover = Color(red: 0.965, green: 0.958, blue: 0.943)

    static let line = Color(red: 0.842, green: 0.816, blue: 0.775)
    static let ink = Color(red: 0.188, green: 0.177, blue: 0.157)
    static let inkSoft = Color(red: 0.322, green: 0.301, blue: 0.269)
    static let mutedInk = Color(red: 0.474, green: 0.446, blue: 0.400)

    static let accent = Color(red: 0.663, green: 0.406, blue: 0.220)
    static let accentSoft = Color(red: 0.945, green: 0.895, blue: 0.838)
    static let signalChanged = Color(red: 0.724, green: 0.470, blue: 0.211)
    static let signalMissing = Color(red: 0.702, green: 0.286, blue: 0.243)

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
