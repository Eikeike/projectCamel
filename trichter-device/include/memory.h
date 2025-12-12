#ifndef APPL_MEMORY_H
#define APPL_MEMORY_H

#include <stdint.h>
#include <zephyr/fs/nvs.h>

/*MEMORY ID DEFINITIONS*/
#define CALIBRATION_VALUE_ID    1


/*MEMORY GLOBAL RAM DATA DEFINITIONS*/
extern uint32_t global_calibration_value;
void save_counter_ram_to_rom();
int init_memory_nv();
int initialize_and_mount_fs(struct nvs_fs *filesys, const struct device *device, const off_t offset, const uint16_t partition_size);

#endif //APPL_MEMORY_H