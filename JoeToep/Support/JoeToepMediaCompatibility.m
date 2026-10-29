// ".m"-bestanden bevatten de daadwerkelijke Objective-C implementatie (in tegenstelling tot
// de ".h"-header, die alleen aankondigt wat er bestaat).
#import "JoeToepMediaCompatibility.h"
// TargetConditionals.h geeft macro's zoals TARGET_OS_IOS/TARGET_OS_OSX waarmee je code kunt
// laten verschillen per platform (net als #if os(iOS) in Swift).
#import <TargetConditionals.h>
// dlfcn.h geeft toegang tot dlsym(), waarmee je op naam een functie kunt opzoeken die pas
// tijdens het draaien (runtime) bekend wordt, in plaats van bij het compileren.
#import <dlfcn.h>
// objc/message.h geeft toegang tot objc_msgSend, de onderliggende manier waarop Objective-C
// berichten ([object bericht]) daadwerkelijk worden afgeleverd.
#import <objc/message.h>

// Signatures verified against WebKit's WKPreferencesPrivate.h / WKWebViewPrivate.h.
// No private framework is linked. Every optional selector is checked before use.
//
// Dit hele bestand gebruikt PRIVATE WebKit-functionaliteit (SPI = System Programming
// Interface): methodes die niet officieel door Apple gedocumenteerd/toegestaan zijn voor
// App Store-apps, maar die hier gebruikt worden omdat dit een persoonlijke, niet-App
// Store-app is. Omdat deze methodes op elk moment kunnen verdwijnen (bijvoorbeeld na een
// iOS-update), wordt VOOR elk gebruik gecontroleerd met "respondsToSelector:" of het object
// de methode wel daadwerkelijk kent. Een "selector" is de naam van een methode als los
// object (bijvoorbeeld @selector(setEnabled:)); "respondsToSelector:" vraagt op dat moment
// (runtime) of een object die methode kan uitvoeren, zonder hem meteen aan te roepen.
//
// "@interface X (CategoryName) ... @end" is een Objective-C "category": het voegt methodes
// toe aan een BESTAAND type (hier WKPreferences/WKWebViewConfiguration/WKWebView) zonder
// een nieuwe subklasse te maken. Hier wordt het alleen gebruikt om de compiler te vertellen
// "deze private methodes bestaan, reken er maar op" — de echte implementatie zit al in
// WebKit zelf; dit stuk voegt geen nieuwe code toe, het is puur een aankondiging.
@interface WKPreferences (JTMediaSPI)
- (void)_setAllowsPictureInPictureMediaPlayback:(BOOL)value;
- (void)_setInterruptAudioOnPageVisibilityChangeEnabled:(BOOL)value;
- (void)_setRequiresPageVisibilityToPlayAudio:(BOOL)value;
- (void)_setPageVisibilityBasedProcessSuppressionEnabled:(BOOL)value;
- (void)_setMediaSourceEnabled:(BOOL)value;
- (void)_setContentChangeObserverEnabled:(BOOL)value;
- (void)_setManagedMediaSourceEnabled:(BOOL)value;
- (void)_setEnabled:(BOOL)value forFeature:(id)feature;
+ (NSArray *)_features;
@end
@interface WKWebViewConfiguration (JoeToepMediaSPI)
- (void)_setAllowsInlineMediaPlaybackAfterFullscreen:(BOOL)value;
- (void)_setInlineMediaPlaybackRequiresPlaysInlineAttribute:(BOOL)value;
@end
@interface WKWebView (JTMediaSPI)
- (BOOL)_canTogglePictureInPicture;
- (BOOL)_isPictureInPictureActive;
- (BOOL)_isShowingVideoPictureInPicture;
- (BOOL)_isSuspended;
- (void)_togglePictureInPicture;
- (void)_updateMediaPlaybackControlsManager;
@end

