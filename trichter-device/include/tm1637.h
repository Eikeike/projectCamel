/* SPDX-License-Identifier: Apache-2.0 */
#ifndef ZEPHYR_DRIVERS_DISPLAY_TM1637_H_
#define ZEPHYR_DRIVERS_DISPLAY_TM1637_H_

#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/kernel.h>

/* Return codes */
#define TM1637_OK       0
#define TM1637_ERROR    1

/* Commands (optional if you need direct access) */
#define TM1637_CMD_AUTO_ADDR_INCR  0x40
#define TM1637_CMD_SET_START_ADDR  0xC0
#define TM1637_CMD_SET_BRIGHT      0x88
#define TM1637_CMD_DISPLAY_OFF     0x80

#define TM1637_BYTE_EMPTY_SEG      0x00

/**
 * @brief Initialize the TM1637 GPIO pins
 *
 * Configures CLK and DIO pins defined in devicetree.
 *
 * @return TM1637_OK if successful, TM1637_ERROR otherwise
 */
int tm1637_init(void);


void tm1637_display_digits(uint8_t digits[], uint8_t num_digits, uint8_t brightness, uint8_t dot_at);

void tm1637_display_ready(uint8_t brightness);

void tm1637_display_error_message(uint8_t brightness);

void tm1637_display_off();

void tm1637_display_bier(uint8_t brightness);

void tm1637_display_cal(uint8_t brightness);

void clk_high(void);
void clk_low(void);


#endif /* ZEPHYR_DRIVERS_DISPLAY_TM1637_H_ */
