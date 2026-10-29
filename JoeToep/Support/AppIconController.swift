import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
final class AppIconController: ObservableObject {
    static let shared = AppIconController()
    /// V15: 43 icons. Every entry has an .appiconset (iOS alternate icon, macOS-shaped Mac sizes)
    /// and an IconPreview<name> image used for the picker and the Mac Dock.
    static let names = ["AppIcon", "White", "Ocean", "Mint", "Sunset", "Neon", "Candy", "Arcade", "Vinyl", "Orbit", "Aurora",
                        "Lava", "Blueprint", "Cassette", "Prism", "Monochrome", "Jelly", "Sunrise", "Cyberpunk",
                        "Midnight", "Gold", "Rose", "Forest", "Grape", "Coral", "Sky", "Slate", "Carbon", "Paper", "Glass",
                        "Sakura", "Ice", "Ember", "Lime", "Terminal", "Pixel", "RetroTV", "Bubble", "Synthwave", "Rainbow",
                        "Holo", "Heart", "Noir"]
    static func title(_ name: String) -> String {
        switch name {
        case "AppIcon": "Classic"
        case "RetroTV": "Retro TV"
        default: name
        }
    }
    @Published private(set) var selection = UserDefaults.standard.string(forKey: "appIconV8") ?? "AppIcon"
    @Published private(set) var error: String?
    @Published private(set) var changing = false
    func restore() {
        #if os(macOS)
        applyDockIcon()
        #endif
    }
    func select(_ name: String) {
        guard Self.names.contains(name), !changing else { return }
        error = nil
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else { error = "Alternate icons are unavailable on this device."; return }
        changing = true
        UIApplication.shared.setAlternateIconName(name == "AppIcon" ? nil : name) { [weak self] problem in
            Task { @MainActor in
                guard let self else { return }
                self.changing = false
                if let problem { self.error = problem.localizedDescription; return }
                self.selection = name
                UserDefaults.standard.set(name, forKey: "appIconV8")
            }
        }
        #else
        selection = name
        UserDefaults.standard.set(name, forKey: "appIconV8")
        applyDockIcon()
        #endif
    }
    #if os(macOS)
    /// V15: the Dock showed the square preview (straight corners, too large). Draw it on the
    /// macOS icon grid instead: 824 pt rounded rectangle centred on a 1024 pt canvas, with shadow.
    private func applyDockIcon() {
        guard selection != "AppIcon", let source = NSImage(named: "IconPreview" + selection) else {
            NSApp.applicationIconImage = nil   // bundle icon (already macOS-shaped)
            return
        }
        NSApp.applicationIconImage = Self.macShaped(source)
    }
    static func macShaped(_ image: NSImage) -> NSImage {
        NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
            let body = NSRect(x: 100, y: 100, width: 824, height: 824)
            let path = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
            shadow.shadowBlurRadius = 18
            shadow.shadowOffset = NSSize(width: 0, height: -8)
            shadow.set()
            NSColor.black.setFill(); path.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            image.draw(in: body, from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
    }
    #endif
}

/// Grid of all icons (Settings › Appearance).
struct IconPickerGrid: View {
    @ObservedObject var icons = AppIconController.shared
    @Environment(\.joeToepTheme) private var theme
    private let columns = [GridItem(.adaptive(minimum: 68, maximum: 84), spacing: 12)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(AppIconController.names, id: \.self) { name in
                Button { icons.select(name) } label: {
                    VStack(spacing: 5) {
                        Image("IconPreview" + name).resizable().interpolation(.high)
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(icons.selection == name ? theme.accent : Color.gray.opacity(0.25), lineWidth: icons.selection == name ? 3 : 0.5))
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        Text(AppIconController.title(name)).font(.caption2).lineLimit(1)
                            .foregroundStyle(icons.selection == name ? theme.accent : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(icons.changing)
                .accessibilityLabel(AppIconController.title(name) + " icon")
                .accessibilityAddTraits(icons.selection == name ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}
