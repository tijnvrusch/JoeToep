import XCTest
@testable import JoeToep

/// V26: Spaces, Split View en Peek op werkruimteniveau (BrowserWorkspace met een eigen tab-opslag).
/// De pure logica (SpaceLogic, SplitLayout, Boosts, PageDigest) staat in LinuxV26Tests.
@MainActor
final class V26FeatureTests: XCTestCase {
    private var suite = ""
    private let touchedKeys = [SpaceStore.key, SpaceStore.activeKey, BoostStore.key, V26Prefs.Key.spacesEnabled,
                               V26Prefs.Key.pinnedEverywhere, V26Prefs.Key.splitEnabled, V26Prefs.Key.peekEnabled, "tabGroupsV21"]
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        suite = "V26FeatureTests." + UUID().uuidString
        // De Spaces staan in .standard (gedeeld door vensters): bewaren en na de test terugzetten.
        for key in touchedKeys { saved[key] = UserDefaults.standard.object(forKey: key); UserDefaults.standard.removeObject(forKey: key) }
    }
    override func tearDown() {
        for key in touchedKeys {
            if let value = saved[key] { UserDefaults.standard.set(value, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }
    private func makeWorkspace() -> BrowserWorkspace {
        BrowserWorkspace(store: TabSessionStore(defaults: UserDefaults(suiteName: suite)!))
    }

    func testVersionIs26() {
        XCTAssertTrue(AppConstants.version.hasPrefix("26."), "26.x")
    }

    func testNewTabsLandInTheActiveSpaceAndSwitchingRestoresTheLastTab() throws {
        let ws = makeWorkspace()
        let home = ws.activeSpaceID
        let first = ws.selected
        let music = try XCTUnwrap(ws.addSpace(named: "Music"))
        XCTAssertEqual(ws.activeSpaceID, music.id)
        XCTAssertNotEqual(ws.selectedID, first.id, "an empty Space opens with a new tab")
        let musicTab = ws.selected
        XCTAssertEqual(ws.spaceID(of: musicTab), music.id)
        ws.addTab(url: URL(string: "https://www.youtube.com/watch?v=music1"))
        let second = ws.selected
        XCTAssertEqual(ws.spaceID(of: second), music.id)
        XCTAssertEqual(Set(ws.visibleTabs.map(\.id)), [musicTab.id, second.id])
        ws.switchSpace(to: home)
        XCTAssertEqual(ws.selectedID, first.id, "back in Home the previous tab is shown")
        XCTAssertFalse(ws.visibleTabs.contains { $0.id == second.id })
        ws.switchSpace(to: music.id)
        XCTAssertEqual(ws.selectedID, second.id, "the last used tab of Music comes back")
    }

    func testSelectingATabInAnotherSpaceFollowsIntoThatSpace() throws {
        let ws = makeWorkspace()
        let home = ws.activeSpaceID
        let homeTab = ws.selected
        _ = try XCTUnwrap(ws.addSpace(named: "Work"))
        ws.select(homeTab)                     // bijv. via de zoekbalk of de sync
        XCTAssertEqual(ws.activeSpaceID, home)
    }

    func testPinnedTabsAreFavouritesInEverySpace() throws {
        let ws = makeWorkspace()
        let pinned = ws.selected
        ws.togglePin(pinned)
        _ = try XCTUnwrap(ws.addSpace(named: "Other"))
        XCTAssertTrue(ws.pinnedTabs.contains { $0.id == pinned.id })
        UserDefaults.standard.set(false, forKey: V26Prefs.Key.pinnedEverywhere)
        XCTAssertFalse(ws.pinnedTabs.contains { $0.id == pinned.id })
    }

    func testClosingTheLastTabOfASpaceKeepsYouInThatSpace() throws {
        let ws = makeWorkspace()
        let other = try XCTUnwrap(ws.addSpace(named: "Other"))
        let only = ws.selected
        ws.close(only)
        XCTAssertEqual(ws.activeSpaceID, other.id)
        XCTAssertEqual(ws.spaceID(of: ws.selected), other.id, "a fresh tab replaces the closed one in the same Space")
        XCTAssertNotEqual(ws.selectedID, only.id)
    }

    func testDeletingASpaceMovesItsTabs() throws {
        let ws = makeWorkspace()
        let home = ws.activeSpaceID
        let music = try XCTUnwrap(ws.addSpace(named: "Music"))
        let tab = ws.selected
        ws.deleteSpace(music.id, closingTabs: false)
        XCTAssertFalse(ws.spaces.contains { $0.id == music.id })
        XCTAssertEqual(ws.activeSpaceID, home)
        XCTAssertEqual(ws.spaceID(of: tab), home)
        ws.deleteSpace(home, closingTabs: false)
        XCTAssertEqual(ws.spaces.count, 1, "the last Space can never be deleted")
    }

    func testMoveTabToSpaceAndSpacesOff() throws {
        let ws = makeWorkspace()
        let home = ws.activeSpaceID
        ws.addTab(url: URL(string: "https://example.com/"))
        let tab = ws.selected
        let work = try XCTUnwrap(ws.addSpace(named: "Work", switchTo: false))
        ws.moveTab(tab, toSpace: work.id)
        XCTAssertEqual(ws.activeSpaceID, work.id, "the selected tab takes its Space along")
        ws.switchSpace(to: home)
        XCTAssertFalse(ws.visibleTabs.contains { $0.id == tab.id })
        UserDefaults.standard.set(false, forKey: V26Prefs.Key.spacesEnabled)
        XCTAssertEqual(ws.visibleTabs.count, ws.tabs.count, "with Spaces off every tab is visible")
    }

    func testSplitViewFocusClosingAndSelection() {
        let ws = makeWorkspace()
        let left = ws.selected
        ws.addTab(url: URL(string: "https://example.com/right"))
        let right = ws.selected
        ws.select(left)
        ws.openSplit(with: right)
        XCTAssertEqual(ws.split?.primary, left.id)
        XCTAssertEqual(ws.split?.secondary, right.id)
        XCTAssertTrue(ws.isOnScreen(left) && ws.isOnScreen(right))
        ws.select(right)                       // klik op het andere paneel = focus, Split blijft
        XCTAssertEqual(ws.selectedID, right.id)
        XCTAssertNotNil(ws.split)
        ws.swapSplitPanes()
        XCTAssertEqual(ws.split?.primary, right.id)
        ws.setSplitFraction(0.99)
        XCTAssertEqual(ws.split?.fraction, SplitLayout.maximumFraction)
        ws.close(right)                        // gesloten paneel → het andere krijgt de focus
        XCTAssertNil(ws.split)
        XCTAssertEqual(ws.selectedID, left.id)
    }

    func testSplitWithoutPartnerOpensANewTabAndEndsWhenAnotherTabIsChosen() {
        let ws = makeWorkspace()
        let only = ws.selected
        ws.openSplit()
        XCTAssertEqual(ws.tabs.count, 2, "no other tab → a new tab next to it")
        XCTAssertEqual(ws.split?.primary, only.id)
        ws.addTab(url: URL(string: "https://example.com/third"))
        XCTAssertNil(ws.split, "choosing a tab outside the split ends Split View")
        UserDefaults.standard.set(false, forKey: V26Prefs.Key.splitEnabled)
        ws.openSplit()
        XCTAssertNil(ws.split, "Split View off in Settings → nothing happens")
    }

    // V26.1: de lege tab die Split View zelf maakte, blijft na sluiten niet als lege Home-tab achter.
    func testSplitRemovesItsUntouchedBlankTabWhenClosed() {
        let ws = makeWorkspace()
        let only = ws.selected
        for _ in 0..<5 { ws.openSplit(); ws.closeSplit(keeping: only.id) }
        XCTAssertEqual(ws.tabs.count, 1, "5× open/close → still just the one tab")
        XCTAssertEqual(ws.selectedID, only.id)
        ws.openSplit()
        let blank = ws.tabs.first { $0.id != only.id }!
        ws.select(blank)                      // focus naar het lege paneel en dat houden
        ws.closeSplit()
        XCTAssertTrue(ws.tabs.contains { $0.id == blank.id }, "the pane you keep is never thrown away")
    }

    func testPeekIsNotATabUntilExpanded() throws {
        let ws = makeWorkspace()
        let opener = ws.selected
        let count = ws.tabs.count
        ws.openPeek(try XCTUnwrap(URL(string: "https://example.com/peek")), from: opener)
        let peek = try XCTUnwrap(ws.peekTab)
        XCTAssertEqual(ws.tabs.count, count, "Peek is never saved or synced as a tab")
        XCTAssertEqual(ws.selectedID, opener.id)
        ws.expandPeek()
        XCTAssertNil(ws.peekTab)
        XCTAssertEqual(ws.tabs.count, count + 1)
        XCTAssertEqual(ws.selectedID, peek.id)
        XCTAssertEqual(ws.tabs.firstIndex { $0.id == peek.id }, (ws.tabs.firstIndex { $0.id == opener.id } ?? 0) + 1)
        ws.openPeek(try XCTUnwrap(URL(string: "https://example.com/second")), from: ws.selected)
        ws.closePeek()
        XCTAssertNil(ws.peekTab)
        XCTAssertEqual(ws.tabs.count, count + 1)
        UserDefaults.standard.set(false, forKey: V26Prefs.Key.peekEnabled)
        ws.openPeek(try XCTUnwrap(URL(string: "https://example.com/off")), from: ws.selected)
        XCTAssertNil(ws.peekTab, "Peek off → the link opens as a normal tab")
        XCTAssertEqual(ws.tabs.count, count + 2)
    }

    func testGroupsAndTabsRememberTheirSpaceAfterRelaunch() throws {
        let defaults = UserDefaults(suiteName: suite)!
        let first = BrowserWorkspace(store: TabSessionStore(defaults: defaults))
        let work = try XCTUnwrap(first.addSpace(named: "Work"))
        let tab = first.selected
        let group = first.newGroup(named: "Project", with: tab)
        first.flushPendingPersist()
        let restored = try XCTUnwrap(TabSessionStore(defaults: defaults).restore())
        let savedTab = try XCTUnwrap(restored.tabs.first { $0.id == tab.id })
        XCTAssertEqual(savedTab.spaceID, work.id)
        XCTAssertEqual(savedTab.groupID, group.id)
        XCTAssertEqual(TabGroupStore.load().first { $0.id == group.id }?.spaceID, work.id)
    }

    /// Stress: 500 willekeurige Space-, Split- en tabbewerkingen; de werkruimte blijft altijd consistent.
    func testWorkspaceStressInvariants() {
        let ws = makeWorkspace()
        var generator = SeededGenerator(seed: 2026)
        for _ in 0..<500 {
            switch Int.random(in: 0..<9, using: &generator) {
            case 0: ws.addTab(url: URL(string: "https://example.com/\(Int.random(in: 0..<50, using: &generator))"))
            case 1: if ws.tabs.count > 1, let tab = ws.tabs.randomElement(using: &generator) { ws.close(tab) }
            case 2: if ws.spaces.count < 5 { ws.addSpace(named: "S") }
            case 3: if let s = ws.spaces.randomElement(using: &generator) { ws.switchSpace(to: s.id) }
            case 4: if let s = ws.spaces.randomElement(using: &generator), ws.spaces.count > 1 { ws.deleteSpace(s.id, closingTabs: Bool.random(using: &generator)) }
            case 5: if let tab = ws.visibleTabs.randomElement(using: &generator) { ws.select(tab) }
            case 6: ws.toggleSplit()
            case 7: if let tab = ws.tabs.randomElement(using: &generator), let s = ws.spaces.randomElement(using: &generator) { ws.moveTab(tab, toSpace: s.id) }
            default: ws.selectNext()
            }
            XCTAssertFalse(ws.tabs.isEmpty)
            XCTAssertTrue(ws.tabs.contains { $0.id == ws.selectedID }, "the selection always exists")
            XCTAssertTrue(ws.spaces.contains { $0.id == ws.activeSpaceID }, "the active Space always exists")
            XCTAssertTrue(ws.isInActiveSpace(ws.selected), "the selected tab is always in the active Space")
            if let pair = ws.split {
                XCTAssertTrue(pair.contains(ws.selectedID))
                XCTAssertTrue(ws.tabs.contains { $0.id == pair.primary } && ws.tabs.contains { $0.id == pair.secondary })
            }
            XCTAssertEqual(Set(ws.tabs.map(\.id)).count, ws.tabs.count, "no duplicate tabs")
        }
    }
}
