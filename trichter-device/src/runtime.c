
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
#include "memory.h"

#define TICKS_PER_LTR 300
static volatile uint32_t g_timestamps[TICKS_PER_LTR];
static volatile uint16_t g_timestamp_idx_to_write = 0;

#define TIMER_VALUE_MAX 				0xFFFFFFFF //32bit of 1b

#define TIMER_FREQUENCY_HZ				125000
#define TIMER_TICK_DURATION_US			8
#define MEARUEMENT_END_TIMEOUT_MS		1000 //TODO Adapt to real values with: max_drinking_time / (TICKS_PER_LTR/2) = max_time_between ticks
#define TIMER_TIMEOUT_TIMESTAMP_DIFF	TIMER_FREQUENCY_HZ / 1000 * MEARUEMENT_END_TIMEOUT_MS

#define ADV_BLINK_TIME_MS				1500
#define TIMER_LONGPRESS_TIME_MS			4000
static uint64_t last_timestamp_blink = 0;
static uint64_t last_timestamp_ready_button = 0; 


static uint8_t ppi_channel;
static uint8_t gpiote_in_channel;
static uint8_t gpiote_in_channel_ready;

uint8_t is_running = false;
uint8_t party_mode = false;

static K_TIMER_DEFINE(fsm_timer, NULL, NULL);

void double_click_timer_exp(struct k_timer *timer);
static K_TIMER_DEFINE(click_timer, double_click_timer_exp, NULL);
void start_double_click_timer(struct k_work *work);
K_WORK_DEFINE(double_click_timer_work, start_double_click_timer);

void adv_timer_exp(struct k_timer *timer);
static K_TIMER_DEFINE(adv_timer, adv_timer_exp, NULL);
static bool g_advertise_in_ready = 0;

static uint8_t num_clicks = 0;
#define DEBOUNCE_CLICK_MS			20
#define MAX_DOUBLE_CLICK_TIMEOUT_MS	1000


/*forward declare*/
uint32_t timer1_get_value();

