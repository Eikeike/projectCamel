
#include <stdint.h>
#include <hal/nrf_gpio.h>
#include <hal/nrf_gpiote.h>
#include <gpiote_nrfx.h>
#include <hal/nrf_timer.h>
#include <zephyr/drivers/counter.h>
#include <nrfx_gpiote.h>
#include <zephyr/irq.h>
#include <helpers/nrfx_gppi.h>
#include "runtime.h"
#include "drivers/nrfx_errors.h"
#include "mdk/nrf52.h"
#include "state_machine.h"
#include "tm1637.h"
#include "devicetree_devices.h"
#include "fsm_core.h"
#include "bluetooth.h"
#include "memory.h"
#include "zephyr/drivers/gpio.h"
#include "zephyr/kernel.h"

#define TICKS_PER_LTR 300
static volatile uint32_t g_timestamps[TICKS_PER_LTR];
static volatile uint16_t g_timestamp_idx_to_write = 0;

#define TIMER_VALUE_MAX 				0xFFFFFFFF

#define ADV_BLINK_TIME_MS				1500
#define PRINT_TIMESTAMPS_IN_CONSOLE

static uint64_t last_timestamp_blink = 0;
static uint8_t is_running = false;
static uint8_t party_mode = false;
static bool g_advertise_in_ready = 0;
static bool g_valid_calibration = false;
#define SENSOR_QUALIFICATION_BURST_WINDOW_MS	K_MSEC(150)
#define MIN_TIMESTAMPS_IN_BURST_WINDOW			3

static bool start_sent = false;

static K_TIMER_DEFINE(fsm_timer, NULL, NULL);

void adv_timer_exp(struct k_timer *timer);
static K_TIMER_DEFINE(adv_timer, adv_timer_exp, NULL);

static void sensor_qualification_handler(struct k_work *work);
K_WORK_DELAYABLE_DEFINE(sensor_qualification_work, sensor_qualification_handler);


void timer_reset();


void sensor_triggered_isr(const struct device *dev, struct gpio_callback *cb, unsigned int pins)
{
	if (!is_running)
	{
		timer_reset();
		nrf_timer_task_trigger(NRF_TIMER2, NRF_TIMER_TASK_START); //starts timer in free running mode
		k_work_schedule(&sensor_qualification_work, SENSOR_QUALIFICATION_BURST_WINDOW_MS);
		is_running = true;
	}
	if (g_timestamp_idx_to_write < TICKS_PER_LTR)
	{
		g_timestamps[g_timestamp_idx_to_write] = nrf_timer_cc_get(NRF_TIMER2, 1); //Read value on channel 1
		printk("Sensor pressed at %d\n", g_timestamps[g_timestamp_idx_to_write]);
	}
	g_timestamp_idx_to_write++;
	
/* 	if (g_stateMachine.current->id == STATE_RUNNING || g_stateMachine.requestStateDeferred == STATE_RUNNING ||
		g_stateMachine.current->id == STATE_CALIBRATING|| g_stateMachine.requestStateDeferred == STATE_CALIBRATING)
	{
		
	} */
}

/*
This is hit 150ms after the very first interrupt, if this is not a detected burst, return like nothing happened
*/
static void sensor_qualification_handler(struct k_work *work)
{
	printk("Handler executing with timestamps received = %d", g_timestamp_idx_to_write);
	if (g_timestamp_idx_to_write >= MIN_TIMESTAMPS_IN_BURST_WINDOW)
	{
		if (g_stateMachine.current->id != STATE_CALIBRATING)
		{
			fsm_transition_deferred(STATE_RUNNING);
		} else {
			g_valid_calibration = true;
		}
	} else {
		g_valid_calibration = false;
		timer_reset();
		is_running = false;
	}
	
}


void on_single_click()
{
	if (!ble_is_sending())
	{
		fsm_transition(STATE_READY);
	}
}


void on_double_click()
{
	g_advertise_in_ready = true;
	ble_delete_active_connection();
}


void on_long_click()
{
	fsm_transition(STATE_CALIBRATING);
}


