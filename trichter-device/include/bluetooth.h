#ifndef TRICHTER_BLUETOOTH_H
#define TRICHTER_BLUETOOTH_H
#include <stdbool.h>
#include <stdint.h>
#include "state_machine.h"


int init_ble(uint8_t timer_tick_duration);
void ble_start_adv(bool adv_slow);
#define BLE_ADV_FAST false
#define BLE_ADV_SLOW true 
void ble_stop_adv();

int ble_send_start();
bool is_ble_connected();
int ble_send_chunk();
int ble_prepare_send(uint32_t *data_buffer, const uint32_t num_elements);
bool ble_is_sending();
bool ble_is_adv();
void delete_all_connections();

typedef enum RemoteState {
    REMOTE_STATE_CMD_IDLE,
    REMOTE_STATE_CMD_READY,
    REMOTE_STATE_CMD_CALIB,
    REMOTE_STATE_CMD_MAX
} RemoteState;

typedef void (*RemoteStateInputHandler)(RemoteState);
void ble_register_state_input_handler(RemoteStateInputHandler handler);
void ble_state_notifier(StateID_t state);
void ble_calibration_attempt_notifier(bool success);

#endif //TRICHTER_BLUETOOTH_H