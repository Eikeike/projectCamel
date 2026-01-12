#ifndef STATEMACHINE_H
#define STATEMACHINE_H

#include <stdint.h>
#include <zephyr/kernel.h>

#define MAX_TRANSITIONS 5

#define ERR_NONE                    0
#define ERR_API                     1
#define ERR_INVALID_PARAM           5
#define ERR_TRANSITION_FORBIDDEN    10
#define ERR_NO_IMPL                 69


typedef enum {
    STATE_IDLE,
    STATE_READY,
    STATE_RUNNING,
    STATE_SENDING,
    STATE_CALIBRATING,
    STATE_ERROR,
    STATE_MAX
} StateID_t;

#define NUM_STATES STATE_MAX

typedef uint8_t (*StateFunc_t)(void);

typedef struct {
    StateID_t id;
    StateFunc_t onEntry;
    StateFunc_t runLoop;
    StateFunc_t onExit;
    StateID_t allowedTransitions[MAX_TRANSITIONS];
} State_t;


uint8_t IdleEntry(void);
uint8_t IdleRun(void);
uint8_t IdleExit(void);

uint8_t ReadyEntry(void);
uint8_t ReadyRun(void);
uint8_t ReadyExit(void);

uint8_t RunningEntry(void);
uint8_t RunningRun(void);
uint8_t RunningExit(void);

uint8_t SendingEntry(void);
uint8_t SendingRun(void);
uint8_t SendingExit(void);

uint8_t CalibEntry(void);
uint8_t CalibRun(void);
uint8_t CalibExit(void);

uint8_t ErrorEntry(void);
uint8_t ErrorRun(void);
uint8_t ErrorExit(void);


extern const State_t STATES[NUM_STATES + 1];


typedef struct {
    const State_t *current;
    StateID_t requestStateDeferred;
    int error;
    struct k_mutex lock;
    uint16_t period_ms;
} StateMachine_t;


uint8_t state_machine_transition(StateMachine_t *stateMachine, StateID_t targetState);

typedef void (*StateNotifier)(StateID_t);
void state_machine_register_notifier(StateNotifier notifier);

#endif //STATEMACHINE_H