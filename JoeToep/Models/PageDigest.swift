// V26 — Pagina-assistent (zoals in Dia): vat de open pagina samen, geef de kernpunten of beantwoord een
// vraag over de pagina. Met Apple Intelligence (on-device, zie Support/PageAssistant.swift) als die er
// is; anders deze ingebouwde, offline methode: zinnen scoren op de belangrijkste woorden van de pagina
// (en van je vraag) en de beste in de oorspronkelijke volgorde tonen. Er gaat nooit tekst naar een server.
// Alleen Foundation: testbaar op Linux.
import Foundation

struct PageContent: Equatable, Sendable {
    var title: String
    var url: URL?
    var text: String
    /// Korte beschrijving (meta description of de beschrijving onder een YouTube-video).
    var summary: String = ""

    var wordCount: Int { PageDigest.words(in: text).count }
    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && summary.isEmpty }
}

enum PageDigest {
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        case summary, keyPoints, question
        var id: String { rawValue }
        var title: String {
            switch self {
            case .summary: "Summarise"
            case .keyPoints: "Key points"
            case .question: "Ask"
            }
        }
    }

    static let stopWords: Set<String> = [
        // Engels
        "the", "a", "an", "and", "or", "but", "if", "then", "of", "in", "on", "at", "to", "for", "with", "by", "from",
        "is", "are", "was", "were", "be", "been", "being", "it", "its", "this", "that", "these", "those", "as", "so",
        "we", "you", "they", "he", "she", "i", "me", "my", "our", "your", "their", "his", "her", "them", "us", "not",
        "do", "does", "did", "have", "has", "had", "will", "would", "can", "could", "should", "may", "might", "just",
        "about", "into", "over", "more", "most", "some", "any", "all", "also", "than", "there", "here", "what", "which",
        "who", "when", "where", "why", "how", "up", "out", "no", "yes", "very", "much", "many", "one", "two", "get",
        // Nederlands
        "de", "het", "een", "en", "of", "maar", "als", "dan", "van", "in", "op", "aan", "te", "voor", "met", "door",
        "uit", "is", "zijn", "was", "waren", "wordt", "worden", "werd", "dit", "dat", "deze", "die", "er", "hier", "daar",
        "wij", "we", "jij", "je", "u", "zij", "ze", "hij", "ik", "mij", "mijn", "ons", "onze", "jouw", "hun", "haar",
        "niet", "geen", "wel", "ook", "nog", "al", "om", "tot", "bij", "naar", "over", "onder", "heeft", "hebben", "had",
        "kan", "kunnen", "zal", "zou", "moet", "mag", "wat", "wie", "waar", "wanneer", "waarom", "hoe", "meer", "veel", "zo",
    ]

    /// Woorden (kleine letters, zonder leestekens, minstens 2 tekens).
    static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
    }

    /// Zinnen van redelijke lengte (te korte menu-items en te lange blokken vallen weg).
    static func sentences(in text: String) -> [String] {
        var result: [String] = []
        let normalized = text.replacingOccurrences(of: "\r", with: "\n")
        for block in normalized.components(separatedBy: "\n") {
            var current = ""
            let chars = Array(block)
            for (index, ch) in chars.enumerated() {
                current.append(ch)
                let next = index + 1 < chars.count ? chars[index + 1] : " "
                // (\u{29} = sluithaakje; als escape zodat de haakjes-telling van validate_project klopt.)
                if ".!?".contains(ch) && (next == " " || next == "\"" || next == "”" || next == "\u{29}") {
                    append(current, to: &result); current = ""
                }
            }
            append(current, to: &result)
        }
        return result
    }
    private static func append(_ raw: String, to list: inout [String]) {
        let sentence = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = words(in: sentence).count
        guard sentence.count >= 25, sentence.count <= 600, wordCount >= 5 else { return }
        list.append(sentence)
    }

    /// De belangrijkste woorden van de pagina (geen stopwoorden of getallen), zwaarste eerst.
    static func keywords(in text: String, limit: Int = 12) -> [String] {
        var counts: [String: Int] = [:]
        for word in words(in: text) where !stopWords.contains(word) && word.count >= 3 && !word.allSatisfy(\.isNumber) {
            counts[word, default: 0] += 1
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(limit).map(\.key)
    }

    /// Zinnen scoren: hoe vaak komen de zwaarste paginawoorden (en eventueel je vraag) erin voor,
    /// genormaliseerd op de lengte, met een kleine bonus voor zinnen vooraan (inleidingen vatten vaak samen).
    static func ranked(_ sentences: [String], question: String? = nil) -> [(index: Int, score: Double)] {
        let all = sentences.joined(separator: " ")
        var frequency: [String: Double] = [:]
        for word in words(in: all) where !stopWords.contains(word) { frequency[word, default: 0] += 1 }
        let maxFrequency = frequency.values.max() ?? 1
        let questionWords = Set((question.map(words(in:)) ?? []).filter { !stopWords.contains($0) })
        return sentences.enumerated().map { index, sentence in
            let sentenceWords = words(in: sentence)
            guard !sentenceWords.isEmpty else { return (index, 0) }
            var score = 0.0
            for word in sentenceWords where !stopWords.contains(word) { score += (frequency[word] ?? 0) / maxFrequency }
            score /= Double(sentenceWords.count).squareRoot()
            if !questionWords.isEmpty {
                let hits = Set(sentenceWords).intersection(questionWords).count
                // Een vraag weegt zwaar: zinnen zonder één vraagwoord doen bijna niet mee.
                score = Double(hits) * 3 + score * (hits == 0 ? 0.1 : 1)
            }
            let position = 1.0 - min(Double(index) / Double(max(sentences.count, 1)), 1.0)
            return (index, score + position * 0.15)
        }
    }

    /// Samenvatting: de `count` beste zinnen in de oorspronkelijke volgorde.
    static func summary(of page: PageContent, count: Int = 5) -> [String] {
        let pool = sentences(in: page.summary + "\n" + page.text)
        guard !pool.isEmpty else { return page.summary.isEmpty ? [] : [page.summary] }
        let best = ranked(pool).sorted { $0.score > $1.score }.prefix(max(1, count)).map(\.index).sorted()
        return dedupe(best.map { pool[$0] })
    }

    /// Kernpunten: korte, beste zinnen (ingekort tot ±160 tekens), elk één punt.
    static func keyPoints(of page: PageContent, count: Int = 5) -> [String] {
        summary(of: page, count: count).map { shorten($0, to: 160) }
    }

    /// Antwoord op een vraag: de zinnen die het best bij de vraag passen. Leeg = niets gevonden.
    static func answer(_ question: String, from page: PageContent, count: Int = 3) -> [String] {
        let pool = sentences(in: page.summary + "\n" + page.text)
        let questionWords = Set(words(in: question).filter { !stopWords.contains($0) })
        guard !pool.isEmpty, !questionWords.isEmpty else { return [] }
        let scored = ranked(pool, question: question).filter { item in
            !Set(words(in: pool[item.index])).intersection(questionWords).isEmpty
        }
        let best = scored.sorted { $0.score > $1.score }.prefix(max(1, count)).map(\.index).sorted()
        return dedupe(best.map { pool[$0] })
    }

    /// Leestijd in minuten (220 woorden per minuut, minstens 1).
    static func readingMinutes(_ page: PageContent) -> Int { max(1, Int((Double(page.wordCount) / 220).rounded(.up))) }

    static func shorten(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        let end = cut.lastIndex(of: " ") ?? cut.endIndex
        return String(cut[..<end]).trimmingCharacters(in: CharacterSet(charactersIn: " ,;:")) + "…"
    }

    private static func dedupe(_ list: [String]) -> [String] {
        var seen = Set<String>()
        return list.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Tekst voor het taalmodel: titel, beschrijving en het begin van de pagina, binnen `limit` tekens.
    static func promptContext(_ page: PageContent, limit: Int = 12_000) -> String {
        var parts = ["Title: \(page.title)"]
        if let url = page.url { parts.append("Address: \(url.absoluteString)") }
        if !page.summary.isEmpty { parts.append("Description: \(page.summary)") }
        let header = parts.joined(separator: "\n")
        let room = max(0, limit - header.count - 20)
        let body = page.text.count > room ? String(page.text.prefix(room)) + " …" : page.text
        return header + "\n\nPage text:\n" + body
    }

    /// Opdracht voor het taalmodel per modus.
    static func instructions(for mode: Mode, sentences: Int) -> String {
        switch mode {
        case .summary:
            return "You summarise web pages and videos for a browser side panel. Write \(sentences) short sentences in the language of the page. Only use facts from the page text. No introduction, no markdown headings."
        case .keyPoints:
            return "You list the key points of a web page or video for a browser side panel. Reply with at most \(sentences) bullet points, each starting with \"• \", in the language of the page. Only use facts from the page text."
        case .question:
            return "You answer questions about the web page the user is reading. Use only the page text. If the page does not contain the answer, say so in one sentence. Answer in the language of the question, in at most \(sentences) sentences."
        }
    }
}
