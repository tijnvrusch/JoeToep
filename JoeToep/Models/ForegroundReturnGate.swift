/// Native fullscreen and Control Center can reactivate the app without a trip
/// through the background. Such activation must not dismiss a new PiP session.
// Deze struct onthoudt of de app zojuist "uit de achtergrond" is teruggekomen,
// zodat andere code (bijv. Picture-in-Picture logica) weet dat een "activation"
// (het weer actief worden van de app) hier vandaan komt, en niet per ongeluk
// een net gestart PiP-schermpje sluit.
struct ForegroundReturnGate {
    // "private" betekent: deze eigenschap ("property") is alleen binnen deze
    // struct zichtbaar/aanpasbaar, niet van buitenaf. Standaardwaarde is false.
    private var returningFromBackground = false
    // "mutating" is nodig omdat een struct standaard onveranderlijk ("value type")
    // is; een functie die een eigenschap van de struct wil wijzigen moet
    // expliciet als "mutating" gemarkeerd worden.
    // Wordt aangeroepen wanneer het systeem meldt dat de app weer naar de
    // voorgrond komt. Zet de vlag op true.
    mutating func willEnterForeground() { returningFromBackground = true }
    // Deze functie leest de huidige status uit, zet hem meteen weer terug op
    // false (dus "verbruikt" hem, vandaar de naam "consume"), en geeft het
    // oorspronkelijke resultaat terug. Zo wordt de vlag maar één keer gebruikt.
    mutating func consumeActivation() -> Bool {
        let result = returningFromBackground
        returningFromBackground = false
        return result
    }
}