// Houdt bij (voor foutopsporing/logging) welke SPI-instellingen daadwerkelijk toegepast zijn.
// "static" binnen een .m-bestand betekent: deze functie/variabele is alleen zichtbaar in dit
// bestand, niet daarbuiten.
static NSMutableArray<NSString *> *JTApplied(void) {
    // "static" binnen een functie betekent: deze variabele wordt maar ÉÉN keer aangemaakt en
    // blijft daarna bestaan tussen aanroepen van de functie (in tegenstelling tot gewone
    // lokale variabelen die elke keer opnieuw beginnen).
    static NSMutableArray<NSString *> *items;
    // dispatch_once zorgt dat de code in het blok ({ ... }) maar precies ÉÉN keer wordt
    // uitgevoerd, ook als meerdere threads deze functie tegelijk aanroepen.
    static dispatch_once_t once;
    dispatch_once(&once, ^{ items = [NSMutableArray array]; });
    return items;
}
// Voegt een tekst toe aan de lijst van toegepaste instellingen, als hij er nog niet in staat.
static void JTNote(NSString *item) {
    // @synchronized vergrendelt dit blok zodat niet twee threads tegelijk de lijst wijzigen
    // (dat zou de lijst kunnen beschadigen).
    @synchronized (JTApplied()) { if (![JTApplied() containsObject:item]) [JTApplied() addObject:item]; }
}
NSString *JTMediaConfigurationSummary(void) {
    @synchronized (JTApplied()) { return [JTApplied() componentsJoinedByString:@", "]; }
}

// Exported WebKit C API (symbols verified in the iOS 27 WebKit binary). In Cocoa builds a
// WKPreferencesRef is the WKPreferences Objective-C object itself (API::Object::wrap).
//
// Dit definieert het "type" van een functiepointer: een functie die een geheugenadres
// (preferences) en een boolean (value) aanneemt en niets teruggeeft. Zo kunnen we straks een
// functie die we via dlsym() gevonden hebben, aanroepen alsof het een gewone C-functie is.
typedef void (*JTBoolPreferenceSetter)(const void *preferences, bool value);
// Zoekt een lage-niveau C-functie in WebKit op zijn naam (symbol) en roept hem aan als hij
// bestaat. Dit is een extra, nog lager niveau dan de Objective-C "_set..."-methodes hierboven:
// sommige instellingen zijn alleen bereikbaar via zo'n interne C-functie.
static BOOL JTSetCPreference(WKPreferences *preferences, const char *symbol, bool value) {
    // dlsym zoekt, terwijl het programma al draait, een functie op zijn naam in alle geladen
    // bibliotheken (RTLD_DEFAULT = zoek overal). Bestaat de naam niet (meer), dan komt er NULL
    // terug en doen we niets (NO = mislukt).
    JTBoolPreferenceSetter setter = (JTBoolPreferenceSetter)dlsym(RTLD_DEFAULT, symbol);
    if (!setter) return NO;
    // "__bridge" zet een Objective-C object om naar een gewone C-pointer zonder het
    // geheugenbeheer (ARC) ervan te veranderen; nodig omdat de C-functie geen Objective-C
    // object verwacht maar een ruwe pointer.
    setter((__bridge const void *)preferences, value);
    JTNote([NSString stringWithFormat:@"%s=%d", symbol + 16, value]);
    return YES;
}
// Toggle an internal/experimental WebKit feature by its stable preference key.
// Schakelt een interne, experimentele WebKit-functie in of uit via zijn sleutel-naam
// (bijvoorbeeld "InterruptVideoOnPageVisibilityChangeEnabled"). WebKit houdt zelf een lijst
// van alle bekende features bij (_features); hier wordt daar doorheen gezocht naar het
// element met de gevraagde "key", en dat element wordt aan/uit gezet.
static BOOL JTSetFeature(WKPreferences *preferences, NSString *key, BOOL enabled) {
    if (![WKPreferences respondsToSelector:@selector(_features)] ||
        ![preferences respondsToSelector:@selector(_setEnabled:forFeature:)]) return NO;
    // "for (id feature in ...)" is Objective-C's manier om door een verzameling te lussen
    // (vergelijkbaar met "for x in lijst" in Swift). "id" betekent: een object van eender
    // welk type (Objective-C's meest algemene objecttype).
    for (id feature in [WKPreferences _features]) {
        // NSSelectorFromString zet een tekst om in een selector, zodat we dynamisch (op naam,
        // pas bepaald tijdens het draaien) kunnen vragen of het object een "key"-methode heeft.
        if (![feature respondsToSelector:NSSelectorFromString(@"key")]) continue;
        // valueForKey: haalt de waarde van een eigenschap op via zijn naam als tekst
        // (Key-Value Coding), in plaats van rechtstreeks feature.key te schrijven.
        if ([[feature valueForKey:@"key"] isEqualToString:key]) {
            [preferences _setEnabled:enabled forFeature:feature];
            JTNote([NSString stringWithFormat:@"%@=%d", key, enabled]);
            return YES;
        }
    }
    return NO;
}

