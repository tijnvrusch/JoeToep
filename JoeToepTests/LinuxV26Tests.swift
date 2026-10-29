// V26 — Unit tests voor de pure V26-logica (Spaces, Split View, Boosts, pagina-assistent, voorkeuren,
// tab-opslag). Draaien in Xcode (JoeToepTests) én op Linux: `Scripts/linux_swift_tests.sh`.
import XCTest
@testable import JoeToep

final class LinuxV26Tests: XCTestCase {
    private func freshDefaults() -> (UserDefaults, String) {
        let suite = "LinuxV26Tests." + UUID().uuidString
        return (UserDefaults(suiteName: suite)!, suite)
    }

    // MARK: Tab-opslag (bugfix: groepen en Spaces bleven na een herstart niet bewaard)

    @MainActor func testSavedTabsKeepGroupAndSpaceAcrossRelaunch() throws {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let group = UUID(), space = UUID()
        var tab = SavedBrowserTab(url: URL(string: "https://www.youtube.com/watch?v=abc"), pinned: nil, title: "A")
        tab.groupID = group; tab.spaceID = space
        let other = SavedBrowserTab(url: URL(string: "https://www.youtube.com/"))
        TabSessionStore(defaults: defaults).save(SavedTabSession(tabs: [tab, other], selectedID: tab.id), window: UUID())
        let restored = try XCTUnwrap(TabSessionStore(defaults: defaults).restore())
        XCTAssertEqual(restored.tabs.first?.groupID, group, "groupID must survive a relaunch")
        XCTAssertEqual(restored.tabs.first?.spaceID, space, "spaceID must survive a relaunch")
        XCTAssertNil(restored.tabs.last?.groupID)
    }

    @MainActor func testSanitizedOnlyCleansTheURL() {
        var tab = SavedBrowserTab(url: URL(string: "https://accounts.google.com/x"), time: 12, playing: true, pinned: true, title: "T")
        tab.groupID = UUID(); tab.spaceID = UUID()
        let clean = TabSessionStore.sanitized(tab)
        XCTAssertNil(clean.url)
        var expected = tab; expected.url = nil
        XCTAssertEqual(clean, expected)
    }

    func testOldSavedDataWithoutSpaceStillDecodes() throws {
        let json = #"{"tabs":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","url":"https://www.youtube.com/"}],"selectedID":"6F9619FF-8B86-D011-B42D-00C04FC964FF"}"#
        let session = try JSONDecoder().decode(SavedTabSession.self, from: Data(json.utf8))
        XCTAssertNil(session.tabs[0].spaceID)
        XCTAssertNil(session.tabs[0].groupID)
    }

    // MARK: Spaces

    func testNormalizedAlwaysHasAValidFirstSpace() {
        XCTAssertEqual(SpaceLogic.normalized([]).count, 1)
        XCTAssertEqual(SpaceLogic.normalized([]).first?.name, "Home")
        let a = BrowserSpace(name: "  ", symbol: "", color: "nope")
        let normalized = SpaceLogic.normalized([a, a])
        XCTAssertEqual(normalized.count, 1, "duplicate ids are dropped")
        XCTAssertEqual(normalized[0].name, "Space")
        XCTAssertEqual(normalized[0].symbol, "circle.fill")
        XCTAssertTrue(SpaceLogic.palette.contains(normalized[0].color))
        let many = (0..<30).map { BrowserSpace(name: "S\($0)", symbol: "star.fill", color: "blue") }
        XCTAssertEqual(SpaceLogic.normalized(many).count, SpaceLogic.maximumCount)
        XCTAssertEqual(SpaceLogic.cleanName(String(repeating: "x", count: 100)).count, 40)
    }

    func testResolveFallsBackToFirstSpace() {
        let spaces = [BrowserSpace(name: "A", symbol: "house.fill", color: "blue"), BrowserSpace(name: "B", symbol: "music.note", color: "red")]
        XCTAssertEqual(SpaceLogic.resolve(nil, in: spaces), spaces[0].id)
        XCTAssertEqual(SpaceLogic.resolve(UUID(), in: spaces), spaces[0].id, "unknown (deleted) space → first space")
        XCTAssertEqual(SpaceLogic.resolve(spaces[1].id, in: spaces), spaces[1].id)
    }

