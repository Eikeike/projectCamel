#include <hal/nrf_gpio.h>
#include "zephyr/drivers/gpio.h"
#include <hal/nrf_timer.h>
#include "zephyr/kernel.h"
#include <helpers/nrfx_gppi.h>
#include "runtime.h"
#include "fsm_core.h"
#include "devicetree_devices.h"
#include "zephyr/kernel.h"
#include "zephyr/sys/clock.h"

#define LONG_CLICK_TIME_MS          4000
#define DOUBLE_CLICK_TIMEOUT_MS     350
#define READY_DEBOUNCE_PERIOD_MS    K_MSEC(5)


struct g_ready_button_t {
	uint8_t button_level_stable;
	uint8_t long_click_fired;
	uint64_t click_time;
    uint8_t double_click_pending;
} g_ready_button;

static void debounce_work_handler(struct k_work *work);
static void long_click_work_handler(struct k_work *work);
static void double_click_debounce_handler(struct k_work *work);
K_WORK_DELAYABLE_DEFINE(debounce_work, debounce_work_handler);
K_WORK_DELAYABLE_DEFINE(long_click_work, long_click_work_handler);
K_WORK_DELAYABLE_DEFINE(double_click_debounce_work, double_click_debounce_handler);

static nrfx_gppi_handle_t ppi_channel;
static uint8_t gpiote_in_channel;

/*
static void ready_button_pressed_handler()
{
	printk("Button pressed at %lldms\n", k_uptime_get());
	if ((k_uptime_get() - g_ready_button.last_timestamp_ready_button) <= DEBOUNCE_CLICK_MS) return;

	g_ready_button.num_clicks++;
	if (g_ready_button.num_clicks == 1)
	{
		printk("Go to READY\n");
    	fsm_transition_deferred(STATE_READY);
		if (!k_work_is_pending(&double_click_timer_work))
		{
			k_work_submit(&double_click_timer_work);
		}
	} else if (g_ready_button.num_clicks == 2)
	{
		printk("Button pressed again. Start advertising\n");
    	g_advertise_in_ready = true;
		g_ready_button.num_clicks = 0;
		k_timer_stop(&click_timer);
	}
	g_ready_button.last_timestamp_ready_button = k_uptime_get();
}
*/
void debounce_work_handler(struct k_work *work)
{
    uint8_t level = gpio_pin_get_dt(&button_ready);
    if (level == g_ready_button.button_level_stable) return;

    g_ready_button.button_level_stable = level;

    if (1 == level) {
        //Rising edge
        g_ready_button.click_time = k_uptime_get();
        k_work_schedule(&long_click_work, K_MSEC(LONG_CLICK_TIME_MS));
        g_ready_button.long_click_fired = false;

    } else {
        //Falling edge
        if (g_ready_button.long_click_fired) return;

        k_work_cancel_delayable(&long_click_work);
        if (!g_ready_button.double_click_pending)
        {
            g_ready_button.double_click_pending = true;
            on_single_click();
            k_work_schedule(&double_click_debounce_work, K_MSEC(DOUBLE_CLICK_TIMEOUT_MS));
        } else {
            g_ready_button.double_click_pending = false;
            k_work_cancel_delayable(&double_click_debounce_work);
            on_double_click();
        }
    }
}


static void long_click_work_handler(struct k_work *work)
{
    if (1 == g_ready_button.button_level_stable) {
        g_ready_button.long_click_fired = true;
        g_ready_button.double_click_pending = false;
        on_long_click();
    }
}


static void double_click_debounce_handler(struct k_work *work)
{
    g_ready_button.double_click_pending = false;
}

/*
static void ready_button_cooldown_expired(struct k_work *work)
{
    ARG_UNUSED(work);
    ready_button_pressed_handler();
}
*/

uint8_t setup_isr_for_gpio_in(const struct gpio_dt_spec *input, struct gpio_callback *cb , gpio_callback_handler_t handler, unsigned long flags)
{
	nrfx_err_t err;

	err = gpio_pin_configure_dt(	input, GPIO_INPUT);
	if (err) {
		printk("ERROR: GPIO input could not be set");
		return err;
	}
	err = gpio_pin_interrupt_configure(input->port, input->pin, flags);
	if (err) {
		printk("ERROR: GPIO interrupt flags could not be set");
		return err;
	}
	gpio_init_callback(cb, handler, BIT(input->pin));
	
	err = gpio_add_callback(input->port, cb);
    if (err) {
        printk("ERROR: Add interrupt failed\n");
        gpio_pin_interrupt_configure(input->port, input->pin, GPIO_INT_DISABLE);
        return err;
    }
	return 0;
}


