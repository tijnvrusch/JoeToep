#import "JoeToepMediaCompatibility.h"
#import <TargetConditionals.h>
#import <dlfcn.h>
#import <objc/message.h>

// Signatures verified against WebKit's WKPreferencesPrivate.h / WKWebViewPrivate.h.
// No private framework is linked. Every optional selector is checked before use.
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

static NSMutableArray<NSString *> *JTApplied(void) {
    static NSMutableArray<NSString *> *items;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ items = [NSMutableArray array]; });
    return items;
}
static void JTNote(NSString *item) {
    @synchronized (JTApplied()) { if (![JTApplied() containsObject:item]) [JTApplied() addObject:item]; }
}
NSString *JTMediaConfigurationSummary(void) {
    @synchronized (JTApplied()) { return [JTApplied() componentsJoinedByString:@", "]; }
}

// Exported WebKit C API (symbols verified in the iOS 27 WebKit binary). In Cocoa builds a
// WKPreferencesRef is the WKPreferences Objective-C object itself (API::Object::wrap).
typedef void (*JTBoolPreferenceSetter)(const void *preferences, bool value);
static BOOL JTSetCPreference(WKPreferences *preferences, const char *symbol, bool value) {
    JTBoolPreferenceSetter setter = (JTBoolPreferenceSetter)dlsym(RTLD_DEFAULT, symbol);
    if (!setter) return NO;
    setter((__bridge const void *)preferences, value);
    JTNote([NSString stringWithFormat:@"%s=%d", symbol + 16, value]);
    return YES;
}
// Toggle an internal/experimental WebKit feature by its stable preference key.
static BOOL JTSetFeature(WKPreferences *preferences, NSString *key, BOOL enabled) {
    if (![WKPreferences respondsToSelector:@selector(_features)] ||
        ![preferences respondsToSelector:@selector(_setEnabled:forFeature:)]) return NO;
    for (id feature in [WKPreferences _features]) {
        if (![feature respondsToSelector:NSSelectorFromString(@"key")]) continue;
        if ([[feature valueForKey:@"key"] isEqualToString:key]) {
            [preferences _setEnabled:enabled forFeature:feature];
            JTNote([NSString stringWithFormat:@"%@=%d", key, enabled]);
            return YES;
        }
    }
    return NO;
}

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

void JTSetBackgroundMediaProtection(WKWebView *webView, BOOL enabled) {
    WKPreferences *preferences = webView.configuration.preferences;
    if ([preferences respondsToSelector:@selector(_setPageVisibilityBasedProcessSuppressionEnabled:)]) {
        [preferences _setPageVisibilityBasedProcessSuppressionEnabled:!enabled];
    }
}

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

BOOL JTNativePiPIsActive(WKWebView *webView) {
#if TARGET_OS_OSX
    return [webView respondsToSelector:@selector(_isPictureInPictureActive)] && [webView _isPictureInPictureActive];
#else
    return [webView respondsToSelector:@selector(_isShowingVideoPictureInPicture)] && [webView _isShowingVideoPictureInPicture];
#endif
}

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
#import <objc/runtime.h>
@interface JTInputDelegate : NSObject
@property (nonatomic) CFAbsoluteTime allowUntil;
@end
@implementation JTInputDelegate
// _WKFocusStartsInputSessionPolicy: 0 auto, 1 allow, 2 disallow.
- (NSInteger)_webView:(WKWebView *)webView decidePolicyForFocusedElement:(id)info {
    return CFAbsoluteTimeGetCurrent() < self.allowUntil ? 1 : 0;
}
- (BOOL)_webView:(WKWebView *)webView focusShouldStartInputSession:(id)info {
    return CFAbsoluteTimeGetCurrent() < self.allowUntil;
}
@end
static const void *JTInputDelegateKey = &JTInputDelegateKey;
#endif

void JTAllowProgrammaticFocus(WKWebView *webView, NSTimeInterval seconds) {
#if TARGET_OS_IOS
    SEL setter = NSSelectorFromString(@"_setInputDelegate:");
    if (![webView respondsToSelector:setter]) return;
    JTInputDelegate *delegate = objc_getAssociatedObject(webView, JTInputDelegateKey);
    if (!delegate) {
        delegate = [JTInputDelegate new];
        objc_setAssociatedObject(webView, JTInputDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ((void (*)(id, SEL, id))objc_msgSend)(webView, setter, delegate);
        JTNote(@"InputDelegate=on");
    }
    delegate.allowUntil = CFAbsoluteTimeGetCurrent() + seconds;
#endif
}