    func testVisibilityAndPinnedFavourites() {
        let home = BrowserSpace(name: "Home", symbol: "house.fill", color: "blue")
        let music = BrowserSpace(name: "Music", symbol: "music.note", color: "pink")
        let spaces = [home, music]
        let loose = SpaceMember(id: UUID(), spaceID: nil, pinned: false)          // oud/gesynct → Home
        let inMusic = SpaceMember(id: UUID(), spaceID: music.id, pinned: false)
        let pinnedMusic = SpaceMember(id: UUID(), spaceID: music.id, pinned: true)
        let members = [loose, inMusic, pinnedMusic]
        XCTAssertEqual(SpaceLogic.visibleIDs(members, active: home.id, spaces: spaces, pinnedEverywhere: true), [loose.id, pinnedMusic.id])
        XCTAssertEqual(SpaceLogic.visibleIDs(members, active: home.id, spaces: spaces, pinnedEverywhere: false), [loose.id])
        XCTAssertEqual(SpaceLogic.visibleIDs(members, active: music.id, spaces: spaces, pinnedEverywhere: false), [inMusic.id, pinnedMusic.id])
    }

    func testSelectionAfterSwitchPrefersLastUsedThenLooseThenPinned() {
        let home = BrowserSpace(name: "Home", symbol: "house.fill", color: "blue")
        let work = BrowserSpace(name: "Work", symbol: "briefcase.fill", color: "green")
        let empty = BrowserSpace(name: "Empty", symbol: "star.fill", color: "gray")
        let spaces = [home, work, empty]
        let pinned = SpaceMember(id: UUID(), spaceID: home.id, pinned: true)
        let w1 = SpaceMember(id: UUID(), spaceID: work.id, pinned: false)
        let w2 = SpaceMember(id: UUID(), spaceID: work.id, pinned: false)
        let members = [pinned, w1, w2]
        XCTAssertEqual(SpaceLogic.selectionAfterSwitch(to: work.id, lastSelected: [work.id: w2.id], members: members, spaces: spaces, pinnedEverywhere: true), w2.id)
        XCTAssertEqual(SpaceLogic.selectionAfterSwitch(to: work.id, lastSelected: [work.id: UUID()], members: members, spaces: spaces, pinnedEverywhere: true), w1.id,
                       "a closed last tab falls back to the first loose tab")
        XCTAssertEqual(SpaceLogic.selectionAfterSwitch(to: empty.id, lastSelected: [:], members: members, spaces: spaces, pinnedEverywhere: true), pinned.id,
                       "an empty space shows a favourite")
        XCTAssertNil(SpaceLogic.selectionAfterSwitch(to: empty.id, lastSelected: [:], members: members, spaces: spaces, pinnedEverywhere: false),
                     "an empty space without favourites → nil (app opens a new tab)")
    }

    func testNeighbourRemovingAndMoving() throws {
        let spaces = (0..<3).map { BrowserSpace(name: "S\($0)", symbol: "star.fill", color: SpaceLogic.palette[$0]) }
        XCTAssertEqual(SpaceLogic.neighbour(of: spaces[2].id, in: spaces, offset: 1), spaces[0].id)
        XCTAssertEqual(SpaceLogic.neighbour(of: spaces[0].id, in: spaces, offset: -1), spaces[2].id)
        XCTAssertEqual(SpaceLogic.neighbour(of: UUID(), in: spaces, offset: 1), spaces[1].id)
        XCTAssertNil(SpaceLogic.neighbour(of: UUID(), in: [], offset: 1))
        let removed = try XCTUnwrap(SpaceLogic.removing(spaces[1].id, from: spaces))
        XCTAssertEqual(removed.spaces.map(\.id), [spaces[0].id, spaces[2].id])
        XCTAssertEqual(removed.fallback, spaces[0].id)
        XCTAssertEqual(SpaceLogic.removing(spaces[0].id, from: spaces)?.fallback, spaces[1].id)
        XCTAssertNil(SpaceLogic.removing(spaces[0].id, from: [spaces[0]]), "the last space can never be removed")
        XCTAssertEqual(SpaceLogic.moving(spaces[0].id, by: 1, in: spaces).map(\.id), [spaces[1].id, spaces[0].id, spaces[2].id])
        XCTAssertEqual(SpaceLogic.moving(spaces[0].id, by: -5, in: spaces), spaces)
        XCTAssertEqual(SpaceLogic.moving(spaces[2].id, by: 9, in: spaces), spaces)
    }

