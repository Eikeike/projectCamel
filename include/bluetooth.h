#ifndef TRICHTER_BLUETOOTH_H
#define TRICHTER_BLUETOOTH_H
#include <stdbool.h>
#include <stdint.h>

int init_ble();
void ble_start_adv();
void ble_stop_adv();

int ble_send_start();
bool is_ble_connected();
int ble_send_chunk();
int ble_prepare_send(uint32_t *data_buffer, const uint32_t num_elements);
bool ble_is_sending();


#endif //TRICHTER_BLUETOOTH_H