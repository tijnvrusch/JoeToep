// V18 — Korte uitleg onder ELKE instelling, zodat altijd duidelijk is wat hij doet.
// SettingToggle / SettingPicker tekenen de gewone SwiftUI-bediening, met de titel en
// (als die er is) een grijze uitlegregel eronder. Eén woordenboek = één plek om teksten te beheren.
import SwiftUI

enum SettingHelp {
    static func text(for title: String) -> String? { texts[title] }

    static let texts: [String: String] = [
        // Appearance
        "Theme": "The overall colour scheme of JoeToep's own bars and menus.",
        "Accent colour": "The highlight colour for buttons, switches and the selected tab.",
        "Custom accent": "Pick any colour as your accent.",
        "Colour": "Colour used for this element.",
        "Colours": "Colour set used for this element.",
        "Colouring": "Single colour, or multiple tones per icon.",
        "Style": "Visual style of this element.",
        "Style for everything": "Applies one icon style to every button at once.",
        "Weight": "Line thickness of icons.",
        "Animations": "How fast menus, tabs and panels move. Off is the fastest and uses the least energy.",
        "Fastest transitions": "Skips waiting animations between fullscreen, PiP and tabs.",
        "Glow": "A soft glow behind the visualizer.",
        "Mirror (symmetric)": "Draws the visualizer mirrored from the centre.",
        "Rounded bars": "Rounded ends on visualizer bars.",
        "Also behind the tabs": "Extends the visualizer behind the tab bar.",
        "Position": "Where this element is placed on screen.",
        "Section": "Which part of the settings to show.",
        "Show JoeToep / #yolo": "Shows the JoeToep name in the menu bar.",
        "Edge-to-edge webpage": "Lets the page use the full screen, under the status bar and rounded corners.",
        // Tabs & text
        "Tab shape": "Rounded or square tabs.",
        "Tab text": "Text size of tab titles.",
        "Close buttons": "When the × on a tab is visible.",
        "Show tab icons": "Shows the site icon in each tab.",
        "Close inactive tabs after": "Tabs you haven't opened for this long are closed automatically.",
        "Open new tabs next to the current tab": "New tabs appear right of the current one instead of at the end.",
        "Show new tabs immediately (middle-click, Open in New Tab)": "Jumps to a link opened in a new tab straight away.",
        "Back on the first page closes the tab": "Going back when there is nothing to go back to closes the tab (like on Android).",
        "Summarise video titles in tabs": "Shortens long video titles to a few words so tabs stay readable.",
        "Length": "How short the tab summaries are.",
        "Use Apple Intelligence when available": "Uses on-device Apple Intelligence for tab summaries; otherwise a fast built-in method.",
        // Menu bar
        "Menu bar buttons": "How many buttons the menu bar shows.",
        "Show Back and Forward buttons": "Arrow buttons to go back and forward in the current tab.",
        "Show Home button": "Button that opens the YouTube home feed.",
        "Show Subscriptions button": "Button that opens your subscriptions.",
        "Show Library button": "Button that opens your YouTube library.",
        "Show History button": "Button that opens your watch history.",
        "Show Playlist / Watch later button": "Button that opens Watch later.",
        "Show Refresh button": "Button that reloads the page.",
        "Show Settings button": "Gear button for these settings (also ⌘, on Mac).",
        "Show New Tab (+) button": "Button that opens a new tab.",
        "Show AirPlay button": "Send audio or video to an AirPlay speaker or TV.",
        "Show resolution (4K) button": "Quick button to choose the video quality.",
        "Show Bookmark button": "Save the current page as a bookmark.",
        "Show More (⋯) browser menu": "Menu with every browser action: share, find, zoom, bookmarks and more.",
        "Show PiP button in menu bar": "Button to start or stop Picture in Picture.",
        "Show Creator tools button (speed, A–B loop, BPM)": "Tools for music and dance: speed, loop, tap tempo, frame step.",
        "Show connection and playback status": "Small indicator for network and player state.",
        // General / browsing
        "New tab page": "What a new tab shows first.",
        "Address bar searches with": "Search engine used when you type words instead of an address.",
        "Open other websites in JoeToep": "Links to other sites open in a JoeToep tab instead of your default browser.",
        "Remember browsing history": "Keeps a list of visited pages in the Library.",
        "Website layout": "Desktop or mobile version of websites.",
        "Pinch gesture": "What pinching does: zoom the video or zoom the page.",
        "Video sizing": "Fit shows the whole video; Fill crops to fill the screen.",
        "Keep the screen on while a video plays": "Stops the display from dimming or locking during playback.",
        "Recover a terminated web process": "If the page crashes in the background, reload it and continue where you were.",
        // Playback & PiP
        "Resolution preference": "The quality YouTube starts at. Higher looks sharper but uses more data.",
        "Quality on cellular / hotspot": "Maximum quality when on mobile data.",
        "Save data on cellular & hotspot": "Uses the lower quality above when not on wifi.",
        "Open videos in fullscreen automatically": "A video you start goes fullscreen right away.",
        "Fullscreen player": "Which player fullscreen uses: YouTube's own or Apple's.",
        "YouTube fullscreen instead of Apple player": "Keeps YouTube's controls in fullscreen.",
        "Use Apple player (off = Safe Fullscreen)": "Apple's player enables AirPlay and system PiP; Safe Fullscreen is the most compatible.",
        "Apple streaming engine (360p, video AirPlay, inline auto-PiP)": "Plays via Apple's engine for AirPlay video. Limited to 360p.",
        "Theater mode (full width)": "Makes the video as wide as the window.",
        "Turn off video captions": "Subtitles are off unless you turn them on yourself.",
        "Turn off thumbnail preview captions": "No subtitles in the silent previews on the home feed.",
        "Rotate fullscreen to landscape": "Turns fullscreen sideways on iPhone.",
        "Return to portrait after fullscreen": "Turns back upright when fullscreen ends.",
        "Fullscreen when rotating to landscape": "Turning your iPhone sideways makes the video fullscreen.",
        "Leave fullscreen when rotating back to portrait": "Turning back upright leaves fullscreen.",
        "Instant rotation (keep the page in portrait)": "Only the video rotates, so it happens without delay.",
        "Automatic PiP when switching apps": "When you switch app while a video plays, it continues in a small floating window.",
        "Smart PiP with multiple displays": "Mac with more screens: PiP only starts when the new app opens on the same screen as JoeToep. On another screen the video keeps playing fullscreen. With just the built-in display PiP always starts.",
        "PiP return button opens": "What the return button in the PiP window brings you back to.",
        "Keep playing when returning from PiP": "The video doesn't pause when you close PiP.",
        "Keep playing in PiP when opening another tab": "A playing video moves to PiP when you open another tab.",
        "New video takes over in fullscreen": "Starting a video in the new tab pauses the PiP video and plays the new one fullscreen.",
        "Picture in Picture on all websites": "The PiP button also works on Vimeo, Twitch and other sites.",
        "Start PiP after leaving fullscreen": "Leaving fullscreen continues in PiP instead of the page.",
        "Keep PiP when returning to JoeToep": "PiP stays open when you come back to the app.",
        "Bring JoeToep forward when native PiP ends": "Closing PiP on Mac brings the JoeToep window to the front.",
        "Automatic floating video fallback": "If system PiP fails on Mac, a floating always-on-top window is used.",
        "Enable direct PiP fallback": "Tries a second PiP method when the first doesn't start.",
        "Protect background playback": "Stops YouTube from pausing the video when the app goes to the background.",
        "Spatial audio for AirPods (movie mode, multichannel)": "Surround and head tracking on AirPods Pro and Max.",
        "Show speed buttons (slower / faster)": "Two buttons in the menu bar: one click is one speed step (0.25× to 4×). Long-press resets to 1×.",
        "Show Download button": "Button to save the video or audio of this page for offline use. Works on sites that offer the file; YouTube uses its own Premium downloads.",
        // Privacy
        "Cookie banners": "Reject all automatically, only hide the banner, or leave it alone.",
        "Remove tracking parameters from links (utm_, fbclid, si …)": "Cleans tracking codes from links before you open or share them.",
        "Send Global Privacy Control (do not sell / share)": "Tells websites you don't want your data sold or shared.",
        "Block known trackers and ad pixels": "Stops analytics and ad scripts from loading.",
        "Clear cookies and website data when JoeToep quits": "Signs you out everywhere when you quit. Off keeps you signed in.",
        // Ads & SponsorBlock
        "Block ads": "Removes YouTube ads before and during videos.",
        "Hide ad cards and promoted tiles": "Hides sponsored cards in the feed.",
        "Hide Shorts": "Removes Shorts from the feed and blocks Shorts pages.",
        "Hide posts and announcements": "Removes community posts from the feed.",
        "Hide Premium / members-only cards": "Hides videos you can't watch without a membership.",
        "Latest compatible EasyList rules": "Adds extra community ad-block rules. Stronger, sometimes less stable.",
        "SponsorBlock": "Skips sponsor segments that other viewers marked.",
        "Ignore segments shorter than": "Very short segments aren't skipped.",
        "Show a notice with Undo after skipping": "A short message with Undo appears after a skip.",
        "Show segments in the progress bar": "Coloured marks show the segments on the time bar.",
        "Skip each segment only once": "Rewinding into a segment won't skip it again.",
        // Sync
        "Live tab sync": "Your tabs, the video and its time stay the same on Mac, iPad and iPhone, instantly. Works over wifi or Bluetooth; nothing goes via the internet.",
        // Creator tools
        "Keep pitch (time-stretch)": "Changing speed keeps the same tone.",
        "Mute this tab": "Silences all video and audio in this tab.",
    ]
}

/// Titel + grijze uitleg eronder (de uitleg valt weg als er geen tekst voor is).
struct SettingLabel: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let help = SettingHelp.text(for: title) {
                Text(help).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingToggle: View {
    let title: String
    @Binding var isOn: Bool
    init(_ title: String, isOn: Binding<Bool>) { self.title = title; self._isOn = isOn }
    var body: some View { Toggle(isOn: $isOn) { SettingLabel(title: title) } }
}

struct SettingPicker<Selection: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Selection
    let content: Content
    init(_ title: String, selection: Binding<Selection>, @ViewBuilder content: () -> Content) {
        self.title = title; self._selection = selection; self.content = content()
    }
    var body: some View {
        Picker(selection: $selection) { content } label: { SettingLabel(title: title) }
    }
}
