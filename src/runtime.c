
#include <stdint.h>
#include <hal/nrf_gpio.h>
#include <hal/nrf_gpiote.h>
#include <hal/nrf_timer.h>
#include <zephyr/drivers/counter.h>
#include <nrfx_gpiote.h>
#include <helpers/nrfx_gppi.h>
#include "runtime.h"
#include "tm1637.h"
#include "devicetree_devices.h"
#include "fsm_core.h"
#include "bluetooth.h"

#define TICKS_PER_LTR 300
static volatile uint32_t g_timestamps[TICKS_PER_LTR];
static volatile uint16_t g_timestamp_idx_to_write = 0;

#define TIMER_VALUE_MAX 			0xFFFFFFFF //32bit of 1b

#define TIMER_FREQUENCY_HZ				125000
#define MEARUEMENT_END_TIMEOUT_MS		1000 //TODO Adapt to real values with: max_drinking_time / (TICKS_PER_LTR/2) = max_time_between ticks
#define TIMER_TIMEOUT_TIMESTAMP_DIFF	TIMER_FREQUENCY_HZ / 1000 * MEARUEMENT_END_TIMEOUT_MS

static uint8_t ppi_channel;
static uint8_t gpiote_in_channel;
static uint8_t gpiote_in_channel_ready;
static volatile uint32_t g_captured_timestamp = 0;

uint8_t is_running = false;

/*forward declare*/
uint32_t timer1_get_value();

static void sensor_triggered_isr(nrfx_gpiote_pin_t pin, nrfx_gpiote_trigger_t trigger, void *context)
{
	if (!is_running)
	{
		timer_reset();
		nrf_timer_task_trigger(NRF_TIMER2, NRF_TIMER_TASK_START); //starts timer in free running mode
		fsm_transition_deferred(STATE_RUNNING);
		is_running = true;
	}
	g_timestamps[g_timestamp_idx_to_write] = nrf_timer_cc_get(NRF_TIMER2, 1); //Read value on channel 1
	g_timestamp_idx_to_write++;
    printk("Sensor trigger detected");
}

static void setup_ppi_for_sensor(const struct gpio_dt_spec *sensor)
{
    nrfx_err_t err;
    const nrfx_gpiote_t gpiote = NRFX_GPIOTE_INSTANCE(GPIOTE_INST);

	if (0 == nrfx_gpiote_init_check(&gpiote))
	{
		err = nrfx_gpiote_init(&gpiote, 0);
		if (err != NRFX_SUCCESS) {
			printk("GPIOTE init failed: %08x\n", err);
			return;
		}
	}
    
    // Allocate GPIOTE channel
    err = nrfx_gpiote_channel_alloc(&gpiote, &gpiote_in_channel);
    if (err != NRFX_SUCCESS) {
        printk("GPIOTE channel alloc failed: %08x\n", err);
        return;
    }

    // Configure input pin
    nrfx_gpiote_trigger_config_t trigger_config = {
        .trigger = NRFX_GPIOTE_TRIGGER_HITOLO,
        .p_in_channel = &gpiote_in_channel,
    };
    
	static const nrfx_gpiote_handler_config_t handler_config = {
		.handler = sensor_triggered_isr,
	};

    nrfx_gpiote_input_pin_config_t input_config = {
        .p_pull_config = NULL,  // Use existing pull config
        .p_trigger_config = &trigger_config,
        .p_handler_config = &handler_config 
    };

    err = nrfx_gpiote_input_configure(&gpiote, sensor->pin, &input_config);
    if (err != NRFX_SUCCESS) {
        printk("GPIOTE input config failed: %08x\n", err);
        return;
    }

	printk("GPIOTE EVENT_IN[%d] addr: %08x\n", 
           gpiote_in_channel, 
           nrfx_gpiote_in_event_address_get(&gpiote, sensor->pin));

    // Allocate PPI channel
    err = nrfx_gppi_channel_alloc(&ppi_channel);
    if (err != NRFX_SUCCESS) {
        printk("PPI channel alloc failed: %08x\n", err);
        return;
    }

    // Connect GPIOTE event to Timer1 capture task
    nrfx_gppi_channel_endpoints_setup(ppi_channel,
        nrfx_gpiote_in_event_address_get(&gpiote, sensor->pin),
        nrf_timer_task_address_get(NRF_TIMER2, NRF_TIMER_TASK_CAPTURE1));

    // Enable PPI channel and GPIOTE input
    nrfx_gppi_channels_enable(BIT(ppi_channel));
    nrfx_gpiote_trigger_enable(&gpiote, sensor->pin, true);
}


