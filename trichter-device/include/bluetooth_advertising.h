#ifndef BLUETOOTH_ADVERTISING_H
#define BLUETOOTH_ADVERTISING_H

#include <stdint.h>
#include "state_machine.h"

typedef enum {
    BLE_ADV_OFF = 0,
    BLE_ADV_FAST,
    BLE_ADV_SLOW,
    BLE_ADV_STATE_MAX
} ble_adv_state_t;

/*PUBLIC API*/

void bluetooth_advertising_fsm_start(void);

void bluetooth_advertising_start_fast(void);
void bluetooth_advertising_start_slow(void);
void bluetooth_advertising_stop(void);

bool bluetooth_advertising_is_active(void);

#endif /* BLUETOOTH_ADVERTISING_H */
