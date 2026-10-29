# Bijdragen aan JoeToep

1. Fork de repo en maak een branch vanaf `main`.
2. Houd wijzigingen klein en gericht; schrijf commentaar in het Nederlands met een versielabel (`// V26:`).
3. Werk `CHANGELOG.md` bij (nieuwste versie bovenaan): wat merkte de gebruiker, wat was de oorzaak, wat is de oplossing.
4. Draai vóór je pull request:
   - `node Scripts/test_media_compatibility.cjs` en de andere `Scripts/test_*.cjs`
   - `python3 Scripts/validate_project.py`
   - een build voor macOS én iOS in Xcode (AppKit/UIKit-code altijd achter `#if os(macOS)` / `#if os(iOS)`).
5. Open een pull request met een korte beschrijving en hoe je het getest hebt.

Een nieuwe release = versie ophogen (`project.pbxproj`, `AppConstants.swift`, `Scripts/validate_project.py`), commit "JoeToep VX.Y" en branch `versie/vX.Y`.
