# Diagnostiek

Bij PiP-fouten: noteer apparaat, OS, inline/fullscreen, gebruikte appwissel, of het beeld verdwijnt of alleen pauzeert, en of een andere app audio startte. Kopieer daarna Settings → Copy PiP diagnostics.

Diagnostiek bevat presentatie-/afspeelstatus en recente lifecycle-events, zonder video-URL of accountgegevens. Herlaad pas na het vastleggen; herladen beëindigt de bestaande videopresentatie.

Audioherstel gebruikt Apple's shouldResume-signaal. Een expliciete remote pause annuleert herstel. Als een andere app de audio-session niet vrijgeeft, kan JoeToep dat niet betrouwbaar overrulen.

Bron voor onderbrekingsafhandeling: https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