// Zet MediaSource (de webtechniek die YouTube normaal gebruikt om streams samen te stellen)
// aan of uit. Uitgeschakeld zorgt dat YouTube in plaats daarvan gewone Apple HLS-streams
// (bruikbaar met AirPlay en de native Picture-in-Picture-pijplijn) gebruikt.
BOOL JTSetMediaSourceEnabled(WKWebViewConfiguration *configuration, BOOL enabled) {
    WKPreferences *preferences = configuration.preferences;
    BOOL changed = NO;
    if ([preferences respondsToSelector:@selector(_setMediaSourceEnabled:)]) {
        [preferences _setMediaSourceEnabled:enabled]; changed = YES;
    }
    if ([preferences respondsToSelector:@selector(_setManagedMediaSourceEnabled:)]) {
        [preferences _setManagedMediaSourceEnabled:enabled]; changed = YES;
    }
    if (changed) JTNote(enabled ? @"MediaSource=on" : @"MediaSource=off (Apple HLS)");
    return changed;
}

// Bepaalt of de webpagina "onderdrukt" mag worden (bijvoorbeeld gepauzeerd) wanneer hij niet
// zichtbaar is (op de achtergrond). "enabled" hier betekent: bescherming AAN, dus de
// onderliggende WebKit-instelling (suppression) wordt dan juist UITGEZET (!enabled).
void JTSetBackgroundMediaProtection(WKWebView *webView, BOOL enabled) {
    WKPreferences *preferences = webView.configuration.preferences;
    if ([preferences respondsToSelector:@selector(_setPageVisibilityBasedProcessSuppressionEnabled:)]) {
        [preferences _setPageVisibilityBasedProcessSuppressionEnabled:!enabled];
    }
}

