# Build report V16.2 — 16.2.0 (18), 26-09-2026

Xcode 27 beta, project `~/Documents/Claude/JoeToep V16`.

| Platform | Build | Installed and started | Automatic tests |
|---|---|---|---|
| iPhone 13 Pro "eiFoon" (iOS 27) | OK | OK | Full run: 54 unit + all UI suites, 0 failures (1 Mac-only test skipped) |
| iPad Pro 12.9 2nd gen (iOS 17.7) | OK | OK (build 20:41) | Not possible: the XCTest runner crashes on the A10X (`casal` in lib_TestingInterop) |
| Mac (macOS 27) | OK | OK | Mac UI tests need Automation Mode approval, so they were not run unattended; the unit tests are shared code |

JS test suites: `test_media_compatibility` 116/116 (including 10,000 transitions and 2,000 fullscreen cycles, no timers); `test_v15_scripts` 12/12; project validation 11 gates.

Device tests on the iPhone (V15DeviceTests + PiPDeviceTests + JoeToepUITests):
- 8 PiP → return-button cycles in a row: 8/8 fullscreen, keeps playing, no inline step.
- PiP return button, pause in PiP stays paused, new tab keeps PiP, landscape → fullscreen < 1.5 s.
- Stress test with 9 tabs, PiP, the Camera app and a quick return; PiP after a background return with 5 cycles and the Camera app.

Bugs found and fixed in this round:
1. From the second PiP return onwards the video landed inline: the app stepped in during the system restore animation, leaving WebKit in a stale PiP state.
2. The stale-PiP repair landed inline instead of fullscreen.
3. An unused new tab popped up the keyboard when you switched back to it.
4. The visualizer drew at 60 fps even in the background and during PiP.