static void ready_button_pressed_isr(const struct device *dev, struct gpio_callback *cb, uint32_t pins)
{
    ARG_UNUSED(dev);
    ARG_UNUSED(cb);
    ARG_UNUSED(pins);
	
    /* Turn LED on */
	
	printk("Button pressed. Go to READY\n");
    fsm_transition(STATE_READY);
	
}


void init_seven_seg()
{
    if (tm1637_init() != TM1637_OK)
    {
        printk("Set up TM1637 failed\n");
    }
}


uint8_t setup_isr_for_gpio_in(const struct gpio_dt_spec *input)
{
	nrfx_err_t err;
    const nrfx_gpiote_t gpiote = NRFX_GPIOTE_INSTANCE(GPIOTE_INST);

	if (0 == nrfx_gpiote_init_check(&gpiote))
	{
		err = nrfx_gpiote_init(&gpiote, 0);
		if (err != NRFX_SUCCESS) {
			printk("GPIOTE init failed: %08x\n", err);
			return;
		}
	}
    
    // Allocate GPIOTE channel
    err = nrfx_gpiote_channel_alloc(&gpiote, &gpiote_in_channel_ready);
    if (err != NRFX_SUCCESS) {
        printk("GPIOTE channel alloc failed: %08x\n", err);
        return;
    }

    // Configure input pin
    nrfx_gpiote_trigger_config_t trigger_config = {
        .trigger = NRFX_GPIOTE_TRIGGER_HITOLO,
        .p_in_channel = &gpiote_in_channel_ready,
    };
    
	static const nrfx_gpiote_handler_config_t handler_config = {
		.handler = ready_button_pressed_isr,
	};

    nrfx_gpiote_input_pin_config_t input_config = {
        .p_pull_config = NULL,  // Use existing pull config
        .p_trigger_config = &trigger_config,
        .p_handler_config = &handler_config 
    };

    err = nrfx_gpiote_input_configure(&gpiote, input->pin, &input_config);
    if (err != NRFX_SUCCESS) {
        printk("GPIOTE input config failed: %08x\n", err);
        return;
    }

	printk("GPIOTE EVENT_IN[%d] addr: %08x\n", 
           gpiote_in_channel_ready, 
           nrfx_gpiote_in_event_address_get(&gpiote, input->pin));
	nrfx_gpiote_trigger_enable(&gpiote, input->pin, true);
 
}



uint8_t init_gpio_inputs()
{
    int ret = 0;
    ret = setup_isr_for_gpio_in(&button_ready);
	//ret |= setup_isr_for_gpio_in(button_test_sensor, sensor_triggered_isr, &button_cb_data_2);

	setup_ppi_for_sensor(&button_test_sensor);
	return ret;
}


