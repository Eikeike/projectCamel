/* SPDX-License-Identifier: Apache-2.0 */
/* tm1637.c - minimal TM1637 bitbang for Zephyr (nRF52832) */

#include "tm1637.h"
#include <zephyr/sys/printk.h>
#include <stdarg.h>

/* --- Devicetree handle --- */
#define TM1637_NODE DT_NODELABEL(tm1637)
#if !DT_NODE_HAS_STATUS_OKAY(TM1637_NODE)
#error "Unsupported board: TM1637 devicetree node not defined"
#endif

static const struct gpio_dt_spec clk =
    GPIO_DT_SPEC_GET(TM1637_NODE, clk_gpios);

static const struct gpio_dt_spec dio =
    GPIO_DT_SPEC_GET(TM1637_NODE, dio_gpios);

/* Timing: microseconds pause */
#define T_US 40

/* Segment map (0–9) */
static const uint8_t digit_to_segment[] = {
    0x3f, /* 0 */
    0x06, /* 1 */
    0x5b, /* 2 */
    0x4f, /* 3 */
    0x66, /* 4 */
    0x6d, /* 5 */
    0x7d, /* 6 */
    0x07, /* 7 */
    0x7f, /* 8 */
    0x6f, /* 9 */
};

/* --- GPIO helpers --- */
static void dio_output(void) { gpio_pin_configure_dt(&dio, GPIO_OUTPUT); }
static void dio_input(void)  { gpio_pin_configure_dt(&dio, GPIO_INPUT); }
void clk_high(void)   { gpio_pin_set_dt(&clk, 1); }
void clk_low(void)    { gpio_pin_set_dt(&clk, 0); }
static void dio_high(void)   { gpio_pin_set_dt(&dio, 1); }
static void dio_low(void)    { gpio_pin_set_dt(&dio, 0); }
static int  dio_read(void)   { return gpio_pin_get_dt(&dio); }

/* --- Protocol primitives --- */
static void tm1637_start(void)
{
    dio_output();
    dio_high();
    clk_high();
    k_busy_wait(T_US);
    dio_low();
    k_busy_wait(T_US);
}

static void tm1637_stop(void)
{
    dio_output();
    clk_low();
    k_busy_wait(T_US);
    dio_low();
    k_busy_wait(T_US);
    clk_high();
    k_busy_wait(T_US);
    dio_high();
    k_busy_wait(T_US);
}

static bool tm1637_write_byte(uint8_t b)
{
    for (int i = 0; i < 8; i++) {
        clk_low();
        if (b & 0x01) dio_high(); else dio_low();
        k_busy_wait(T_US);
        clk_high();
        k_busy_wait(T_US);
        b >>= 1;
    }

    /* ACK cycle */
    clk_low();
    dio_input();
    k_busy_wait(T_US);
    clk_high();
    k_busy_wait(T_US);
    int ack = dio_read();
    clk_low();
    dio_output();
    return (ack == 0);
}

/* --- Public API --- */
int tm1637_init(void)
{
    if (!device_is_ready(clk.port) || !device_is_ready(dio.port)) {
        printk("Error: GPIO devices not ready\n");
        return TM1637_ERROR;
    }
    if (gpio_pin_configure_dt(&clk, GPIO_OUTPUT) != 0 ||
        gpio_pin_configure_dt(&dio, GPIO_OUTPUT) != 0) {
        printk("Error: failed to configure CLK/DIO pins\n");
        return TM1637_ERROR;
    }
    clk_high();
    dio_high();
    k_busy_wait(T_US);
    printk("Set up CLK at %s pin %d\n", clk.port->name, clk.pin);
    printk("Set up DIO at %s pin %d\n", dio.port->name, dio.pin);

    tm1637_display_off();
    return TM1637_OK;
}

void tm1637_display_off()
{
     /* command1: auto increment */
    tm1637_start();
    tm1637_write_byte(TM1637_CMD_AUTO_ADDR_INCR);
    tm1637_stop();

    /* command2: necessary, but transmit no data in init */
    tm1637_start();
    tm1637_stop();

    /* command3: brightness */
    tm1637_start();
    tm1637_write_byte(TM1637_CMD_DISPLAY_OFF);
    tm1637_stop();
}


void tm1637_display_digits(uint8_t digits[], uint8_t num_digits, uint8_t brightness, uint8_t dot_at)
{
    if (brightness > 7)
    {
        brightness = 7;
    }
    if (num_digits > 4)
    {
        num_digits = 4;
    }
    /* command1: auto increment */
    tm1637_start();
    tm1637_write_byte(TM1637_CMD_AUTO_ADDR_INCR);
    tm1637_stop();

    /* command2: set starting address (0xC0) */
    tm1637_start();
    tm1637_write_byte(TM1637_CMD_SET_START_ADDR);
    for (int i = 0; i < 4; i++) {
        uint8_t seg = digit_to_segment[digits[i] % 10];
        if (i == dot_at)
        {
            seg |= 0b10000000;
        }
        if (i >= num_digits)
        {
            seg = 0;
        }
        tm1637_write_byte(seg);
    }
    tm1637_stop();

    /* command3: brightness */
    tm1637_start();
    tm1637_write_byte(TM1637_CMD_SET_BRIGHT | (brightness & 0x07));
    tm1637_stop();
}


static void tm1637_display_letters(uint8_t *letters, uint8_t brightness)
{
    if (brightness >= 7)
    {
        brightness = 7;
    }

    /* command1: auto increment */
    tm1637_start();
    tm1637_write_byte(TM1637_CMD_AUTO_ADDR_INCR);
    tm1637_stop();

    /* command2: set starting address (0xC0) */
    tm1637_start();
    tm1637_write_byte(TM1637_CMD_SET_START_ADDR);
    for (uint8_t idx = 0; idx < 4; idx++)
    {
        tm1637_write_byte(letters[idx]);
    }
    tm1637_write_byte(TM1637_BYTE_EMPTY_SEG);
    tm1637_stop();

    /* command3: brightness */
    tm1637_start();
    tm1637_write_byte(TM1637_CMD_SET_BRIGHT | (brightness & 0x07));
    tm1637_stop();
} 


void tm1637_display_ready(uint8_t brightness)
{

    uint8_t letter_r = 0b00110001;
    uint8_t letter_d = 0b01011110;
    uint8_t letter_y = 0b01101110;
    uint8_t letters[] = {
        letter_r,
        letter_d,
        letter_y
    };

   tm1637_display_letters(letters, brightness);
}


void tm1637_display_error_message(uint8_t brightness)
{
    uint8_t letter_E = 0b01111001;
    uint8_t letter_r = 0b00110001;

    uint8_t letters[] = {
        letter_E,
        letter_r,
        letter_r
    };
    tm1637_display_letters(letters, brightness);
}


void tm1637_display_bier(uint8_t brightness)
{
    if (brightness >= 7)
    {
        brightness = 7;
    }
    uint8_t letter_b = 0b01111100;
    uint8_t letter_I = 0b00000110;
    uint8_t letter_E = 0b01111001;
    uint8_t letter_r = 0b00110001;

    uint8_t letters[] = {
        letter_b,
        letter_I,
        letter_E,
        letter_r
    };
    tm1637_display_letters(letters, brightness);
}


void tm1637_display_cal(uint8_t brightness)
{
    if (brightness >= 7)
    {
        brightness = 7;
    }
    uint8_t letter_C = 0b00111001;
    uint8_t letter_A = 0b01110111;
    uint8_t letter_L = 0b10111000;

    uint8_t letters[] = {
        letter_C,
        letter_A,
        letter_L
    };
    tm1637_display_letters(letters, brightness);
}