#ifndef ZEPHYR_DEVICETREE_DEVICES_H_
#define ZEPHYR_DEVICETREE_DEVICES_H_

#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <nrfx_gpiote.h>
#include <helpers/nrfx_gppi.h>
#include <hal/nrf_gpiote.h>

#define BUTTON_READY	    DT_ALIAS(buttonrdy)
#define BUTTON_PAIRING      DT_ALIAS(buttonpairing)
#define BUTTON_TEST_SENSOR  DT_ALIAS(buttontest)

#ifndef CONFIG_BUTTONLESS
    #if !DT_NODE_HAS_STATUS_OKAY(BUTTON_READY)
    #error "Unsupported board: buttonRdy devicetree alias is not defined"
    #endif
    #if !DT_NODE_HAS_STATUS_OKAY(BUTTON_PAIRING)
    #error "Unsupported board: buttonPair devicetree alias is not defined"
    #endif
#endif
#if !DT_NODE_HAS_STATUS_OKAY(BUTTON_TEST_SENSOR)
#error "Unsupported board: buttonTest devicetree alias is not defined"
#endif

#define GPIOTE_INST	NRF_DT_GPIOTE_INST(BUTTON_TEST_SENSOR, gpios)
#define GPIOTE_NODE	DT_NODELABEL(_CONCAT(gpiote, GPIOTE_INST))

#ifndef CONFIG_BUTTONLESS
static const struct gpio_dt_spec button_ready = GPIO_DT_SPEC_GET_OR(BUTTON_READY, gpios, {0});
static const struct gpio_dt_spec button_pairing = GPIO_DT_SPEC_GET_OR(BUTTON_PAIRING, gpios, {0});
#endif
static const struct gpio_dt_spec button_test_sensor = GPIO_DT_SPEC_GET_OR(BUTTON_TEST_SENSOR, gpios, {0});

static struct gpio_callback button_cb_data_1;
static struct gpio_callback button_cb_data_2;

/*
 * The led0 devicetree alias is optional. If present, we'll use it
 * to turn on the LED whenever the button is pressed.
 */
static struct gpio_dt_spec led = GPIO_DT_SPEC_GET_OR(DT_ALIAS(led0), gpios, {0});

static const struct device *hw_timer_1 = DEVICE_DT_GET(DT_ALIAS(hw_timer));
static bool g_timer_initialized = false;



#endif //ZEPHYR_DEVICETREE_DEVICES_H_ 