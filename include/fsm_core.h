#ifndef FSM_CORE_H
#define FSM_CORE_H 

#include <stdint.h>
#include "state_machine.h"

extern StateMachine_t g_stateMachine;

void fsm_init();
void fsm_main(void *p1, void *p2, void *p3);
uint8_t fsm_transition(StateID_t targetState);
uint8_t fsm_transition_deferred(StateID_t state);

#endif //FSM_CORE_H