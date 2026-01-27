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

extern uint8_t IdleEntry(void);
extern uint8_t IdleRun(void);
extern uint8_t IdleExit(void);

extern uint8_t ReadyEntry(void);
extern uint8_t ReadyRun(void);
extern uint8_t ReadyExit(void);

extern uint8_t RunningEntry(void);
extern uint8_t RunningRun(void);
extern uint8_t RunningExit(void);

extern uint8_t SendingEntry(void);
extern uint8_t SendingRun(void);
extern uint8_t SendingExit(void);

extern uint8_t ErrorEntry(void);
extern uint8_t ErrorRun(void);
extern uint8_t ErrorExit(void);

const State_t STATES[NUM_STATES + 1] = {
    [STATE_IDLE] = {
        .id = STATE_IDLE,
        .onEntry = IdleEntry,
        .runLoop = IdleRun,
        .onExit = IdleExit,
        .allowedTransitions = {STATE_RUNNING, STATE_ERROR, STATE_READY, STATE_MAX, STATE_MAX}
    },
    [STATE_READY] = {
        .id = STATE_READY,
        .onEntry = ReadyEntry,
        .runLoop = ReadyRun,
        .onExit = ReadyExit,
        .allowedTransitions = {STATE_RUNNING, STATE_IDLE, STATE_CALIBRATING, STATE_MAX, STATE_MAX}
    },
    [STATE_RUNNING] = {
        .id = STATE_RUNNING,
        .onEntry = RunningEntry,
        .runLoop = RunningRun,
        .onExit = RunningExit,
        .allowedTransitions = {STATE_SENDING, STATE_ERROR, STATE_MAX, STATE_MAX, STATE_MAX}
    },
    [STATE_SENDING] = {
        .id = STATE_SENDING,
        .onEntry = SendingEntry,
        .runLoop = SendingRun,
        .onExit = SendingExit,
        .allowedTransitions = {STATE_ERROR, STATE_READY, STATE_MAX, STATE_MAX, STATE_MAX}
    },
    [STATE_CALIBRATING] = {
        .id = STATE_CALIBRATING,
        .onEntry = CalibEntry,
        .runLoop = CalibRun,
        .onExit = CalibExit,
        .allowedTransitions = {STATE_READY, STATE_ERROR, STATE_MAX, STATE_MAX, STATE_MAX}
    },
    [STATE_ERROR] = {
        .id = STATE_ERROR,
        .onEntry = ErrorEntry,
        .runLoop = ErrorRun,
        .onExit = ErrorExit,
        .allowedTransitions = {STATE_ERROR, STATE_MAX, STATE_MAX, STATE_MAX, STATE_MAX}
    }
};


static uint8_t fsm_transition_internal(StateMachine_t *sm, StateID_t targetState)
{
    uint8_t ret = ERR_NONE;
    k_mutex_lock(&sm->lock, K_FOREVER);
    printk("%s: Requested transition from %d to %d\n", sm->name, sm->current->id, targetState);
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
    g_stateMachine.name = "Main FSM";
    g_stateMachine.states = STATES;
    g_stateMachine.num_states = NUM_STATES;
    g_stateMachine.notify = true;

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