    func testMakeSpaceUsesUnusedColourAndSymbol() {
        var spaces = [SpaceLogic.defaultSpace()]
        for i in 0..<8 { spaces.append(SpaceLogic.makeSpace(named: "S\(i)", existing: spaces)) }
        XCTAssertEqual(Set(spaces.map(\.color)).count, spaces.count, "every new space gets its own colour while the palette lasts")
        XCTAssertEqual(Set(spaces.map(\.symbol)).count, spaces.count)
        XCTAssertTrue(BrowserSpace(name: "x", symbol: "🎧", color: "blue").symbolIsEmoji)
        XCTAssertFalse(BrowserSpace(name: "x", symbol: "music.note", color: "blue").symbolIsEmoji)
    }

    func testSpaceStoreRoundTrip() {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(SpaceStore.load(defaults).count, 1)
        let spaces = [SpaceLogic.defaultSpace(), BrowserSpace(name: "Music", symbol: "🎵", color: "pink")]
        SpaceStore.save(spaces, defaults)
        XCTAssertEqual(SpaceStore.load(defaults), spaces)
        XCTAssertNil(SpaceStore.loadActive(defaults))
        SpaceStore.saveActive(spaces[1].id, defaults)
        XCTAssertEqual(SpaceStore.loadActive(defaults), spaces[1].id)
        defaults.set(Data("garbage".utf8), forKey: SpaceStore.key)
        XCTAssertEqual(SpaceStore.load(defaults).count, 1, "corrupt data → one default space")
    }

    /// Stress: duizenden willekeurige bewerkingen; er is altijd minstens één Space en elke tab is zichtbaar
    /// in precies één Space (of in alle, als hij vastgezet is).
    func testSpacesStressInvariants() {
        var generator = SeededGenerator(seed: 26)
        var spaces = [SpaceLogic.defaultSpace()]
        var members: [SpaceMember] = []
        for _ in 0..<5_000 {
            switch Int.random(in: 0..<6, using: &generator) {
            case 0 where spaces.count < SpaceLogic.maximumCount: spaces.append(SpaceLogic.makeSpace(named: "S", existing: spaces))
            case 1:
                if let victim = spaces.randomElement(using: &generator), let result = SpaceLogic.removing(victim.id, from: spaces) {
                    spaces = result.spaces
                    members = members.map { m in var m = m; if m.spaceID == victim.id { m.spaceID = result.fallback }; return m }
                }
            case 2: members.append(SpaceMember(id: UUID(), spaceID: spaces.randomElement(using: &generator)?.id, pinned: Bool.random(using: &generator)))
            case 3: if !members.isEmpty { members.remove(at: Int.random(in: 0..<members.count, using: &generator)) }
            case 4: if let s = spaces.randomElement(using: &generator) { spaces = SpaceLogic.moving(s.id, by: Int.random(in: -3...3, using: &generator), in: spaces) }
            default: spaces = SpaceLogic.normalized(spaces)
            }
            XCTAssertFalse(spaces.isEmpty)
            for member in members where !member.pinned {
                let visibleIn = spaces.filter { SpaceLogic.isVisible(member, active: $0.id, spaces: spaces, pinnedEverywhere: true) }
                XCTAssertEqual(visibleIn.count, 1)
            }
        }
    }

    // MARK: Split View

