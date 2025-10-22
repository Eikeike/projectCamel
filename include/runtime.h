#ifndef ZEPHYR_RUNTIME_H_
#define ZEPHYR_RUNTIME_H_

#include <zephyr/kernel.h>
#include <stdint.h>

void init_seven_seg();

void endless_loop();

void init_gpio_outputs();

uint8_t init_gpio_inputs();


#endif //ZEPHYR_RUNTIME_H_