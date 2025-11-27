Übersicht
*********

Trichter Alexander Holt? Nur Gott kann mich trichtern? Wechselstromgleichtrichter?

Zusammengefasst: Ein unnötig kompliziertes PCB, das misst, wie schnell du trinkst. Nicht irgendwie, nein - aus einem Trichter.
Damit es nicht zu dumm ist, überträgt die Kiste dein Trinkergebnis an einen BLE fähigen Controller (Smartphone)

Anforderungen
*********************
Das repository umfasst den Code für die Embedded-Software, die auf dem SoC läuft.
**SoC**: E73-2G4M04S1B
**MCU**: NRF52832-QFAA
**Board**: Custom PCB, designed für:
* Anzeige eines vierstelligen 7-Seg-Displays
* UART zu USB-C conversion
* Sensor-Eingang
* Spannungsversorgung über Batterie und optional USB-C
* Input/Output Peripherie (Buttons, LEDs)
*  SWD/JTAG Schnittstelle

Repository-Struktur
**********************

boards
	Devicetree layout für custom PCB basierend auf E73 SoC

conf
	Konfigurationsdateien, getrennt nach Bootloader und Applikation

doc
	Dokumentation.

src
	Source files der Applikation, nicht des bootloaders!

Code-Struktur
*****************

Das repository enthält primär den **Code für die Applikation**.

Auf dem Board ist der MCUBoot Bootloader installiert. Die Konfiguration dafür findet sich in conf/mcuboot. Für den Bootloader wurde das gleiche devicetree layout genutzt wie für die Applikation.
Der Bootloader ist enabled, Serial Recovery zu nutzen und nach einem MCU reset für einige Sekunden zu warten, bis aus dem bootloader in die applikation gesprungen wird.
Das ermöglicht ein einfaches flashen neuer builds per USB/MCUmgr.

Requirements
*************

Das Projekt muss heruntergeladen werden und setzt eine Zephyr-RTOS Installation voraus.
Diese muss wie in `diesem Tutorial <https://docs.zephyrproject.org/latest/develop/getting_started/index.html>`_ installiert werden.
**Die Applikation muss in zephyrproject/applications gespeichert werden!**


Nützliche Commands für den zephyr-code:
***************************************
Bootloader
-----------

Um den bootloader zu builden: In den ordner: **zephyrproject/bootloader/mcuboot/boot/zephyr**

::

	cmake -GNinja -DBOARD=pilsPlatine -DBOARD_ROOT=<Absolute_path_to>\\applications\\projectCamel -DAPPL_CONF_DIR=<Absolute_path_to>\\zephyrproject\\applications\\projectCamel\\conf\\mcuboot\\  -S . -B .\\build -DCONF_FILE=".\\prj.conf"

Das erzeugte \*.elf oder \*.hex file in ./build/zephyr kann dann auf die MCU geflashed werden.
TODO: Bootloader update über serial Recovery

Der Bootloader nutzt Serial Recovery - sobald er geflashed ist, kann über den USB-C port neue Software geflashed werden.
Dafür muss zunächst die Applikation gebaut werden:

Applikation
------------
In den Ordner **applications/projectCamel**:

::

	west build -b pilsPlatine .

Dann kann die Applikation hochgeladen werden, indem `dieses Turorial befolgt wird <https://docs.mcuboot.com/serial_recovery.html>`_

Der korrekte command zum flashen ist:

::

	mcumgr image upload .\build\zephyr\zephyr.signed.bin -c serial_1

Serial port
------------
Am leichtesten:

1. In den Ordner zephyrproject eine CMD öffnen

2. .\\.venv\\Scripts\\activate

3. python -m serial.tools.miniterm COM6 115200