static void sensor_triggered_isr(nrfx_gpiote_pin_t pin, nrfx_gpiote_trigger_t trigger, void *context)
{
	if (!is_running)
	{
		timer_reset();
		nrf_timer_task_trigger(NRF_TIMER2, NRF_TIMER_TASK_START); //starts timer in free running mode
		if (g_stateMachine.current->id != STATE_CALIBRATING)
		{
			fsm_transition_deferred(STATE_RUNNING);
		}
	}
	if (g_stateMachine.current->id == STATE_RUNNING || g_stateMachine.requestStateDeferred == STATE_RUNNING ||
		g_stateMachine.current->id == STATE_CALIBRATING|| g_stateMachine.requestStateDeferred == STATE_CALIBRATING)
	{
		is_running = true;
		g_timestamps[g_timestamp_idx_to_write] = nrf_timer_cc_get(NRF_TIMER2, 1); //Read value on channel 1
		g_timestamp_idx_to_write++;
	}
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
	printk("Button pressed at %lldms\n", k_uptime_get());

	num_clicks++;
	if (num_clicks == 1)
	{
		printk("Go to READY\n");
    	fsm_transition_deferred(STATE_READY);
		if (!k_work_is_pending(&double_click_timer_work))
		{
			k_work_submit(&double_click_timer_work);
		}
	} else if (num_clicks == 2)
	{
		printk("Button pressed again. Start advertising\n");
    	g_advertise_in_ready = true;
	}
	last_timestamp_ready_button = k_uptime_get();
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


void double_click_timer_exp(struct k_timer *timer)
{
	//No double click detected
	printk("Double click expired at %lldms\n", k_uptime_get());
	num_clicks = 0;
}


void start_double_click_timer(struct k_work *work)
{
	printk("Work: start timer at %lldms\n", k_uptime_get());
	k_timer_start(&click_timer, K_MSEC(MAX_DOUBLE_CLICK_TIMEOUT_MS), K_NO_WAIT);
}


void adv_timer_exp(struct k_timer *timer)
{
	ble_stop_adv();
}


uint8_t init_gpio_inputs()
{
    int ret = 0;
    ret = setup_isr_for_gpio_in(&button_ready);
	//ret |= setup_isr_for_gpio_in(button_test_sensor, sensor_triggered_isr, &button_cb_data_2);

	setup_ppi_for_sensor(&button_test_sensor);
	//ret = gpio_pin_configure_dt(&button_ready, GPIO_INPUT);
	if (ret != 0)
	{
		printk("Error %d: failed to configure button device %s pin %d\n", ret, button_ready.port->name, button_ready.pin);
	} else {
		printk("Set up Ready button at %s pin %d\n", button_ready.port->name, button_ready.pin);
	}
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


uint8_t IdleEntry(void)
{
	tm1637_display_off();
	gpio_pin_set_dt(&led, 1);
	g_stateMachine.period_ms = FSM_PERIOD_SLOW_MS;
	return ERR_NONE;
};

uint8_t IdleRun(void) {return ERR_NONE;};
uint8_t IdleExit(void)
{
	g_stateMachine.period_ms = FSM_PERIOD_FAST_MS;
	return ERR_NONE;
} ;


uint8_t ReadyEntry(void)
{
	if (party_mode)
	{
		tm1637_display_bier(5);
	} else {
		tm1637_display_ready(2);
	}
	k_timer_start(&fsm_timer, K_SECONDS(120), K_NO_WAIT);
	g_stateMachine.period_ms = FSM_PERIOD_SLOW_MS;
	return ERR_NONE;
};


uint8_t ReadyRun(void)
{
	if (g_advertise_in_ready)
	{
		if (!ble_is_adv())
		{
			ble_start_adv();
			k_timer_start(&adv_timer, K_SECONDS(120), K_NO_WAIT); //advertise for 2min max
		}
		//blinking while advertising
		uint64_t now = k_uptime_get();
		if ((now - last_timestamp_blink) > ADV_BLINK_TIME_MS)
		{
			gpio_pin_toggle_dt(&led);
			last_timestamp_blink = now;
		}
	}

	//longpress detection
	printk("Ready button %d\n", gpio_pin_get_dt(&button_ready));
	if (gpio_pin_get_dt(&button_ready) == 0)
	{
		if ((k_uptime_get() - last_timestamp_ready_button) > TIMER_LONGPRESS_TIME_MS)
		{
			last_timestamp_ready_button = k_uptime_get(); 
			fsm_transition(STATE_CALIBRATING);
		}
	}
	
	if (k_timer_status_get(&fsm_timer) > 0)
	{
		fsm_transition(STATE_IDLE);
	}
	return ERR_NONE;
};


uint8_t ReadyExit(void)
{
	k_timer_stop(&fsm_timer); //TODO assign fsm_timer to state machine and stop it on each transition request
	ble_stop_adv();
	return ERR_NONE;
};


uint8_t RunningEntry(void)
{
	ble_stop_adv();
	k_timer_stop(&adv_timer);
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
	//printk("Got timerValue %d\n" , current_timestamp);

	uint64_t uS = current_timestamp * (1000000ULL / TIMER_FREQUENCY_HZ); //timetamp to microseconds (1 step = 8uS)
	uint8_t digits[4];
	digits[0] = (uint8_t)(uS / 10000000) % 10; //10sec
	digits[1] = (uint8_t)(uS / 1000000) % 10; //1sec
	digits[2] = (uint8_t)(uS / 100000) % 10; //100ms
	digits[3] = (uint8_t)(uS / 10000) % 10; //10ms

	tm1637_display_digits(digits, 4, 8, 1);

	if (g_timestamp_idx_to_write > 0)
	{
		uint32_t diff = current_timestamp - last_saved_timestamp;
		//printk("Diffed to %d\n", diff);
		
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

uint8_t CalibEntry(void)
{
	tm1637_display_cal(5);
	return ERR_NONE;
};


uint8_t CalibRun(void)
{
	uint32_t current_timestamp = TIMER_VALUE_MAX;
	uint32_t last_saved_timestamp = 0;
	
	nrf_timer_task_trigger(NRF_TIMER2, NRF_TIMER_TASK_CAPTURE0); //sensor data on channel 1, task on channel 0
	current_timestamp = nrf_timer_cc_get(NRF_TIMER2, 0); //Capture is done via PPI
	unsigned int key = irq_lock();
	if (g_timestamp_idx_to_write >= 1)
	{
		last_saved_timestamp = g_timestamps[g_timestamp_idx_to_write - 1];
	}
	irq_unlock(key);

	uint8_t digits[4];
	digits[0] = (uint8_t)(g_timestamp_idx_to_write / 1000) % 10; //1000
	digits[1] = (uint8_t)(g_timestamp_idx_to_write / 100) % 10; //100
	digits[2] = (uint8_t)(g_timestamp_idx_to_write / 10) % 10; //10
	digits[3] = (uint8_t)g_timestamp_idx_to_write % 10; //1

	// I hate this 
	uint8_t num_digits =
    (g_timestamp_idx_to_write >= 1000) ? 4 :
    (g_timestamp_idx_to_write >= 100)  ? 3 :
    (g_timestamp_idx_to_write >= 10)   ? 2 : 1;

	tm1637_display_digits(digits, num_digits, 6, 5); //dot at 5 = no dot

	if (g_timestamp_idx_to_write > 0)
	{
		uint32_t diff = current_timestamp - last_saved_timestamp;
		//printk("Diffed to %d\n", diff);
		
		if (diff  >= TIMER_TIMEOUT_TIMESTAMP_DIFF)
		{
			global_calibration_value = g_timestamp_idx_to_write;
			fsm_transition(STATE_READY);
		}
	}
	return ERR_NONE;
};


uint8_t CalibExit(void)
{
	is_running = false;
	nrf_timer_task_trigger(NRF_TIMER2, NRF_TIMER_TASK_STOP);
	save_counter_ram_to_rom();
	return ERR_NONE;
};


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

	tm1637_display_digits(digits, 4, 8, 1);
	//start a 10s timer
	k_timer_start(&fsm_timer, K_SECONDS(10), K_NO_WAIT);
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
						start_sent = false;
						return ERR_API;
					}
				}
			}
		}
	};
	if (k_timer_status_get(&fsm_timer) > 0)
	{
		fsm_transition(STATE_READY);
	}
	return ERR_NONE;
}

uint8_t SendingExit(void)
{
	start_sent = false;
	k_timer_stop(&fsm_timer);
	return ERR_NONE;
};

uint8_t ErrorEntry(void){
	tm1637_display_error_message(5);
	return ERR_NONE;
};
uint8_t ErrorRun(void){return ERR_NONE;};
uint8_t ErrorExit(void){return ERR_NO_IMPL;};