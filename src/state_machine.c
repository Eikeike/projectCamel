
#include <stdint.h>
#include "state_machine.h"

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
        .allowedTransitions = {STATE_RUNNING, STATE_IDLE, STATE_MAX, STATE_MAX, STATE_MAX}
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
    [STATE_ERROR] = {
        .id = STATE_ERROR,
        .onEntry = ErrorEntry,
        .runLoop = ErrorRun,
        .onExit = ErrorExit,
        .allowedTransitions = {STATE_ERROR, STATE_MAX, STATE_MAX, STATE_MAX, STATE_MAX}
    }
};


static uint8_t is_transition_allowed(const State_t *currState, StateID_t targetState)
{
    //Error checks
    if (targetState > NUM_STATES || currState->allowedTransitions == NULL)
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
    
    if (!stateMachine || !stateMachine->current || targetState > NUM_STATES)
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
        if (ret != ERR_NONE && ret != ERR_NO_IMPL)
        {
            return ret;
        }
        if (ret == ERR_NO_IMPL)
        {
            printk("WARNING: OnExit of current state has no implementation\n");
        }
        State_t *next = &STATES[targetState];
        printk("Going to target state %d\n", next->id);
        stateMachine->current = next;
        ret = next->onEntry();
    }
    return ret;
}

