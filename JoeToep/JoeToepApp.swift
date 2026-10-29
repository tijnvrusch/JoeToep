import SwiftUI

@main
struct JoeToepApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(JoeToepAppDelegate.self) private var appDelegate
    #endif
    var body: some Scene {
        WindowGroup("JoeToep", id: "main") {
            #if os(macOS)
            RootView().frame(minWidth: 520, minHeight: 360)
            #else
            RootView()
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1240, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands { BrowserCommands() }
        #endif
    }
}
#if os(macOS)
struct BrowserCommands: Commands {
    @FocusedValue(\.workspaceActions) private var actions
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") { actions?.newTab() }.keyboardShortcut("t", modifiers: .command).disabled(actions == nil)
            Button("New Private Tab") { actions?.newPrivateTab() }.keyboardShortcut("n", modifiers: [.command, .shift]).disabled(actions == nil)
            Button("New Window") { openWindow(id: "main") }.keyboardShortcut("n", modifiers: .command)
            Button("Reopen Closed Tab") { actions?.reopenClosedTab() }.keyboardShortcut("t", modifiers: [.command, .shift]).disabled(actions == nil)
            Divider()
            Button("Open Location…") { actions?.editAddress() }.keyboardShortcut("l", modifiers: .command).disabled(actions == nil)
            Divider()
            Button("Close Tab") { actions?.closeTab() }.keyboardShortcut("w", modifiers: .command).disabled(actions == nil)
            Button("Close Window") { actions?.closeWindow() }.keyboardShortcut("w", modifiers: [.command, .shift]).disabled(actions == nil)
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { actions?.openSettings() }.keyboardShortcut(",", modifiers: .command).disabled(actions == nil)
        }
        CommandGroup(after: .newItem) {
            Button("Reload Page") { actions?.reload() }.keyboardShortcut("r", modifiers: .command).disabled(actions == nil)
        }
        CommandGroup(replacing: .textEditing) {
            Button("Find on Page…") { actions?.find() }.keyboardShortcut("f", modifiers: .command).disabled(actions == nil)
        }
        CommandMenu("History") {
            Button("Back") { actions?.goBack() }.keyboardShortcut("[", modifiers: .command).disabled(actions == nil)
            Button("Forward") { actions?.goForward() }.keyboardShortcut("]", modifiers: .command).disabled(actions == nil)
            Divider()
            Button("Show Bookmarks & History") { actions?.showLibrary() }.keyboardShortcut("y", modifiers: .command).disabled(actions == nil)
            Button("Add / Remove Bookmark") { actions?.toggleBookmark() }.keyboardShortcut("d", modifiers: .command).disabled(actions == nil)
        }
        CommandMenu("Tabs") {
            Button("Show Next Tab") { actions?.nextTab() }.keyboardShortcut("]", modifiers: [.command, .shift]).disabled(actions == nil)
            Button("Show Previous Tab") { actions?.previousTab() }.keyboardShortcut("[", modifiers: [.command, .shift]).disabled(actions == nil)
            Button("Next Tab") { actions?.nextTab() }.keyboardShortcut(.tab, modifiers: .control).disabled(actions == nil)
            Button("Previous Tab") { actions?.previousTab() }.keyboardShortcut(.tab, modifiers: [.control, .shift]).disabled(actions == nil)
            Button("Pin / Unpin Tab") { actions?.togglePin() }.disabled(actions == nil)
            Divider()
            ForEach(1..<10) { number in
                Button(number == 9 ? "Last Tab" : "Tab \(number)") { actions?.selectTab(number - 1) }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command).disabled(actions == nil)
            }
        }
        CommandGroup(after: .toolbar) {
            Button("Zoom In") { actions?.zoomIn() }.keyboardShortcut("+", modifiers: .command).disabled(actions == nil)
            Button("Zoom Out") { actions?.zoomOut() }.keyboardShortcut("-", modifiers: .command).disabled(actions == nil)
            Button("Actual Size") { actions?.resetZoom() }.keyboardShortcut("0", modifiers: .command).disabled(actions == nil)
        }
        CommandMenu("Playback") {
            Button("Toggle Picture in Picture") { actions?.pictureInPicture() }.keyboardShortcut("z", modifiers: .option).disabled(actions == nil)
        }
    }
}
#endif
