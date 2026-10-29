# V10 vrijgavecriteria

Status: **NIET vrijgegeven als definitieve stabiele versie**. Het tussenpakket bevat broncode, tests en een eerlijk testverslag.

Afgerond: versie/defaults, tabs/herstel, bediening, iconenassets, Release-build Mac en iOS/iPadOS, 36 native tests op Mac en simulator, 115 JavaScript-tests, 25 filtercontroles, project- en syntaxvalidatie.

Open voordat definitieve oplevering mogelijk is:

- Automatische inline-PiP op fysieke iPhone repareren en zichtbaar beeld na minimaal 30 seconden bevestigen, ook op mobiele YouTube-pagina's en bij herhaalde wissels.
- Mac originele YouTube-fullscreen op meer video’s en herhaalde navigaties verifiëren; één live video is bevestigd.
- Terugkeer zonder fullscreen-sprong en lock/unlock met ononderbroken audio fysiek testen. Lang indrukken voor PiP-reset is op iPhone geslaagd.
- Video-AirPlay naar een echte ontvanger bevestigen, niet alleen aanwezigheid in de kiezer.
- iPad-uitvoering herstellen of handmatige tests uitvoeren; XCTest-bootstrap crasht met huidige Xcode/OS-combinatie.
- Trackpad/seekbalk, iconen, netwerkovergangen en lange afspeel-/energiemetingen afronden. Enhanced toetsenbediening is geslaagd.

Zie TEST_PLAN.md voor de scenariomatrix. Geslaagde simulaties tellen niet als bewijs van native PiP. De PiP-faaltest blijft aanwezig en wordt niet overgeslagen om een groen resultaat te verkrijgen.
