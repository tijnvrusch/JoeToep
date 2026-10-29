import SwiftUI

/// V15: resolved visual settings, passed down through the environment.
struct JoeToepTheme: Equatable {
    var style: ThemeStyle = .youtube
    var accent: Color = Color(hex: 0xFF3B30)
    var iconVariant: IconVariant = .outline
    var iconWeight: IconWeightChoice = .regular
    var rendering: IconRendering = .monochrome
    var animationStyle: AnimationStyle = .smooth
    var tabShape: TabShape = .rounded
    var tabClose: TabCloseButtons = .hover
    var tabText: TabTextSize = .regular
    var showTabIcons = true
    var density: ToolbarDensity = .compact

    var animation: Animation? { animationStyle.animation }
    var background: Color { style.background }
    var foreground: Color { style.foreground }
    var secondary: Color { style.secondary }
    var tabHeight: CGFloat { max(30, 27 * density.scale + 3) }
    var tabCornerRadius: CGFloat {
        switch tabShape {
        case .rounded: 8
        case .pill: tabHeight / 2
        case .square, .underline: 2
        }
    }
}

private struct JoeToepThemeKey: EnvironmentKey { static let defaultValue = JoeToepTheme() }
extension EnvironmentValues {
    var joeToepTheme: JoeToepTheme {
        get { self[JoeToepThemeKey.self] }
        set { self[JoeToepThemeKey.self] = newValue }
    }
}

extension AppSettings {
    var theme: JoeToepTheme {
        JoeToepTheme(style: themeStyle, accent: accentColor, iconVariant: iconVariant, iconWeight: iconWeight,
                     rendering: iconRendering, animationStyle: animationStyle, tabShape: tabShape,
                     tabClose: tabCloseButtons, tabText: tabTextSize, showTabIcons: showTabIcons, density: toolbarDensity)
    }
}

/// Applies the chosen icon style (variant, weight, rendering, accent) to an SF Symbol.
struct ThemedIcon: ViewModifier {
    let theme: JoeToepTheme
    let size: CGFloat
    var active = false
    var enabled = true
    @ViewBuilder
    func body(content: Content) -> some View {
        let styled = content
            .font(.system(size: size, weight: theme.iconWeight.weight))
            .symbolVariant(active ? theme.iconVariant.variants.fill : theme.iconVariant.variants)
            .opacity(enabled ? 1 : 0.35)
        switch theme.rendering {
        case .monochrome:
            styled.symbolRenderingMode(.monochrome).foregroundStyle(active ? theme.accent : theme.foreground)
        case .hierarchical:
            styled.symbolRenderingMode(.hierarchical).foregroundStyle(active ? theme.accent : theme.foreground)
        case .accent:
            styled.symbolRenderingMode(.monochrome).foregroundStyle(theme.accent)
        case .palette:
            styled.symbolRenderingMode(.palette).foregroundStyle(theme.accent, theme.foreground.opacity(0.75))
        }
    }
}

extension View {
    func themedIcon(_ theme: JoeToepTheme, size: CGFloat, active: Bool = false, enabled: Bool = true) -> some View {
        modifier(ThemedIcon(theme: theme, size: size, active: active, enabled: enabled))
    }
}
