#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN
/// Runtime-checked WebKit SPI for this personal, non-App-Store build.
FOUNDATION_EXPORT BOOL JTConfigureMedia(WKWebViewConfiguration *configuration);
/// -1 unavailable, 0 not eligible, 1 already active, 2 start requested.
FOUNDATION_EXPORT NSInteger JTStartNativePiP(WKWebView *webView);
FOUNDATION_EXPORT BOOL JTNativePiPIsActive(WKWebView *webView);
FOUNDATION_EXPORT void JTSetBackgroundMediaProtection(WKWebView *webView, BOOL enabled);
/// V10: MediaSource on/off. Off makes YouTube use Apple HLS/URL media: real video AirPlay and a
/// stream URL that a native AVKit PiP pipeline can prepare before the app is left.
FOUNDATION_EXPORT BOOL JTSetMediaSourceEnabled(WKWebViewConfiguration *configuration, BOOL enabled);
/// Human-readable list of the runtime SPI switches that were actually available.
FOUNDATION_EXPORT NSString *JTMediaConfigurationSummary(void);
/// V11: allow the next programmatic focus (e.g. YouTube search in a new tab) to show the
/// iOS keyboard for `seconds`. Uses WebKit's input delegate SPI; no effect on macOS.
FOUNDATION_EXPORT void JTAllowProgrammaticFocus(WKWebView *webView, NSTimeInterval seconds);
NS_ASSUME_NONNULL_END
