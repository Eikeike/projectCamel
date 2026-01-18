Übersicht
*********

Trichter Alexander Holt? Nur Gott kann mich trichtern? Wechselstromgleichtrichter?

Zusammengefasst: Ein unnötig kompliziertes PCB, das misst, wie schnell du trinkst. Nicht irgendwie, nein - aus einem Trichter.
Damit es nicht zu dumm ist, überträgt die Kiste dein Trinkergebnis an einen BLE fähigen Controller (Smartphone)

Unser KAMEL (Konsum-Analyse-Modul zur Ermittlung der Litergeschwindigkeit) läuft schneller als du säufst.

Inhalt
*********************
Das repository umfasst den Code für die Embedded-Software, die auf dem SoC läuft und für die App, die mit diesem SoC kommuniziert.
Facts:

* Kommunikation über BLE
* Embedded Code basierend auf Zephyr RTOS
* Custom SoC basierend auf NRF52832 (siehe trichter-device/README.rst für Details)

Repository-Struktur
**********************

**trichter-device**
	Enthält den gesamten embedded code. Benötigt eine Installation vom Zephyr RTOS und muss auf diesen verlinken. Siehe in trichter-device enthaltene Readme.rst

**bierorgl_app**
	Enthält die gesamte App für das Smartphone (FLutter based, bisher nur android support), mit der das embedded device gesteuert und ausgelesen werden kann.
