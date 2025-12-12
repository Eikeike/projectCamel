#include <zephyr/drivers/flash.h>
#include <zephyr/storage/flash_map.h>
#include <zephyr/fs/nvs.h>
#include "memory.h"


static struct nvs_fs fs;

#define NVS_PARTITION_APP			storage_partition_app
#define NVS_PARTITION_DEVICE_APP	FIXED_PARTITION_DEVICE(NVS_PARTITION_APP)
#define NVS_PARTITION_OFFSET_APP	FIXED_PARTITION_OFFSET(NVS_PARTITION_APP)
#define NVS_PARTITION_SIZE_APP		FIXED_PARTITION_SIZE(NVS_PARTITION_APP)

uint32_t global_calibration_value;

int initialize_and_mount_fs(struct nvs_fs *filesys, const struct device *device, const off_t offset, const uint16_t partition_size)
{
	int err = 0;
    int retVal = 0;
    struct flash_pages_info info;

    filesys->flash_device = device;
    if (!device_is_ready(filesys->flash_device)) {
        printk("Flash device %s is not ready\n", filesys->flash_device->name);
        return 1;
	}
	filesys->offset = offset;
	printk("%s: Offset = 0x%08x, partition size = %d\n", filesys->flash_device->name, offset, partition_size);
	err = flash_get_page_info_by_offs(filesys->flash_device, filesys->offset, &info);
	if (err) {
		printk("Unable to get page info, rc=%d\n", err);
		return 1;
	}
	filesys->sector_size = info.size;
	filesys->sector_count =  (uint16_t)(partition_size / filesys->sector_size);
	printk("Flash device %s is ready and will be mounted now with sector_size = %d and sector_count = %d\n", filesys->flash_device->name, filesys->sector_size, filesys->sector_count);
	err = nvs_mount(filesys);
	if (err) {
		printk("Flash Init failed, rc=%d\n", err);
		return 1;
	}
	return 0;
}


int init_memory_nv()
{
	int err;
	err = initialize_and_mount_fs(&fs, NVS_PARTITION_DEVICE_APP, NVS_PARTITION_OFFSET_APP, NVS_PARTITION_SIZE_APP);
	if (err)
	{
		return 0;
	}

    err = nvs_read(&fs, CALIBRATION_VALUE_ID, &global_calibration_value, sizeof(global_calibration_value));
	if (err > 0)
    { 
		printk("Found NV Data with Id: %d, Value: %d\n", CALIBRATION_VALUE_ID, global_calibration_value);
	} else {/* item was not found, add it */
		printk("No value found for NV ID %d\n, defaulting to 300", CALIBRATION_VALUE_ID);
        global_calibration_value = 300;
        return 0;
	}
    return 1;
}


void save_counter_ram_to_rom()
{
    nvs_write(&fs, CALIBRATION_VALUE_ID, &global_calibration_value, sizeof(global_calibration_value));
}
