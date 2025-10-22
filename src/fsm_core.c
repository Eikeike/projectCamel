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


void fsm_start()
{
    k_mutex_init(&g_stateMachine.lock);
    g_stateMachine.current = &STATES[STATE_IDLE];
    g_stateMachine.error = ERR_NONE;

    k_thread_create(&state_machine_thread_data, state_machine_stack, K_THREAD_STACK_SIZEOF(state_machine_stack), fsm_main, NULL, NULL, NULL, STATE_MACHINE_THREAD_PRIO, 0, K_NO_WAIT);
    //k_thread_name_set(&state_machine_thread_data, "statemachinethread");
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
        } else if (g_stateMachine.requestStateDeferred)
        {
            if (g_stateMachine.requestStateDeferred != STATE_MAX)
            {
                fsm_transition(g_stateMachine.requestStateDeferred);
                unsigned int key = irq_lock(); //Do not allow interrupts to request deferred
                g_stateMachine.requestStateDeferred = STATE_MAX;
                irq_unlock(key);
            }
        }
        k_msleep(9); //9ms because display and measurement resolution is 10ms
    }
    ARG_UNUSED(p1);
    ARG_UNUSED(p2);
    ARG_UNUSED(p3);
}


uint8_t fsm_transition(StateID_t targetState)
{
    uint8_t ret = ERR_NONE;
    k_mutex_lock(&g_stateMachine.lock, K_FOREVER);
    printk("Requested transition from %d to %d\n", g_stateMachine.current->id, targetState);
    ret = state_machine_transition(&g_stateMachine, targetState);
    k_mutex_unlock(&g_stateMachine.lock);

    if (ret != ERR_NONE && ret != ERR_TRANSITION_FORBIDDEN) //on invalid transitions, simply do not do anything
    {
        k_mutex_lock(&g_stateMachine.lock, K_FOREVER);
        ret = state_machine_transition(&g_stateMachine, STATE_ERROR);
        g_stateMachine.requestStateDeferred = STATE_MAX; //Clear any pending deferred requests
        k_mutex_unlock(&g_stateMachine.lock);
    }
    return ret;
    
}


uint8_t fsm_transition_deferred(StateID_t state)
{
    if (g_stateMachine.current->id == STATE_ERROR)
    {
        return ERR_TRANSITION_FORBIDDEN;
    };
    g_stateMachine.requestStateDeferred = state;
    return ERR_NONE;
}