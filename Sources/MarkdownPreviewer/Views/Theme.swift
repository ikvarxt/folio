import SwiftUI

enum Theme {
    static let windowCanvas = Color(red: 0.961, green: 0.952, blue: 0.932)
    static let sidebarSurface = Color(red: 0.934, green: 0.923, blue: 0.899)
    static let panelSurface = Color(red: 0.985, green: 0.982, blue: 0.972)
    static let line = Color(red: 0.835, green: 0.807, blue: 0.764)
    static let ink = Color(red: 0.192, green: 0.181, blue: 0.161)
    static let mutedInk = Color(red: 0.462, green: 0.434, blue: 0.389)
    static let accent = Color(red: 0.686, green: 0.431, blue: 0.242)
    static let accentSoft = Color(red: 0.938, green: 0.880, blue: 0.816)
    static let signalChanged = Color(red: 0.724, green: 0.470, blue: 0.211)
    static let signalMissing = Color(red: 0.702, green: 0.286, blue: 0.243)
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
