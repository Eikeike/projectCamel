#ifndef ZEPHYR_RUNTIME_H_
#define ZEPHYR_RUNTIME_H_

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>
#include <stdint.h>

void init_seven_seg();

void endless_loop();

void init_gpio_outputs();

uint8_t init_gpio_inputs();

void on_single_click();
void on_double_click();
void on_long_click();

void sensor_triggered_isr(const struct device *dev, struct gpio_callback *cb, unsigned int pins);
void ble_delete_active_connection();


#endif //ZEPHYR_RUNTIME_H_