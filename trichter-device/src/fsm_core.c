#include <stdint.h>
#include <zephyr/kernel.h>
#include "state_machine.h"
#include "fsm_core.h"


#define STATE_MACHINE_THREAD_PRIO			3
#define STATE_MACHINE_THREAD_STACK_SIZE 	1024

uint8_t g_fsm_run = 1;

StateMachine_t g_stateMachine;

K_THREAD_STACK_DEFINE(state_machine_stack, STATE_MACHINE_THREAD_STACK_SIZE);
static struct k_thread state_machine_thread_data;


static uint8_t fsm_transition_internal(StateMachine_t *sm, StateID_t targetState)
{
    uint8_t ret = ERR_NONE;
    k_mutex_lock(&sm->lock, K_FOREVER);
    printk("Requested transition from %d to %d\n", sm->current->id, targetState);
    ret = state_machine_transition(sm, targetState);
    k_mutex_unlock(&sm->lock);

    if (ret != ERR_NONE && ret != ERR_TRANSITION_FORBIDDEN) //on invalid transitions, simply do not do anything
    {
        k_mutex_lock(&sm->lock, K_FOREVER);
        ret = state_machine_transition(sm, STATE_ERROR);
        sm->requestStateDeferred = STATE_MAX; //Clear any pending deferred requests
        k_mutex_unlock(&sm->lock);
    }
    return ret;
}

static uint8_t fsm_transition_deferred_internal(StateMachine_t *sm, StateID_t state)
{
    if (sm->current->id == STATE_ERROR)
    {
        return ERR_TRANSITION_FORBIDDEN;
    };
    sm->requestStateDeferred = state;
    return ERR_NONE;
}


void fsm_main(void *p1, void *p2, void *p3)
{
    uint8_t ret = ERR_NONE;
    while (g_fsm_run)
    {
        k_mutex_lock(&g_stateMachine.lock, K_FOREVER);
        ret = g_stateMachine.current->runLoop();
        k_mutex_unlock(&g_stateMachine.lock);

        if (ret != ERR_NONE)
        {
            fsm_transition(STATE_ERROR);
            g_fsm_run = 0;
        } else if (g_stateMachine.requestStateDeferred != STATE_MAX)
        {
            fsm_transition(g_stateMachine.requestStateDeferred);
            unsigned int key = irq_lock(); //Do not allow interrupts to request deferred
            g_stateMachine.requestStateDeferred = STATE_MAX;
            irq_unlock(key);
        }
        k_msleep(g_stateMachine.period_ms);
    }
}


void fsm_start()
{
    k_mutex_init(&g_stateMachine.lock);
    g_stateMachine.current = &STATES[STATE_IDLE];
    g_stateMachine.error = ERR_NONE;
    g_stateMachine.period_ms = FSM_PERIOD_FAST_MS;
    g_stateMachine.requestStateDeferred = STATE_MAX;

    k_thread_create(&state_machine_thread_data, state_machine_stack, K_THREAD_STACK_SIZEOF(state_machine_stack), fsm_main, NULL, NULL, NULL, STATE_MACHINE_THREAD_PRIO, 0, K_NO_WAIT);
}


uint8_t fsm_transition(StateID_t targetState)
{
    return fsm_transition_internal(&g_stateMachine, targetState);
}


uint8_t fsm_transition_deferred(StateID_t state)
{
    return fsm_transition_deferred_internal(&g_stateMachine, state);
}


uint8_t ble_fsm_transition(StateMachine_t *sm, StateID_t targetState)
{
    return fsm_transition_internal(sm, targetState);
}


uint8_t ble_fsm_transition_deferred(StateMachine_t *sm, StateID_t state)
{
    return fsm_transition_deferred_internal(sm, state);
}
