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
    /// V16.2.1: interface text size factor (Settings › Appearance › Text size).
    var textScale: Double = 1
    /// Tab-title font: the chosen tab text size multiplied by the text-size factor.
    var tabFont: Font { .system(size: tabText.pointSize * textScale) }
    var showTabIcons = true
    var density: ToolbarDensity = .compact
    var animations: [AnimationKind: Animation] = [:]
    var visualizer: VisualizerStyle = .off
    var visualizerIntensity: Double = 0.6
    var visualizerConfig = VisualizerConfig()      // V17.1

    var animation: Animation? { anim(.tabs) }
    func anim(_ kind: AnimationKind) -> Animation? { animations[kind] }
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
                     tabClose: tabCloseButtons, tabText: tabTextSize, textScale: textScale, showTabIcons: showTabIcons, density: toolbarDensity,
                     animations: Dictionary(uniqueKeysWithValues: AnimationKind.allCases.compactMap { kind in animation(kind).map { (kind, $0) } }),
                     visualizer: visualizerStyle, visualizerIntensity: visualizerIntensity, visualizerConfig: visualizerConfig)
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


// MARK: - V16.2.1 text size

extension View {
    /// Applies the "Text size" setting to everything inside this view.
    /// - iPhone/iPad: SwiftUI's Dynamic Type sizes (the same scale as the system text-size
    ///   setting), so every text style (.body, .caption, …) grows or shrinks together.
    /// - Mac: macOS has no Dynamic Type, so we set the default font size (13 pt × factor) and
    ///   make controls bigger when the text is large.
    @ViewBuilder
    func joeToepTextScale(_ scale: Double) -> some View {
        #if os(iOS)
        self.dynamicTypeSize(DynamicTypeSize.forScale(scale))
        #else
        self.environment(\.font, .system(size: 13 * scale))
            .controlSize(scale >= 1.35 ? .large : (scale <= 0.85 ? .small : .regular))
        #endif
    }
}

#if os(iOS)
extension DynamicTypeSize {
    /// Maps our factor to the nearest Dynamic Type step (".large" is the normal size).
    static func forScale(_ scale: Double) -> DynamicTypeSize {
        switch scale {
        case ..<0.78: return .xSmall
        case ..<0.88: return .small
        case ..<0.96: return .medium
        case ..<1.06: return .large          // normal
        case ..<1.16: return .xLarge
        case ..<1.28: return .xxLarge
        case ..<1.42: return .xxxLarge
        case ..<1.62: return .accessibility1
        case ..<1.82: return .accessibility2
        default:      return .accessibility3
        }
    }
}
#endif
