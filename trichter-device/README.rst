Allgemein
*********
Dieses sub-projekt enthält den embedded Code für den Sensor, der die Trinkgeschwindigkeit misst und per BLE an ein Smartphone übertragen kann.

Hardware
*********

**SoC**: E73-2G4M04S1B

**MCU**: NRF52832-QFAA

**Board**: Custom PCB, designed für:

* Anzeige eines vierstelligen 7-Seg-Displays
* UART zu USB-C conversion
* Sensor-Eingang
* Spannungsversorgung über Batterie und optional USB-C
* Input/Output Peripherie (Buttons, LEDs)
* SWD/JTAG Schnittstelle

Sub-Projekt-Layout
*******************
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
**Die Applikation (also der root folder) muss in zephyrproject/applications gespeichert werden!**

Wenn das repo und die zephyr-Installation an unterschiedlichen Orten gespeichert sind, vorher die Variable :code:`ZEPHYR_BASE` auf den absoluten Pfad von :code:`<...>/zephyrproject` setzen, wie beschrieben `hier <https://docs.zephyrproject.org/latest/develop/env_vars.html>`_


Nützliche Commands für den zephyr-code:
***************************************
Bootloader
-----------

Um den bootloader zu builden: In den ordner: **zephyrproject/bootloader/mcuboot/boot/zephyr**

::

	cmake -GNinja -DBOARD=pilsPlatine -DBOARD_ROOT=<Absolute_path_to>\\applications\\projectCamel\\trichter-device -DAPPL_CONF_DIR=<Absolute_path_to>\\zephyrproject\\applications\\projectCamel\\trichter-device\\conf\\mcuboot\\  -S . -B .\\build -DCONF_FILE=".\\prj.conf"

Und danach 

::

	ninja -Cbuild

Das erzeugte \*.elf oder \*.hex file in ./build/zephyr kann dann auf die MCU geflashed werden.

Der Bootloader nutzt Serial Recovery - sobald er geflashed ist, kann über den USB-C port neue Software geflashed werden.
Dafür muss zunächst die Applikation gebaut werden:

Applikation
------------
In den Ordner **applications/projectCamel/trichter-device**:

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

