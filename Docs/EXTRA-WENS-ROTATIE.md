
## EXTRA WENS VAN TIJN (13-10, ná de start van 23.1) — meenemen in 23.1
**iPhone: automatisch draaien bij fullscreen** — nieuwe instelling (iPhone, STANDAARD AAN), uit te zetten:
- Opent een video fullscreen → telefoon draait automatisch naar landscape, óók als rotatievergrendeling aan staat (app forceert de oriëntatie via UIWindowScene.requestGeometryUpdate / supportedInterfaceOrientations).
- Sluit de video fullscreen → automatisch terug naar portrait.
- Beide overgangen zeer snel en vloeiend. Testen op eiFoon (met rotatievergrendeling aan én uit).