    func testSplitClampArrangementAndFrames() {
        XCTAssertEqual(SplitLayout.clamp(0.05), 0.2)
        XCTAssertEqual(SplitLayout.clamp(0.95), 0.8)
        XCTAssertEqual(SplitLayout.clamp(.nan), 0.5)
        XCTAssertEqual(SplitLayout.arrangement(width: 1200, height: 800, prefersVertical: false), .sideBySide)
        XCTAssertEqual(SplitLayout.arrangement(width: 500, height: 800, prefersVertical: false), .stacked)
        XCTAssertEqual(SplitLayout.arrangement(width: 500, height: 400, prefersVertical: false), .single)
        XCTAssertEqual(SplitLayout.arrangement(width: 1200, height: 800, prefersVertical: true), .stacked)
        XCTAssertEqual(SplitLayout.arrangement(width: 1200, height: 400, prefersVertical: true), .sideBySide)
        for width in stride(from: 640.0, through: 3000, by: 37) {
            for fraction in stride(from: 0.0, through: 1.0, by: 0.05) {
                let f = SplitLayout.frames(width: width, height: 700, fraction: fraction, arrangement: .sideBySide, gap: 6)
                XCTAssertEqual(f.first.width + 6 + f.second.width, width, accuracy: 0.001)
                XCTAssertEqual(f.second.minX, f.first.maxX + 6, accuracy: 0.001)
                XCTAssertGreaterThanOrEqual(f.first.width, (width - 6) * 0.2 - 1)
            }
        }
        let stacked = SplitLayout.frames(width: 400, height: 900, fraction: 0.5, arrangement: .stacked, gap: 4)
        XCTAssertEqual(stacked.first.height + 4 + stacked.second.height, 900, accuracy: 0.001)
        XCTAssertEqual(SplitLayout.frames(width: 300, height: 300, fraction: 0.5, arrangement: .single, gap: 4).second, .zero)
    }

    func testSplitDragValidationPartnerAndSwap() {
        XCTAssertEqual(SplitLayout.fraction(start: 0.5, translation: 100, total: 1000), 0.6, accuracy: 0.0001)
        XCTAssertEqual(SplitLayout.fraction(start: 0.5, translation: -900, total: 1000), 0.2)
        XCTAssertEqual(SplitLayout.fraction(start: 0.7, translation: 50, total: 0), 0.7)
        let a = UUID(), b = UUID(), c = UUID()
        XCTAssertNil(SplitLayout.validated(SplitPair(primary: a, secondary: a), existing: [a]))
        XCTAssertNil(SplitLayout.validated(SplitPair(primary: a, secondary: b), existing: [a]), "a closed pane ends the split")
        XCTAssertEqual(SplitLayout.validated(SplitPair(primary: a, secondary: b, fraction: 3), existing: [a, b])?.fraction, 0.8)
        XCTAssertEqual(SplitLayout.partnerCandidate(for: b, recent: [a, c, b], order: [a, b, c]), c)
        XCTAssertEqual(SplitLayout.partnerCandidate(for: b, recent: [], order: [a, b, c]), c)
        XCTAssertEqual(SplitLayout.partnerCandidate(for: c, recent: [], order: [a, b, c]), b)
        XCTAssertEqual(SplitLayout.partnerCandidate(for: b, recent: [], order: [a, b, c], excluded: [c]), a)
        XCTAssertNil(SplitLayout.partnerCandidate(for: a, recent: [], order: [a]))
        let pair = SplitPair(primary: a, secondary: b, fraction: 0.3)
        XCTAssertEqual(pair.partner(of: a), b); XCTAssertEqual(pair.partner(of: b), a); XCTAssertNil(pair.partner(of: c))
        XCTAssertEqual(pair.swapped().primary, b)
        XCTAssertEqual(pair.swapped().fraction, 0.7, accuracy: 0.0001)
        XCTAssertEqual(pair.swapped().swapped().primary, pair.primary)
        XCTAssertEqual(pair.swapped().swapped().fraction, pair.fraction, accuracy: 1e-9)
    }

    // MARK: Boosts

    func testSiteKeys() {
        XCTAssertEqual(BoostStore.siteKey(for: URL(string: "https://www.youtube.com/watch?v=1")), "youtube.com")
        XCTAssertEqual(BoostStore.siteKey(for: URL(string: "https://m.youtube.com/")), "youtube.com")
        XCTAssertEqual(BoostStore.siteKey(for: URL(string: "https://music.youtube.com/")), "music.youtube.com")
        XCTAssertEqual(BoostStore.siteKey(for: URL(string: "https://WWW.Example.COM/a")), "example.com")
        XCTAssertEqual(BoostStore.siteKey(for: URL(string: "https://m.com/")), "m.com", "a two-label host keeps its name")
        XCTAssertNil(BoostStore.siteKey(for: URL(string: "file:///tmp/x.html")))
        XCTAssertNil(BoostStore.siteKey(for: nil))
    }

