# Bijdragen aan JoeToep

1. Fork de repo en maak een branch vanaf `main`.
2. Houd wijzigingen klein en gericht; schrijf commentaar in het Nederlands met een versielabel (`// V27:`). Nieuwe logica die geen UI nodig heeft: in `JoeToep/Models` met alleen `import Foundation`, met tests in `JoeToepTests`.
3. Werk `CHANGELOG.md` bij (nieuwste versie bovenaan): wat merkte de gebruiker, wat was de oorzaak, wat is de oplossing.
4. Draai vóór je pull request:
   - `npm ci --ignore-scripts && npm test` (alle JS-regressies)
   - `python3 Scripts/validate_project.py`
   - `Scripts/linux_swift_tests.sh` (pure Swift-logica + unit tests; werkt ook zonder Mac, via Docker)
   - een build voor macOS én iOS in Xcode (AppKit/UIKit-code altijd achter `#if os(macOS)` / `#if os(iOS)`).
5. Open een pull request met een korte beschrijving en hoe je het getest hebt.

Een nieuwe release = versie ophogen (`project.pbxproj`, `AppConstants.swift`, `EXPECTED_VERSION`/`EXPECTED_BUILD` in `Scripts/validate_project.py`), een nieuw bovenste kopje `# X.Y.Z (build)` in `CHANGELOG.md`, commit "JoeToep VX.Y" en branch `versie/vX.Y`.