uint32_t timer1_get_value()
{
	volatile uint32_t ticks = 0;
	int err = 1;
	if (!g_timer_initialized)
	{
		err = counter_get_value(hw_timer_1, &ticks);
		if (!err)
		{
			return ticks;
		} else {
			return TIMER_VALUE_MAX;
		}
	} else {
		return TIMER_VALUE_MAX;
	}
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


void timer_reset()
{
	for (uint16_t i = 0; i < TICKS_PER_LTR; ++i)
	{
		g_timestamps[i] = TIMER_VALUE_MAX;
		g_timestamp_idx_to_write = 0;
	}
		nrf_timer_task_trigger(NRF_TIMER2, NRF_TIMER_TASK_CLEAR);

    for (uint8_t i = 0; i < NRF_TIMER_CC_CHANNEL_COUNT(2); i++) {
        nrf_timer_cc_set(NRF_TIMER2, (nrf_timer_cc_channel_t)i, 0);
    }
    

    for (uint8_t i = 0; i < NRF_TIMER_CC_CHANNEL_COUNT(2); i++) {
        nrf_timer_event_clear(NRF_TIMER2, nrf_timer_compare_event_get(i));
    }
    

    nrf_timer_int_disable(NRF_TIMER2, NRF_TIMER_INT_COMPARE0_MASK |
                                  NRF_TIMER_INT_COMPARE1_MASK |
                                  NRF_TIMER_INT_COMPARE2_MASK |
                                  NRF_TIMER_INT_COMPARE3_MASK |
                                  NRF_TIMER_INT_COMPARE4_MASK |
                                  NRF_TIMER_INT_COMPARE5_MASK);

	nrf_timer_prescaler_set(NRF_TIMER2, NRF_TIMER_FREQ_125kHz);
	nrf_timer_mode_set(NRF_TIMER2, NRF_TIMER_MODE_TIMER);
    nrf_timer_bit_width_set(NRF_TIMER2, NRF_TIMER_BIT_WIDTH_32);
	nrf_timer_shorts_disable(NRF_TIMER2, NRF_TIMER_SHORT_COMPARE1_CLEAR_MASK | NRF_TIMER_SHORT_COMPARE0_CLEAR_MASK);

	
	printk("Successfully reset timer\n");
}


uint8_t IdleEntry(void) {return ERR_NO_IMPL;};
uint8_t IdleRun(void) {return ERR_NONE;};
uint8_t IdleExit(void) {return ERR_NONE;} ;

uint8_t ReadyEntry(void) {
	tm1637_display_ready(5);
	return ERR_NONE;
};
uint8_t ReadyRun(void){return ERR_NONE;};
uint8_t ReadyExit(void){return ERR_NONE;};


uint8_t RunningEntry(void)
{
	ble_stop_adv();
	return ERR_NONE;
};


uint8_t RunningRun(void)
{
	uint32_t current_timestamp = TIMER_VALUE_MAX;
	uint32_t last_saved_timestamp = 0;
	

	nrf_timer_task_trigger(NRF_TIMER2, NRF_TIMER_TASK_CAPTURE0); //sensor data on channel 1, task on channel 0
	current_timestamp = nrf_timer_cc_get(NRF_TIMER2, 0); //Capture is done via PPI
	unsigned int key = irq_lock();
	last_saved_timestamp = g_timestamps[g_timestamp_idx_to_write - 1];
	irq_unlock(key);
	printk("Got timerValue %d\n" , current_timestamp);

	uint64_t uS = current_timestamp * (1000000ULL / TIMER_FREQUENCY_HZ); //timetamp to microseconds (1 step = 8uS)
	uint8_t digits[4];
	digits[0] = (uint8_t)(uS / 10000000) % 10; //10sec
	digits[1] = (uint8_t)(uS / 1000000) % 10; //1sec
	digits[2] = (uint8_t)(uS / 100000) % 10; //100ms
	digits[3] = (uint8_t)(uS / 10000) % 10; //10ms

	tm1637_display_digits(digits, 8, 1);

	if (g_timestamp_idx_to_write > 0)
	{
		uint32_t diff = current_timestamp - last_saved_timestamp;
		printk("Diffed to %d\n", diff);
		
		if (diff  >= TIMER_TIMEOUT_TIMESTAMP_DIFF)
		{
			fsm_transition(STATE_SENDING);
		}
	}
	
	return ERR_NONE;
};


uint8_t RunningExit(void)
{
	nrf_timer_task_trigger(NRF_TIMER2, NRF_TIMER_TASK_STOP);
	is_running = false;
	printk("Called RunningExit\n");
	return ERR_NONE;
};

static K_TIMER_DEFINE(sending_timer, NULL, NULL);

uint8_t SendingEntry(void)
{
	uint32_t highest_stamp = g_timestamps[g_timestamp_idx_to_write - 1];
	printk("Highest timestamp at %d\n", highest_stamp);
	uint64_t uS = highest_stamp * (1000000ULL / TIMER_FREQUENCY_HZ); //timetamp to microseconds (1 step = 8uS)
	uint8_t digits[4];
	digits[0] = (uint8_t)(uS / 10000000) % 10; //10sec
	digits[1] = (uint8_t)(uS / 1000000) % 10; //1sec
	digits[2] = (uint8_t)(uS / 100000) % 10; //100ms
	digits[3] = (uint8_t)(uS / 10000) % 10; //10ms

	tm1637_display_digits(digits, 8, 1);
	//start a 10s timer
	k_timer_start(&sending_timer, K_SECONDS(10), K_NO_WAIT);
	return ERR_NONE;
};

static bool start_sent = false;


uint8_t SendingRun(void)
{
	if (is_ble_connected())
	{
		//call bluetooth function that takes an array of uint32 and chunks it according to the current MTU and sends it
		if (!start_sent)
		{
			int ret = 0;
			ret = ble_prepare_send(g_timestamps, g_timestamp_idx_to_write);
			if (ret == 0)
			{
				ret = ble_send_start();
				if (ret != 0)
				{
					printk("BLE start error\n");
					start_sent = 0;
					return ERR_API;
				} else {
					start_sent = true;
				}
			}
		} else {
			if (ble_is_sending())
			{
				int err = ble_send_chunk();
				if (err)
				{
					if (err != 0)
					{
						printk("BLE send chunk error\n");
						start_sent = false;  // Reset for retry
						return ERR_API;
					}
				}
			}
		}
	};
	if (k_timer_status_get(&sending_timer) > 0)
	{
		fsm_transition(STATE_READY);
	}
	return ERR_NONE;
}

uint8_t SendingExit(void)
{
	k_timer_stop(&sending_timer);
	return ERR_NONE;
};

uint8_t ErrorEntry(void){
	tm1637_display_error_message(5);
	return ERR_NONE;
};
uint8_t ErrorRun(void){return ERR_NONE;};
uint8_t ErrorExit(void){return ERR_NO_IMPL;};