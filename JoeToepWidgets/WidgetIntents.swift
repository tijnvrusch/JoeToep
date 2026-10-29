// V21 — Knoppen in widgets (play/pauze, spoelen, Spotify, overnemen, openen). Ook dit bestand staat
// in beide targets (app én widgets). Draait de intent in de app (AudioPlaybackIntent laat het systeem
// de app daarvoor wekken), dan voert de app hem meteen uit; anders zet de widget hem in de rij.
import AppIntents
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetIntentRouter {
    /// De app zet dit bij het starten; in de widget-extensie blijft het nil.
    nonisolated(unsafe) static var handler: ((WidgetCommand) -> Void)?
    static func run(_ command: WidgetCommand) {
        if let handler { DispatchQueue.main.async { handler(command) } }
        else { WidgetShared.enqueue(command) }
        #if canImport(WidgetKit)
        // Na een halve seconde opnieuw tekenen (dan heeft de app de nieuwe toestand geschreven).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { WidgetCenter.shared.reloadAllTimelines() }
        #endif
    }
}

struct MediaCommandIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Control playback"
    static var description = IntentDescription("Play, pause or skip the video on one of your devices.")
    static var isDiscoverable = false

    @Parameter(title: "Action") var action: String
    @Parameter(title: "Device") var deviceID: String

    init() {}
    init(action: WidgetCommand.Action, deviceID: String?) {
        self.action = action.rawValue
        self.deviceID = deviceID ?? ""
    }

    func perform() async throws -> some IntentResult {
        guard let a = WidgetCommand.Action(rawValue: action) else { return .result() }
        WidgetIntentRouter.run(WidgetCommand(action: a, deviceID: deviceID.isEmpty ? nil : deviceID))
        return .result()
    }
}

struct OpenLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open in JoeToep"
    static var openAppWhenRun = true
    static var isDiscoverable = false
    @Parameter(title: "Address") var url: URL
    init() {}
    init(url: URL) { self.url = url }
    func perform() async throws -> some IntentResult {
        WidgetIntentRouter.run(WidgetCommand(action: .open, deviceID: nil, url: url))
        return .result()
    }
}
