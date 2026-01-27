
#include <stdint.h>
#include "state_machine.h"

static StateNotifier g_state_notifier;

static uint8_t is_transition_allowed(const State_t *currState, StateID_t targetState)
{
    //Error checks --> targetState within num_states is checked by transition function!
    if (currState->allowedTransitions == NULL)
    {
        return 0;
    }

    //Implementation
    for (int state = 0; state < MAX_TRANSITIONS; state++)
    {
        if (currState->allowedTransitions[state] == targetState)
        {
            return 1;
        }
    }
    return 0;
}


uint8_t state_machine_transition(StateMachine_t *stateMachine, StateID_t targetState)
{
    //Error Checks
    if (!stateMachine || !stateMachine->current || targetState > stateMachine->num_states)
    {
        printk("Invalid State request\n");
        return ERR_INVALID_PARAM;
        
    }
    if (!stateMachine->current->onEntry || !stateMachine->current->onExit)
    {
        printk("Invalid function definitions\n");
        return ERR_INVALID_PARAM;
    }

    //Implementation
    uint8_t ret = ERR_NONE;
    if (0 == is_transition_allowed(stateMachine->current, targetState))
    {
        printk("State transition not allowed\n");
        ret = ERR_TRANSITION_FORBIDDEN;
    } else {
        ret = stateMachine->current->onExit(); 
        printk("OnExit returned %d", ret);
        if (ret != ERR_NONE && ret != ERR_NO_IMPL)
        {
            return ret;
        }
        if (ret == ERR_NO_IMPL)
        {
            printk("WARNING: OnExit of current state has no implementation\n");
        }
        State_t *next = &stateMachine->states[targetState];
        printk("Going to target state %d\n", next->id);
        stateMachine->current = next;
        ret = next->onEntry();

        if ((ret == ERR_NONE || ret == ERR_NO_IMPL) && g_state_notifier != NULL)
        {
            if (stateMachine->notify)
            {
                g_state_notifier(stateMachine->current->id);
            }
        }
    }
    return ret;
}


void state_machine_register_notifier(StateNotifier notifier)
{
    if (notifier != NULL)
    {
        g_state_notifier = notifier;
    }
}
