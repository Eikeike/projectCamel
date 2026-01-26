#ifndef ZEPHYR_RUNTIME_H_
#define ZEPHYR_RUNTIME_H_

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>
#include <stdint.h>
#include "bluetooth.h"

#define TIMER_FREQUENCY_HZ				125000
#define TIMER_TICK_DURATION_US			8
#define MEARUEMENT_END_TIMEOUT_MS		1000 //TODO Adapt to real values with: max_drinking_time / (TICKS_PER_LTR/2) = max_time_between ticks
#define TIMER_TIMEOUT_TIMESTAMP_DIFF	TIMER_FREQUENCY_HZ / 1000 * MEARUEMENT_END_TIMEOUT_MS

void init_seven_seg();

void endless_loop();

void init_gpio_outputs();

uint8_t init_gpio_inputs();

void input_request_state_ready();
void input_request_pairing_mode();
void input_request_state_calibrating();
void ble_remote_state_dispatch(RemoteState state);

void sensor_triggered_isr(const struct device *dev, struct gpio_callback *cb, unsigned int pins);
void ble_delete_active_connection();

int get_timer_tick_duration();
void on_trichter_startup();

typedef void (*CalibrationAttempt)(bool);
void calib_attempt_register_notifier(CalibrationAttempt notifier);


#endif //ZEPHYR_RUNTIME_H_