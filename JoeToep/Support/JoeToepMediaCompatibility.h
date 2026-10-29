// Objective-C is een oudere programmeertaal van Apple. Een ".h"-bestand ("header") is een
// soort inhoudsopgave: het zegt WELKE functies/types beschikbaar zijn, zonder de eigenlijke
// code (die staat in het bijbehorende ".m"-bestand). Andere bestanden importeren deze header
// om deze functies te kunnen gebruiken.
#import <Foundation/Foundation.h>
// WebKit.h geeft toegang aan de types WKWebView en WKWebViewConfiguration die hieronder
// gebruikt worden (de webweergave-component van Apple).
#import <WebKit/WebKit.h>

// NS_ASSUME_NONNULL_BEGIN/END omsluiten een stuk code waarbinnen pointers (verwijzingen naar
// objecten) standaard NIET nil (leeg/afwezig) mogen zijn, tenzij expliciet anders aangegeven
// (zoals met "nullable"). Dit maakt de code veiliger en duidelijker voor Swift-gebruik.
NS_ASSUME_NONNULL_BEGIN
/// Runtime-checked WebKit SPI for this personal, non-App-Store build.
// FOUNDATION_EXPORT maakt deze C-achtige functie zichtbaar buiten dit bestand, zodat Swift
// (via de bridging header) en andere Objective-C-bestanden hem kunnen aanroepen.
// Deze functie zet WebKit-instellingen die nodig zijn voor achtergrond-afspelen/Picture-in-Picture.
FOUNDATION_EXPORT BOOL JTConfigureMedia(WKWebViewConfiguration *configuration);
/// -1 unavailable, 0 not eligible, 1 already active, 2 start requested.
// Probeert de systeem-eigen (native) Picture-in-Picture van WebKit te starten.
FOUNDATION_EXPORT NSInteger JTStartNativePiP(WKWebView *webView);
// Geeft terug of WebKit's eigen Picture-in-Picture op dit moment actief is.
FOUNDATION_EXPORT BOOL JTNativePiPIsActive(WKWebView *webView);
// Schakelt bescherming tegen het onderbreken van achtergrondmedia aan of uit.
FOUNDATION_EXPORT void JTSetBackgroundMediaProtection(WKWebView *webView, BOOL enabled);
/// V10: MediaSource on/off. Off makes YouTube use Apple HLS/URL media: real video AirPlay and a
/// stream URL that a native AVKit PiP pipeline can prepare before the app is left.
FOUNDATION_EXPORT BOOL JTSetMediaSourceEnabled(WKWebViewConfiguration *configuration, BOOL enabled);
/// Human-readable list of the runtime SPI switches that were actually available.
// Geeft een leesbare tekst terug met welke verborgen WebKit-instellingen (SPI) daadwerkelijk
// beschikbaar bleken te zijn op dit toestel/deze iOS-versie (handig om te debuggen).
FOUNDATION_EXPORT NSString *JTMediaConfigurationSummary(void);
/// V11: allow the next programmatic focus (e.g. YouTube search in a new tab) to show the
/// iOS keyboard for `seconds`. Uses WebKit's input delegate SPI; no effect on macOS.
FOUNDATION_EXPORT void JTAllowProgrammaticFocus(WKWebView *webView, NSTimeInterval seconds);
/// V16: terminate the web content process (it restarts on the next load). NO if unavailable.
FOUNDATION_EXPORT BOOL JTRestartWebContent(WKWebView *webView);
NS_ASSUME_NONNULL_END