static void setup_ppi_for_sensor(const struct gpio_dt_spec *sensor)
{
    nrfx_err_t err;
    static nrfx_gpiote_t gpiote = NRFX_GPIOTE_INSTANCE(NRF_GPIOTE);

	if (false == nrfx_gpiote_init_check(&gpiote))
	{
		err = nrfx_gpiote_init(&gpiote, 0);
		if (err != 0) {
			printk("GPIOTE init failed: %08x\n", err);
			return;
		}
	}
    // Allocate GPIOTE channel
    err = nrfx_gpiote_channel_alloc(&gpiote, &gpiote_in_channel);
    if (err != 0) {
        printk("GPIOTE channel alloc failed: %08x\n", err);
        return;
    }

    // Configure input pin
    nrfx_gpiote_trigger_config_t trigger_config = {
        .trigger = NRFX_GPIOTE_TRIGGER_LOTOHI,
        .p_in_channel = &gpiote_in_channel,
    };
    
    nrfx_gpiote_input_pin_config_t input_config = {
        .p_pull_config = NULL,  // Use existing pull config
        .p_trigger_config = &trigger_config,
        .p_handler_config = NULL 
    };

    err = nrfx_gpiote_input_configure(&gpiote, sensor->pin, &input_config);
    if (err != 0) {
        printk("GPIOTE input config failed: %08x\n", err);
        return;
    }
	nrfx_gpiote_trigger_enable(&gpiote, sensor->pin, false);
	
    uint32_t eep = nrf_gpiote_event_address_get(NRF_GPIOTE, nrfx_gpiote_in_event_get(&gpiote, sensor->pin));
    uint32_t tep = nrf_timer_task_address_get(NRF_TIMER2, NRF_TIMER_TASK_CAPTURE1);

	printk("EVENT addr IN : %08x; OUT : %08x\n", eep, tep);

    err = nrfx_gppi_conn_alloc(eep, tep, &ppi_channel);
    if (err != 0) {
        printk("GPPI conn alloc failed: 0x%08x\n", err);
        return;
    }

    // Enable the connection (replaces nrfx_gppi_channels_enable(BIT(channel)))
    nrfx_gppi_conn_enable(ppi_channel);
}


void ready_button_isr(const struct device *dev, struct gpio_callback *cb,
		    uint32_t pins)
{
	printk("Button pressed at %d, level %d...\n", k_cycle_get_32(), gpio_pin_get_dt(&button_ready));
    k_work_reschedule(&debounce_work, READY_DEBOUNCE_PERIOD_MS);
}



uint8_t init_gpio_inputs()
{
    int ret = 0;
    ret = setup_isr_for_gpio_in(&button_ready, &button_cb_data_1, ready_button_isr, GPIO_INT_EDGE_BOTH);
	ret |= setup_isr_for_gpio_in(&button_test_sensor, &button_cb_data_2, sensor_triggered_isr, GPIO_INT_EDGE_RISING); //sensor triggered ISR in runtime.h
	setup_ppi_for_sensor(&button_test_sensor);

	if (ret != 0)
	{
		printk("Error %d: failed to configure GPIO inputs\n", ret);
	} else {
		printk("Set up All GPIO Inputs successfully");
	}
	return ret;
}


void init_gpio_outputs()
{
    int ret = 0;
	if (led.port && !gpio_is_ready_dt(&led))
    {
		printk("Error %d: LED device %s is not ready; ignoring it\n", ret, led.port->name);
		led.port = NULL;
	}
	if (led.port)
    {
		ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT);
		if (ret != 0)
        {
			printk("Error %d: failed to configure LED device %s pin %d\n", ret, led.port->name, led.pin);
			led.port = NULL;
		} else {
			printk("Set up LED at %s pin %d\n", led.port->name, led.pin);
		}
	}
}