// De belangrijkste opzet-functie: schakelt allerlei WebKit-instellingen in zodat video's
// (zoals van YouTube) kunnen doorspelen op de achtergrond en in Picture-in-Picture kunnen
// gaan. Geeft terug of tenminste íéts daadwerkelijk kon worden ingesteld.
BOOL JTConfigureMedia(WKWebViewConfiguration *configuration) {
    WKPreferences *preferences = configuration.preferences;
    BOOL enabled = NO;
    if ([preferences respondsToSelector:@selector(_setAllowsPictureInPictureMediaPlayback:)]) {
        [preferences _setAllowsPictureInPictureMediaPlayback:YES];
        enabled = YES;
    }
    if ([preferences respondsToSelector:@selector(_setInterruptAudioOnPageVisibilityChangeEnabled:)]) {
        [preferences _setInterruptAudioOnPageVisibilityChangeEnabled:NO];
    }
    if ([preferences respondsToSelector:@selector(_setRequiresPageVisibilityToPlayAudio:)]) {
        [preferences _setRequiresPageVisibilityToPlayAudio:NO];
    }
    // A hidden page (lock button, Home, other app) must not interrupt or re-route video.
    JTSetFeature(preferences, @"InterruptVideoOnPageVisibilityChangeEnabled", NO);
    JTSetFeature(preferences, @"RequiresPageVisibilityForVideoToBeNowPlaying", NO);
    // V23.1: NIET "TextRecognitionInVideosEnabled" uitzetten — getest: het webproces liep dan vast bij
    // fullscreen (zwarte tab). De klik-blokkade van die laag lost MacNavigationMonitor op.
    // The user already interacted with the page; presentation changes requested by the app
    // (fullscreen return, PiP toggle, AirPlay picker) may inherit that document gesture.
    JTSetCPreference(preferences, "WKPreferencesSetMediaUserGestureInheritsFromDocument", true);
    JTSetCPreference(preferences, "WKPreferencesSetMainContentUserGestureOverrideEnabled", true);
#if TARGET_OS_IOS
    // V13: the desktop site's hover tooltips made iOS treat the first tap on play/pause or
    // fullscreen as a hover (content-change observer), so a second tap was needed.
    if ([preferences respondsToSelector:@selector(_setContentChangeObserverEnabled:)]) {
        [preferences _setContentChangeObserverEnabled:NO];
        JTNote(@"ContentChangeObserver=off");
    }
#endif
#if TARGET_OS_IOS
    // Set once. Toggling any preference while backgrounding broadcasts a settings update to the
    // web process at the exact moment of the lock/PiP transition (audible hitch).
    if ([preferences respondsToSelector:@selector(_setPageVisibilityBasedProcessSuppressionEnabled:)]) {
        [preferences _setPageVisibilityBasedProcessSuppressionEnabled:NO];
    }
#endif
#if TARGET_OS_IOS
    // Dit is een publieke (niet-verborgen) instelling: staat inline afspelen met
    // Picture-in-Picture toe op iOS/iPadOS.
    configuration.allowsPictureInPictureMediaPlayback = YES;
    if ([configuration respondsToSelector:@selector(_setAllowsInlineMediaPlaybackAfterFullscreen:)]) {
        [configuration _setAllowsInlineMediaPlaybackAfterFullscreen:YES];
    }
    if ([configuration respondsToSelector:@selector(_setInlineMediaPlaybackRequiresPlaysInlineAttribute:)]) {
        [configuration _setInlineMediaPlaybackRequiresPlaysInlineAttribute:NO];
    }
    enabled = YES;
#endif
    return enabled;
}

// Geeft terug of WebKit's eigen Picture-in-Picture op dit moment actief is. Mac en
// iOS/iPadOS gebruiken elk hun eigen private methode hiervoor.
BOOL JTNativePiPIsActive(WKWebView *webView) {
#if TARGET_OS_OSX
    return [webView respondsToSelector:@selector(_isPictureInPictureActive)] && [webView _isPictureInPictureActive];
#else
    return [webView respondsToSelector:@selector(_isShowingVideoPictureInPicture)] && [webView _isShowingVideoPictureInPicture];
#endif
}

// Probeert WebKit's eigen (native) Picture-in-Picture te starten. Alleen op macOS
// geïmplementeerd; op iOS/iPadOS bestaat deze specifieke SPI-route niet (-1 = niet
// beschikbaar). De teruggegeven waarden staan uitgelegd in de header (.h-bestand).
NSInteger JTStartNativePiP(WKWebView *webView) {
#if TARGET_OS_OSX
    if (![webView respondsToSelector:@selector(_canTogglePictureInPicture)] ||
        ![webView respondsToSelector:@selector(_togglePictureInPicture)]) return -1;
    if ([webView respondsToSelector:@selector(_isSuspended)] && [webView _isSuspended]) return 0;
    if (JTNativePiPIsActive(webView)) return 1;
    if ([webView respondsToSelector:@selector(_updateMediaPlaybackControlsManager)]) {
        [webView _updateMediaPlaybackControlsManager];
    }
    if (![webView _canTogglePictureInPicture]) return 0;
    [webView _togglePictureInPicture];
    return 2;
#else
    return -1;
#endif
}

