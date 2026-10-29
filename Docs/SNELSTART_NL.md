# JoeToep V10 installeren en controleren

1. Open `JoeToep.xcodeproj`, scheme JoeToep, en kies Mac/iPhone/iPad.
2. Selecteer je Signing Team. Behoud `nl.tijn.JoeToep` om de bestaande app bij te werken.
3. Bouw met Cmd R. Het apparaat moet ontgrendeld zijn, de Mac vertrouwen en Developer Mode toestaan.
4. Controleer op iOS bij Instellingen → Algemeen → Beeld in beeld dat automatisch starten aanstaat.
5. Start een gewone video. Automatisch fullscreen en PiP staan standaard aan. Houd de PiP-knop langer dan 0,3 seconde ingedrukt voor een presentatiereset.

Deze werkversie is nog niet als definitief stabiel goedgekeurd. Vooral automatische PiP vanuit inline video blijft een open fout. Force-quitten is geen gewone appwissel en beëindigt doorgaans de app. Lees het testverslag voordat je de versie als dagelijkse vervanger gebruikt.