void init_seven_seg()
{
    if (tm1637_init() != TM1637_OK)
    {
        printk("Set up TM1637 failed\n");
    }
}

void adv_timer_exp(struct k_timer *timer)
{
	ble_stop_adv();
	g_advertise_in_ready = false;
}


void timer_reset()
{
	for (uint16_t i = 0; i < TICKS_PER_LTR; ++i)
	{
		g_timestamps[i] = 0;
	}
	g_timestamp_idx_to_write = 0;
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

void on_trichter_startup()
{
	g_advertise_in_ready = true;
    fsm_transition_deferred(STATE_READY);
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
	if (g_advertise_in_ready || ble_is_adv())
	{
		if (!is_ble_connected())
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
	}
	
	if (is_ble_connected()) {
		gpio_pin_set_dt(&led, 1); // solid LED when connected
	}

	//longpress detection
	printk("Ready button %d\n", gpio_pin_get_dt(&button_ready));
	/*
	if (gpio_pin_get_dt(&button_ready) == 1)
	{
		if ((k_uptime_get() - g_ready_button.last_timestamp_ready_button) > TIMER_LONGPRESS_TIME_MS)
		{
			g_ready_button.last_timestamp_ready_button = k_uptime_get(); 
			fsm_transition(STATE_CALIBRATING);
		}
	}
	*/
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
	g_advertise_in_ready = false;
	return ERR_NONE;
};


uint8_t RunningEntry(void)
{
	ble_stop_adv();
	k_timer_stop(&adv_timer);
	g_stateMachine.period_ms = FSM_PERIOD_FAST_MS;
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

	tm1637_display_digits(digits, 4, TM1637_BRIGHTNESS_HIGH, 1);

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
	timer_reset();
	g_stateMachine.period_ms = FSM_PERIOD_FAST_MS;
	g_valid_calibration = false;
	return ERR_NONE;
};


uint8_t CalibRun(void)
{
	uint32_t current_timestamp = TIMER_VALUE_MAX;
	uint32_t last_saved_timestamp = 0;
	
	nrf_timer_task_trigger(NRF_TIMER2, NRF_TIMER_TASK_CAPTURE0); //sensor data on channel 1, task on channel 0
	current_timestamp = nrf_timer_cc_get(NRF_TIMER2, 0); //Capture is done via PPI
	if (g_timestamp_idx_to_write >= MIN_TIMESTAMPS_IN_BURST_WINDOW)
	{
		unsigned int key = irq_lock();
		last_saved_timestamp = g_timestamps[g_timestamp_idx_to_write - 1];
		irq_unlock(key);

		uint8_t digits[4];
		digits[3] = (uint8_t)g_timestamp_idx_to_write % 10; //1
		digits[2] = (uint8_t)(g_timestamp_idx_to_write / 10) % 10; //10
		digits[1] = (uint8_t)(g_timestamp_idx_to_write / 100) % 10; //100
		digits[0] = (uint8_t)(g_timestamp_idx_to_write / 1000) % 10; //1000

		tm1637_display_digits(digits, 4, TM1637_BRIGHTNESS_MID, 5); //dot at 5 = no dot
		uint32_t diff = current_timestamp - last_saved_timestamp;
		printk("Diffed to %d\n", diff);
		
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
	if (g_valid_calibration)
	{
		save_counter_ram_to_rom();
	}
	return ERR_NONE;
};


#ifdef PRINT_TIMESTAMPS_IN_CONSOLE
void print_all_timestamps()
{

	printk("================ALL TIMESTAMPS==================\n");
	printk("[");
	for (int i = 0; i < g_timestamp_idx_to_write; i++)
	{
		uint8_t *b = (uint8_t *)&g_timestamps[i];
		printk("%d, ", g_timestamps[i]);
		k_msleep(8);
	}
	printk("]");
}
#endif


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
	k_timer_start(&fsm_timer, K_SECONDS(30), K_NO_WAIT);

	#ifdef PRINT_TIMESTAMPS_IN_CONSOLE
	print_all_timestamps();
	#endif
	return ERR_NONE;
};


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