#if TARGET_OS_IOS
// objc/runtime.h geeft toegang tot dingen zoals objc_getAssociatedObject/objc_setAssociatedObject,
// waarmee je een extra "eigenschap" aan een bestaand object kunt "plakken" zonder dat object
// zelf aan te passen (handig als je de broncode van dat object niet bezit, zoals bij WKWebView).
#import <objc/runtime.h>
// Een eigen kleine klasse die als "input delegate" van WebKit optreedt: WebKit vraagt dit
// object of het toetsenbord getoond mag worden wanneer een tekstveld op de pagina
// programmatisch (dus niet door een echte tik van de gebruiker) de focus krijgt.
@interface JTInputDelegate : NSObject
// @property maakt automatisch een eigenschap met getter/setter aan; hier: tot welk tijdstip
// programmatische focus is toegestaan.
@property (nonatomic) CFAbsoluteTime allowUntil;
@end
@implementation JTInputDelegate
// _WKFocusStartsInputSessionPolicy: 0 auto, 1 allow, 2 disallow.
// Deze methode-naam begint met een underscore: het is weer een private WebKit-delegate-methode.
// Hij geeft 1 (sta toe) terug zolang we nog binnen het toegestane tijdvenster zitten, anders 0.
- (NSInteger)_webView:(WKWebView *)webView decidePolicyForFocusedElement:(id)info {
    return CFAbsoluteTimeGetCurrent() < self.allowUntil ? 1 : 0;
}
- (BOOL)_webView:(WKWebView *)webView focusShouldStartInputSession:(id)info {
    return CFAbsoluteTimeGetCurrent() < self.allowUntil;
}
@end
// Een pointer die als unieke "sleutel" dient om dit associated object later terug te vinden
// bij hetzelfde WKWebView (het adres van deze variabele zelf is uniek genoeg).
static const void *JTInputDelegateKey = &JTInputDelegateKey;
#endif

// Staat toe dat de volgende programmatische focus (bijvoorbeeld het automatisch focussen van
// het YouTube-zoekveld in een nieuw tabblad) het toetsenbord toont, gedurende `seconds`
// seconden. Zonder dit zou WebKit dat normaal blokkeren (om te voorkomen dat websites
// ongevraagd het toetsenbord opdringen).
void JTAllowProgrammaticFocus(WKWebView *webView, NSTimeInterval seconds) {
#if TARGET_OS_IOS
    SEL setter = NSSelectorFromString(@"_setInputDelegate:");
    if (![webView respondsToSelector:setter]) return;
    // Kijkt of er al een JTInputDelegate aan dit specifieke webView "geplakt" is; zo niet,
    // wordt er één gemaakt en bewaard (OBJC_ASSOCIATION_RETAIN_NONATOMIC = het webView houdt
    // hem in leven, net als een gewone sterke eigenschap zou doen).
    JTInputDelegate *delegate = objc_getAssociatedObject(webView, JTInputDelegateKey);
    if (!delegate) {
        delegate = [JTInputDelegate new];
        objc_setAssociatedObject(webView, JTInputDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // objc_msgSend is de kern van hoe Objective-C berichten aflevert: normaal schrijf je
        // [webView _setInputDelegate:delegate], maar omdat de selector hier pas tijdens het
        // draaien bekend is (via NSSelectorFromString), wordt objc_msgSend rechtstreeks
        // aangeroepen met een functie-aanduiding die het juiste type argumenten aangeeft.
        ((void (*)(id, SEL, id))objc_msgSend)(webView, setter, delegate);
        JTNote(@"InputDelegate=on");
    }
    delegate.allowUntil = CFAbsoluteTimeGetCurrent() + seconds;
#endif
}

// Beëindigt het webcontent-proces van WebKit (het herstart vanzelf bij de volgende keer
// laden). Dit is een soort "harde herstart" van de webpagina, gebruikt als een gewone
// paginavernieuwing niet volstaat. Probeert eerst de nieuwste, dan de oudere private naam.
BOOL JTRestartWebContent(WKWebView *webView) {
    for (NSString *name in @[@"_killWebContentProcessAndResetState", @"_killWebContentProcess"]) {
        SEL selector = NSSelectorFromString(name);
        if ([webView respondsToSelector:selector]) {
            ((void (*)(id, SEL))objc_msgSend)(webView, selector);
            JTNote(@"ForceRefresh=kill");
            return YES;
        }
    }
    return NO;
}
