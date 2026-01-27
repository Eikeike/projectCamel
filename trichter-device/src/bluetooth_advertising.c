#include <zephyr/kernel.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/hci.h>
#include <zephyr/sys/printk.h>

#include "bluetooth_advertising.h"
#include "bluetooth_common.h"
#include "fsm_core.h"
#include "state_machine.h"


#define BLE_ADV_FAST_TIMEOUT_SEC    30

#define BT_SM_PERIOD_MS             500

#define BLE_ADV_SLOW_INT_MIN        1364  //852.5ms, as per apple developer guidelines
#define BLE_ADV_SLOW_INT_MAX        1365
#define BLE_FSM_THREAD_STACK_SIZE   1024
#define BLE_FSM_THREAD_PRIO         3


static K_THREAD_STACK_DEFINE(ble_fsm_stack, BLE_FSM_THREAD_STACK_SIZE);
static struct k_thread ble_fsm_thread_data;

static uint8_t g_ble_fsm_run = 1;

typedef enum
{
    BLE_STATE_IDLE = 0,
    BLE_STATE_ADV_FAST,
    BLE_STATE_ADV_SLOW,
    BLE_STATE_STOP,
    BLE_STATE_ERROR,
    BLE_STATE_MAX
} BleStateId_t;

#define NUM_STATES_BLE BLE_STATE_MAX

static StateMachine_t g_ble_sm;

static struct k_timer adv_fast_timer;

static bool g_adv_active = false;

/* Forward declare */
static uint8_t ble_state_idle(void);
static uint8_t ble_state_adv_fast(void);
static uint8_t ble_state_adv_slow(void);
static uint8_t ble_state_stop(void);
static uint8_t ble_state_error(void);
static uint8_t ble_state_no_impl(void);


static const State_t BLE_STATES[NUM_STATES_BLE] =
{
    [BLE_STATE_IDLE] =
    {
        .id = BLE_STATE_IDLE,
        .onEntry = ble_state_idle,
        .runLoop = ble_state_no_impl,
        .onExit  = ble_state_no_impl,
        .allowedTransitions = {BLE_STATE_ADV_FAST, BLE_STATE_ADV_SLOW, BLE_STATE_MAX, BLE_STATE_MAX, BLE_STATE_MAX}
    },
    [BLE_STATE_ADV_FAST] =
    {
        .id = BLE_STATE_ADV_FAST,
        .onEntry = ble_state_adv_fast,
        .runLoop = ble_state_no_impl,
        .onExit  = ble_state_no_impl,
        .allowedTransitions = {BLE_STATE_IDLE, BLE_STATE_ADV_SLOW, BLE_STATE_MAX, BLE_STATE_MAX, BLE_STATE_MAX}
    },
    [BLE_STATE_ADV_SLOW] =
    {
        .id = BLE_STATE_ADV_SLOW,
        .onEntry = ble_state_adv_slow,
        .runLoop = ble_state_no_impl,
        .onExit  = ble_state_no_impl,
        .allowedTransitions = {BLE_STATE_IDLE, BLE_STATE_ADV_FAST, BLE_STATE_MAX, BLE_STATE_MAX, BLE_STATE_MAX}
    },
    [BLE_STATE_STOP] =
    {
        .id = BLE_STATE_STOP,
        .onEntry = ble_state_stop,
        .runLoop = ble_state_no_impl,
        .onExit  = ble_state_no_impl,
        .allowedTransitions = {BLE_STATE_IDLE, BLE_STATE_MAX, BLE_STATE_MAX, BLE_STATE_MAX, BLE_STATE_MAX}
    },
    [BLE_STATE_ERROR] =
    {
        .id = BLE_STATE_ERROR,
        .onEntry = ble_state_error,
        .runLoop = ble_state_no_impl,
        .onExit  = ble_state_no_impl,
        .allowedTransitions = {BLE_STATE_IDLE, BLE_STATE_MAX, BLE_STATE_MAX, BLE_STATE_MAX, BLE_STATE_MAX}
    },
};


/* Advertising data */
struct bt_data ad[] = {
    BT_DATA_BYTES(BT_DATA_FLAGS, (BT_LE_AD_GENERAL | BT_LE_AD_NO_BREDR)),
    BT_DATA(BT_DATA_NAME_COMPLETE,
            CONFIG_BT_DEVICE_NAME,
            sizeof(CONFIG_BT_DEVICE_NAME) - 1) // sizeof ist sicherer als strlen bei Konstanten
};

struct bt_data sd[] = {
    BT_DATA_BYTES(BT_DATA_UUID128_ALL, BT_UUID_CUSTOM_SERVICE_VAL)
};

