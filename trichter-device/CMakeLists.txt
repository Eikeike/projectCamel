# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)
set(BOARD_ROOT ${CMAKE_HOME_DIRECTORY})

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(camel)

target_include_directories(app PRIVATE include)
target_sources(app PRIVATE src/main.c src/tm1637.c src/fsm_core.c src/runtime.c src/state_machine.c src/bluetooth.c src/memory.c src/inputs.c src/bluetooth_advertising.c)

