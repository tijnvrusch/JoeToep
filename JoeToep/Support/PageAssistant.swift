// V26 — Pagina-assistent (zoals Dia): samenvatten, kernpunten en vragen over de open pagina.
// 1. Apple Intelligence (on-device Foundation Models) als het apparaat dat ondersteunt en het aan staat.
// 2. Anders (of bij een fout) de ingebouwde, offline methode uit Models/PageDigest.swift.
// De paginatekst verlaat het apparaat nooit.
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class PageAssistantModel: ObservableObject {
    enum Engine: Equatable {
        case appleIntelligence, builtIn
        var title: String { self == .appleIntelligence ? "Apple Intelligence (on device)" : "Built-in (offline)" }
        var symbol: String { self == .appleIntelligence ? "sparkles" : "text.alignleft" }
    }
    @Published private(set) var page: PageContent?
    @Published private(set) var lines: [String] = []
    @Published private(set) var keywords: [String] = []
    @Published private(set) var engine: Engine = .builtIn
    @Published private(set) var busy = false
    @Published private(set) var loading = false
    @Published private(set) var message: String?
    @Published var mode: PageDigest.Mode = .summary
    @Published var question = ""
    private var task: Task<Void, Never>?
    private var loadedKey: String?

    static var appleIntelligenceAvailable: Bool { TabTitleSummarizer.appleIntelligenceAvailable }

    /// Pagina (opnieuw) inlezen; gebeurt alleen als het adres veranderde, of met `force`.
    func load(from session: WebSession, force: Bool = false) {
        let key = (session.currentURL?.absoluteString ?? "") + "|" + (session.pageTitle ?? "")
        guard force || key != loadedKey else { return }
        loadedKey = key
        task?.cancel()
        loading = true; message = nil; lines = []; keywords = []
        task = Task { [weak self, weak session] in
            guard let session else { return }
            let page = await session.readPage()
            guard let self, !Task.isCancelled else { return }
            self.loading = false
            self.page = page
            guard let page else {
                self.message = session.showsNewTabPage ? "Open a page to use the assistant." : "This page has no readable text yet."
                return
            }
            self.keywords = PageDigest.keywords(in: page.summary + " " + page.text, limit: 8)
            if V26Prefs.assistantAutoSummary() { self.run(.summary) }
        }
    }

    func run(_ mode: PageDigest.Mode, question: String? = nil) {
        guard let page else { return }
        self.mode = mode
        let asked = question?.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode == .question && (asked ?? "").isEmpty { message = "Type a question first."; return }
        task?.cancel()
        busy = true; message = nil
        let count = V26Prefs.assistantSentences()
        let useApple = V26Prefs.assistantAppleIntelligence() && Self.appleIntelligenceAvailable
        task = Task { [weak self] in
            var result: [String]? = nil
            var used = Engine.builtIn
            if useApple, let lines = await Self.appleResponse(mode: mode, page: page, question: asked, count: count), !lines.isEmpty {
                result = lines; used = .appleIntelligence
            }
            if result == nil { result = Self.builtInResponse(mode: mode, page: page, question: asked, count: count) }
            guard let self, !Task.isCancelled else { return }
            self.busy = false
            self.engine = used
            self.lines = result ?? []
            if self.lines.isEmpty {
                self.message = mode == .question ? "The page doesn't seem to answer that." : "Not enough text on this page to summarise."
            }
        }
    }

    func cancel() { task?.cancel(); busy = false; loading = false }

    /// Het antwoord als platte tekst (voor kopiëren).
    var plainText: String {
        switch mode {
        case .keyPoints: lines.map { "• " + $0 }.joined(separator: "\n")
        default: lines.joined(separator: mode == .summary ? " " : "\n")
        }
    }

    nonisolated static func builtInResponse(mode: PageDigest.Mode, page: PageContent, question: String?, count: Int) -> [String] {
        switch mode {
        case .summary: PageDigest.summary(of: page, count: count)
        case .keyPoints: PageDigest.keyPoints(of: page, count: count)
        case .question: PageDigest.answer(question ?? "", from: page, count: min(count, 4))
        }
    }

    /// Regels uit een modelantwoord: opsommingstekens en lege regels eruit.
    nonisolated static func lines(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t•-*–")) }
            .filter { !$0.isEmpty }
    }

    private static func appleResponse(mode: PageDigest.Mode, page: PageContent, question: String?, count: Int) async -> [String]? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            let session = LanguageModelSession(instructions: PageDigest.instructions(for: mode, sentences: count))
            // Het on-device model heeft een beperkt contextvenster: hooguit ±8.000 tekens paginatekst.
            var prompt = PageDigest.promptContext(page, limit: 8_000)
            if let question, mode == .question { prompt += "\n\nQuestion: " + question }
            else { prompt += "\n\nTask: " + (mode == .summary ? "summarise this page." : "list the key points of this page.") }
            do {
                let response = try await session.respond(to: prompt)
                let lines = Self.lines(from: response.content)
                return mode == .summary ? [lines.joined(separator: " ")] : lines
            } catch { return nil }
        }
        #endif
        return nil
    }
}