/* Advertising Params */
struct bt_le_adv_param *adv_fast_param =
    BT_LE_ADV_PARAM(BT_LE_ADV_OPT_CONN,
                     BT_GAP_ADV_FAST_INT_MIN_1,
                     BT_GAP_ADV_FAST_INT_MAX_1,
                     NULL);

struct bt_le_adv_param *adv_slow_param =
    BT_LE_ADV_PARAM(BT_LE_ADV_OPT_CONN,
                     BLE_ADV_SLOW_INT_MIN,
                     BLE_ADV_SLOW_INT_MAX,
                     NULL);


// Minimal FSM main for BLE
static void ble_fsm_main(void *p1, void *p2, void *p3)
{
    while (g_ble_fsm_run)
    {
        if (g_ble_sm.requestStateDeferred != BLE_STATE_MAX)
        {
            printk("Going to transition BLE\n");
            ble_fsm_transition(&g_ble_sm, g_ble_sm.requestStateDeferred);

            unsigned int key = irq_lock();
            g_ble_sm.requestStateDeferred = BLE_STATE_MAX;
            irq_unlock(key);
        }
        k_msleep(g_ble_sm.period_ms);
    }
}


static void adv_fast_timeout(struct k_timer *timer)
{
    ble_fsm_transition_deferred(&g_ble_sm, BLE_STATE_ADV_SLOW);
}


static uint8_t ble_adv_start(const struct bt_le_adv_param *param)
{
    int err;

    if (g_adv_active)
    {
        return ERR_NONE;
    }
    printk("Starting advertising\n");
    err = bt_le_adv_start(param, ad, ARRAY_SIZE(ad), sd, ARRAY_SIZE(sd));
    if (err)
    {
        printk("BLE adv start failed (%d)\n", err);
        return ERR_API;
    }

    g_adv_active = true;
    return ERR_NONE;
}


static void ble_adv_stop(void)
{
    printk("Stopping advertising\n");
    if (!g_adv_active)
    {
        return;
    }

    bt_le_adv_stop();
    g_adv_active = false;
}


static uint8_t ble_state_idle(void)
{
    return ERR_NONE;
}

static uint8_t ble_state_adv_fast(void)
{
    return ble_adv_start(adv_fast_param);
}

static uint8_t ble_state_adv_slow(void)
{
    return ble_adv_start(adv_slow_param);
}

static uint8_t ble_state_stop(void)
{
    ble_adv_stop();
    ble_fsm_transition_deferred(&g_ble_sm, BLE_STATE_IDLE);
    return ERR_NONE;
}

static uint8_t ble_state_error(void)
{
    ble_adv_stop();
    return ERR_NONE;
}

static uint8_t ble_state_no_impl()
{
    return ERR_NONE;
}


void bluetooth_advertising_fsm_start(void)
{
    k_mutex_init(&g_ble_sm.lock);

    g_ble_sm.current = &BLE_STATES[BLE_STATE_IDLE];
    g_ble_sm.error = ERR_NONE;
    g_ble_sm.period_ms = BT_SM_PERIOD_MS;
    g_ble_sm.requestStateDeferred = BLE_STATE_MAX;
    g_ble_sm.name = "BLE FSM";
    g_ble_sm.states = BLE_STATES;
    g_ble_sm.num_states = NUM_STATES_BLE;
    g_ble_sm.notify = false;

    k_timer_init(&adv_fast_timer, adv_fast_timeout, NULL);

    g_adv_active = false;
    k_thread_create(&ble_fsm_thread_data, ble_fsm_stack,
                K_THREAD_STACK_SIZEOF(ble_fsm_stack),
                ble_fsm_main,
                NULL, NULL, NULL,
                BLE_FSM_THREAD_PRIO,
                0,
                K_NO_WAIT);
}

void bluetooth_advertising_start_fast(void)
{
    printk("Requested fast adv\n");
    k_timer_start(&adv_fast_timer, K_SECONDS(BLE_ADV_FAST_TIMEOUT_SEC), K_NO_WAIT);
    ble_fsm_transition_deferred(&g_ble_sm, BLE_STATE_ADV_FAST);
}


void bluetooth_advertising_start_slow(void)
{
    printk("Requested slow adv\n");
    k_timer_stop(&adv_fast_timer);
    ble_fsm_transition_deferred(&g_ble_sm, BLE_STATE_ADV_SLOW);
}


void bluetooth_advertising_stop(void)
{
    k_timer_stop(&adv_fast_timer);
    ble_fsm_transition(&g_ble_sm, BLE_STATE_STOP);
}


bool bluetooth_advertising_is_active(void)
{
    return g_adv_active;
}