    func testStylesheetPresetsOnlyWhereTheyApply() {
        var yt = SiteBoost(site: "youtube.com")
        yt.presets = [.hideComments, .noAnimations]
        XCTAssertTrue(yt.stylesheet.contains("ytd-comments#comments"))
        XCTAssertTrue(yt.stylesheet.contains("animation-duration: 0s"))
        var other = SiteBoost(site: "example.com")
        other.presets = [.hideComments, .underlineLinks]
        XCTAssertFalse(other.stylesheet.contains("ytd-comments"), "YouTube presets never apply to other sites")
        XCTAssertTrue(other.stylesheet.contains("text-decoration: underline"))
        yt.enabled = false
        XCTAssertEqual(yt.stylesheet, "")
    }

    func testStylesheetFontFilterBackgroundWidthAndCustomCSS() {
        var boost = SiteBoost(site: "example.com")
        boost.font = .serif; boost.filter = .dark; boost.backgroundHex = "#abc"; boost.readingWidth = 50
        boost.customCSS = "@import url(https://evil.example/x.css);\nh1 { color: red }\n</style><script>"
        let css = boost.stylesheet
        XCTAssertTrue(css.contains("\"New York\""))
        XCTAssertTrue(css.contains("invert(1) hue-rotate(180deg)"))
        XCTAssertTrue(css.contains("img, picture, video"), "dark filter re-inverts media")
        XCTAssertTrue(css.contains("#AABBCC"))
        XCTAssertTrue(css.contains("max-width: 480px"), "reading width is clamped")
        XCTAssertFalse(css.contains("@import"))
        XCTAssertFalse(css.contains("</"))
        XCTAssertTrue(css.contains("h1 { color: red }"))
        XCTAssertEqual(boost.changeCount, 5)
        XCTAssertNil(SiteBoost.validHex("#12345")); XCTAssertNil(SiteBoost.validHex("zzz"))
        XCTAssertEqual(SiteBoost.validHex("0f0f0f"), "#0F0F0F")
    }

    func testZapSelectorSanitising() {
        for good in ["#secondary", "ytd-rich-shelf-renderer", "div.card > a:nth-of-type(2)", "[aria-label=\"Shorts\"]", "a[href*='promo']"] {
            XCTAssertEqual(SiteBoost.sanitizedSelector(good), good)
        }
        for bad in ["", "   ", "a { color: red }", "a;b", "a</style>", "@media", "div(", "a]", "[x=\"1]", "a\\", String(repeating: "a", count: 401)] {
            XCTAssertNil(SiteBoost.sanitizedSelector(bad), bad)
        }
        var boost = SiteBoost(site: "x.com")
        XCTAssertTrue(boost.addHidden(" .ad "))
        XCTAssertFalse(boost.addHidden(".ad"), "duplicates are ignored")
        XCTAssertFalse(boost.addHidden("}"))
        XCTAssertEqual(boost.hiddenSelectors, [".ad"])
        XCTAssertTrue(boost.stylesheet.contains(".ad { display: none !important; }"))
    }

