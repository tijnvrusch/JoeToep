import SwiftUI

extension View {
    @ViewBuilder
    func joeToepGlass<S: Shape>(in shape: S, enabled: Bool = true) -> some View {
        if !enabled {
            self.background(Color(white: 0.085), in: shape)
        } else if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.09), lineWidth: 0.5))
        }
    }
}
struct JoeToepIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .foregroundStyle(configuration.isPressed ? Color.red : Color.primary)
            .background(configuration.isPressed ? Color.white.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }
}
