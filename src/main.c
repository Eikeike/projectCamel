/*
 * Copyright (c) 2016 Open-RnD Sp. z o.o.
 * Copyright (c) 2020 Nordic Semiconductor ASA
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * NOTE: If you are looking into an implementation of button events with
 * debouncing, check out `input` subsystem and `samples/subsys/input/input_dump`
 * example instead.
 */

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/sys/util.h>
#include <zephyr/sys/printk.h>
#include <zephyr/debug/object_tracing.h>
#include <inttypes.h>
#include "tm1637.h"
#include "runtime.h"
#include "devicetree_devices.h"
#include "fsm_core.h"
#include "bluetooth.h"

void print_thread_priorities(void)
{
    struct k_thread *thread_list = NULL;
    struct k_thread *thread;
    
    /* Get the list of all threads */
    thread_list = SYS_THREAD_MONITOR_HEAD;
    
    printk("Active Threads and Priorities:\n");
    printk("------------------------------\n");
    
    while ((thread = thread_list) != NULL) {
        printk("Thread %p, name: %s, priority: %d\n",
               thread,
               k_thread_name_get(thread),
               k_thread_priority_get(thread));
               
        thread_list = SYS_THREAD_MONITOR_NEXT(thread_list);
    }
    printk("------------------------------\n");
}

int main(void)
{
	init_seven_seg();
	init_gpio_inputs();
	init_gpio_outputs();
	init_ble();

	ble_start_adv();

	fsm_start();

    uint8_t digits[4] = {1, 2, 3, 4};

	if (led.port) {
		unsigned int key = 0;
		int locked = 0;
		while (1) {
			/* If we have an LED, match its state to the button's. */
			int val = gpio_pin_get_dt(&button_ready);
			if (val > 0)
			{	
				gpio_pin_set_dt(&led, val);
			}
			print_thread_priorities();
			k_msleep(6000);	
		}
	}
	return 0;
}