    func testBoostPayloadAndStore() throws {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = URL(string: "https://www.youtube.com/watch?v=1")
        XCTAssertEqual(BoostStore.payload(for: url, globallyEnabled: true, defaults), BoostStore.emptyPayload)
        var boost = SiteBoost(site: "youtube.com")
        boost.addHidden("#chat")
        boost.customCSS = "p { content: \"\u{2028}\" }"
        BoostStore.save(boost, defaults)
        XCTAssertEqual(BoostStore.boost(for: URL(string: "https://m.youtube.com/"), defaults), boost)
        let payload = BoostStore.payload(for: url, globallyEnabled: true, defaults)
        XCTAssertFalse(payload.contains("\u{2028}"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
        XCTAssertEqual(object["enabled"] as? Bool, true)
        XCTAssertEqual(object["site"] as? String, "youtube.com")
        XCTAssertTrue((object["css"] as? String)?.contains("#chat { display: none !important; }") == true)
        XCTAssertEqual(BoostStore.payload(for: url, globallyEnabled: false, defaults), BoostStore.emptyPayload)
        // Een lege boost wordt niet bewaard.
        BoostStore.save(SiteBoost(site: "youtube.com"), defaults)
        XCTAssertNil(BoostStore.boost(for: url, defaults))
        BoostStore.save(boost, defaults)
        BoostStore.remove(site: "youtube.com", defaults)
        XCTAssertTrue(BoostStore.loadAll(defaults).isEmpty)
    }

    func testBootstrapContainsEveryEnabledBoostAsValidJSON() throws {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(BoostStore.bootstrap(globallyEnabled: true, defaults), "{}")
        var a = SiteBoost(site: "youtube.com"); a.presets = [.hideComments]
        var b = SiteBoost(site: "example.com"); b.customCSS = "p { content: \"}\" }"
        var c = SiteBoost(site: "off.com"); c.addHidden(".x"); c.enabled = false
        for boost in [a, b, c] { BoostStore.save(boost, defaults) }
        let json = BoostStore.bootstrap(globallyEnabled: true, defaults)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: [String: Any]])
        XCTAssertEqual(Set(object.keys), ["youtube.com", "example.com"], "disabled boosts are left out")
        XCTAssertTrue((object["example.com"]?["css"] as? String)?.contains("content: \"}\"") == true)
        XCTAssertEqual(BoostStore.bootstrap(globallyEnabled: false, defaults), "{}")
    }

    // MARK: Pagina-assistent

    private let article = PageContent(
        title: "Solar panels on balconies",
        url: URL(string: "https://example.com/solar"),
        text: """
        Home
        Menu
        Balcony solar panels are small solar systems that you can plug into a normal wall socket. They usually deliver between 300 and 800 watts of solar power.
        Many cities now allow balcony solar panels without a permit. The panels pay for themselves in about five years, depending on the amount of sun.
        Installation takes less than an hour because no electrician is needed. You only need a sturdy railing and a nearby wall socket.
        The weather in winter strongly reduces the output of solar panels. In summer a single panel can cover the standby power of a whole household.
        Read more about energy.
        """,
        summary: "A guide to balcony solar panels: costs, rules and output.")

    func testSentenceSplittingSkipsMenusAndShortLines() {
        let sentences = PageDigest.sentences(in: article.text)
        XCTAssertFalse(sentences.contains("Home"))
        XCTAssertFalse(sentences.contains("Read more about energy."))
        XCTAssertEqual(sentences.count, 8)
        XCTAssertTrue(sentences[0].hasPrefix("Balcony solar panels are small"))
        XCTAssertEqual(PageDigest.sentences(in: "Version 2.5 is out now and it is much faster than before. Great news for everyone today!").count, 2,
                       "a decimal point does not end a sentence")
    }

    func testKeywordsAndSummary() {
        let keywords = PageDigest.keywords(in: article.text, limit: 5)
        XCTAssertEqual(keywords.first, "solar")
        XCTAssertTrue(keywords.contains("panels"))
        XCTAssertFalse(keywords.contains("the"))
        let summary = PageDigest.summary(of: article, count: 3)
        XCTAssertEqual(summary.count, 3)
        let pool = PageDigest.sentences(in: article.summary + "\n" + article.text)
        let positions = summary.compactMap { pool.firstIndex(of: $0) }
        XCTAssertEqual(positions, positions.sorted(), "summary keeps the page order")
        XCTAssertEqual(PageDigest.summary(of: PageContent(title: "x", url: nil, text: ""), count: 3), [])
        XCTAssertEqual(PageDigest.keyPoints(of: article, count: 4).count, 4)
    }

