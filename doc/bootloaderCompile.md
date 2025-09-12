# Steps to reproduce:

1. Clone ZephyrProject
2. Place this application within zephyrproject folder
3. activate venv
4. run zephyr\zephyr-env.cmd
5. cd bootloader\mcuboot\boot
6. mkdir build
7. set ZEPHYR_BASE=..\..\..\..\..\zephyr (ADAPT BASED ON YOUR ZEPHYR INSTALL DIR)
7. cmake -GNinja -DBOARD=pilsPlatine -DBOARD_ROOT=D:\devel\zephyrproject\applications\projectCamel -DAPPL_CONF_DIR=D:\\devel\\zephyrproject\\applications\\projectCamel\\conf\\mcuboot\  -S . -B .\build
 -DCONF_FILE=".\\prj.conf 
8. build\ninja