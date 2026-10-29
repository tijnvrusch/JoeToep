import SwiftUI
#if os(macOS)
import AppKit

/// V16 (Mac): middle mouse button on a hovered control (close a tab, open a page in a new tab,
/// force refresh). One app-wide event monitor; views register while the pointer is over them.
@MainActor
final class MiddleClickRouter {
    static let shared = MiddleClickRouter()
    private var hovered: (id: UUID, action: () -> Void)?
    private var monitor: Any?
    func enter(_ id: UUID, _ action: @escaping () -> Void) {
        hovered = (id, action)
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseUp) { event in
            guard event.buttonNumber == 2 else { return event }
            let target = MainActor.assumeIsolated { MiddleClickRouter.shared.hovered?.action }
            guard let target else { return event }
            DispatchQueue.main.async { target() }
            return nil
        }
    }
    func leave(_ id: UUID) { if hovered?.id == id { hovered = nil } }
}

private struct MiddleClickModifier: ViewModifier {
    let action: () -> Void
    @State private var id = UUID()
    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside { MiddleClickRouter.shared.enter(id, action) } else { MiddleClickRouter.shared.leave(id) }
            }
            .onDisappear { MiddleClickRouter.shared.leave(id) }
    }
}
extension View {
    func middleClick(_ action: @escaping () -> Void) -> some View { modifier(MiddleClickModifier(action: action)) }
}
#else
extension View {
    func middleClick(_ action: @escaping () -> Void) -> some View { self }
}
#endif