    // V26.1: links en datums in een YouTube-beschrijving zijn geen onderwerpen.
    func testKeywordsSkipLinksAndDates() {
        let text = """
        Remix live show Oct 18th at the theatre! Tickets https://www.example.com/tickets?id=3 and spotify.com/remix.
        Follow on https://linktr.ee/remix — remix remix theatre synthesizer. Next show oct 25th, www.shows.nl/remix
        """
        let keywords = PageDigest.keywords(in: text)
        XCTAssertEqual(keywords.first, "remix")
        XCTAssertTrue(keywords.contains("theatre"))
        for noise in ["https", "www", "com", "oct", "18th", "25th", "linktr", "example", "spotify"] {
            XCTAssertFalse(keywords.contains(noise), noise)
        }
    }

    func testAnswerFindsTheRelevantSentence() {
        let permit = PageDigest.answer("Do I need a permit?", from: article, count: 1)
        XCTAssertEqual(permit.count, 1)
        XCTAssertTrue(permit[0].contains("permit"))
        let install = PageDigest.answer("How long does installation take?", from: article, count: 1)
        XCTAssertTrue(install.first?.contains("less than an hour") == true)
        XCTAssertEqual(PageDigest.answer("What about quantum chromodynamics?", from: article), [], "nothing relevant → no answer")
        XCTAssertEqual(PageDigest.answer("the of and", from: article), [], "a question of only stop words → no answer")
    }

    func testReadingTimeShortenAndPromptContext() {
        XCTAssertEqual(PageDigest.readingMinutes(PageContent(title: "", url: nil, text: String(repeating: "word ", count: 221))), 2)
        XCTAssertEqual(PageDigest.readingMinutes(PageContent(title: "", url: nil, text: "")), 1)
        let short = PageDigest.shorten("one two three four five six", to: 12)
        XCTAssertTrue(short.hasSuffix("…")); XCTAssertLessThanOrEqual(short.count, 13)
        XCTAssertEqual(PageDigest.shorten("short", to: 12), "short")
        let long = PageContent(title: "T", url: nil, text: String(repeating: "a", count: 50_000))
        XCTAssertLessThanOrEqual(PageDigest.promptContext(long, limit: 2_000).count, 2_000)
        XCTAssertTrue(PageDigest.promptContext(article).contains("Description: A guide"))
        for mode in PageDigest.Mode.allCases { XCTAssertTrue(PageDigest.instructions(for: mode, sentences: 4).contains("4")) }
    }

    // MARK: Voorkeuren

    func testPreferenceDefaultsClampingAndReset() {
        let (d, suite) = freshDefaults()
        defer { d.removePersistentDomain(forName: suite) }
        XCTAssertTrue(V26Prefs.spacesEnabled(d)); XCTAssertTrue(V26Prefs.pinnedEverywhere(d))
        XCTAssertTrue(V26Prefs.splitEnabled(d)); XCTAssertEqual(V26Prefs.splitFraction(d), 0.5)
        XCTAssertTrue(V26Prefs.peekEnabled(d)); XCTAssertEqual(V26Prefs.peekSize(d), 0.84)
        XCTAssertTrue(V26Prefs.boostsEnabled(d)); XCTAssertTrue(V26Prefs.assistantEnabled(d))
        XCTAssertEqual(V26Prefs.assistantSentences(d), 5)
        d.set(9.0, forKey: V26Prefs.Key.splitFraction); XCTAssertEqual(V26Prefs.splitFraction(d), 0.8)
        d.set(0.1, forKey: V26Prefs.Key.peekSize); XCTAssertEqual(V26Prefs.peekSize(d), 0.5)
        d.set(99, forKey: V26Prefs.Key.assistantSentences); XCTAssertEqual(V26Prefs.assistantSentences(d), 12)
        d.set(100.0, forKey: V26Prefs.Key.splitGap); XCTAssertEqual(V26Prefs.splitGap(d), 24)
        d.set(false, forKey: V26Prefs.Key.spacesEnabled); XCTAssertFalse(V26Prefs.spacesEnabled(d))
        V26Prefs.reset(d)
        XCTAssertTrue(V26Prefs.spacesEnabled(d)); XCTAssertEqual(V26Prefs.splitFraction(d), 0.5); XCTAssertEqual(V26Prefs.assistantSentences(d), 5)
    }
}

/// Voorspelbare willekeur voor stresstests (zelfde volgorde bij elke run).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}
