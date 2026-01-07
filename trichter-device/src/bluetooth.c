#include <stdint.h>
#include <zephyr/kernel.h>
#include <zephyr/kernel_structs.h>
#include <zephyr/sys/printk.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/conn.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/bluetooth/uuid.h>
#include <zephyr/drivers/flash.h>
#include <zephyr/storage/flash_map.h>
#include <zephyr/settings/settings.h>
#include "bluetooth.h"
#include "memory.h"

#define MAX_TIMESTAMPS          300
#define CHUNK_SIZE              10
#define MAX_INDICATION_RETRIES  3
#define INDICATION_TIMEOUT_MS   5000
#define MAX_SDU_SIZE_BYTE       243 //247 MTU - 4 byte header
#define COUNT_BYTES(num)        (num * sizeof(uint32_t))

static bool g_is_advertising = false;
static bool g_is_connected = false;
static bool g_restart_adv = false;

static uint8_t g_timer_tick_duration = 0;

static uint8_t indication_retry_count = 0;
static struct bt_gatt_indicate_params last_ind_params;

K_SEM_DEFINE(indication_sem, 0, 1);
K_THREAD_STACK_DEFINE(retry_work_stack, 512);

struct k_work_q retry_work;
struct k_work work;


enum transmission_flags {
    TX_FLAG_START = 0xAA,
    TX_FLAG_DATA = 0xBB,
    TX_FLAG_END = 0xCC
};

static struct nvs_fs fs_ble;

#define NVS_PARTITION_BLE			storage_partition_ble
#define NVS_PARTITION_DEVICE_BLE	FIXED_PARTITION_DEVICE(NVS_PARTITION_BLE)
#define NVS_PARTITION_OFFSET_BLE	FIXED_PARTITION_OFFSET(NVS_PARTITION_BLE)
#define NVS_PARTITION_SIZE_BLE      FIXED_PARTITION_SIZE(NVS_PARTITION_BLE)

//Header
#pragma pack(push, 1)
struct  ble_packet_header {
    uint8_t flag;           // Packet type flag
    uint16_t chunk_index;   // Current chunk number
    uint8_t data_size_bytes;     // Size of one chunk in byte (= Number of timestamps * 4)
};

//Data Package buffer
struct ble_transmission_packet {
    struct ble_packet_header header;
    uint32_t *data_buff;        // Pointing to a location within bulk_data_service.timestamps
};

#pragma pack(pop)

//Datastructure for Characteristic holding the data
struct bulk_data_service {
    uint8_t timestamp_bytes[COUNT_BYTES(MAX_TIMESTAMPS)];
    uint16_t count;        // Number of valid timestamps
    uint16_t idx_to_send;   // Index of next timestamp to send
    bool transmission_active;
    struct bt_conn *current_conn;
    uint16_t sdu_size;
};

//Actual Characteristic holding the data
static struct bulk_data_service g_bulk_service = {
    .count = 0,
    .idx_to_send = 0,
    .transmission_active = false,
    .current_conn = NULL,
    .sdu_size = 16 //23 = default MTU, minus header size (4byte) yields 19byte --> 16 is next one div by 4
};

static struct bt_gatt_indicate_params ind_params;
static uint8_t tx_buffer[sizeof(struct ble_packet_header) + MAX_SDU_SIZE_BYTE];

/* Custom 128-bit UUIDs */
#define BT_UUID_CUSTOM_SERVICE_VAL \
    BT_UUID_128_ENCODE(0xaf56d6dd, 0x3c39, 0x4d67, 0x9bbe, 0x4fb04fa327cc)

/*Custom 128-bit UUIDs for Characeristics*/

#define BT_UUID_ARRAY_CHARACTERISTIC_VAL \
    BT_UUID_128_ENCODE( 0xf9d76937, 0xbd70, 0x4e4f, 0xa4da, 0x0b718d5f5b6d)

#define BT_UUID_CALIB_CHAR_VAL \
    BT_UUID_128_ENCODE(0x23de2cad, 0x0fc8, 0x49f4, 0xbbcc, 0x5eb2c9fdb91b)


static struct bt_uuid_128 custom_service_uuid = BT_UUID_INIT_128(BT_UUID_CUSTOM_SERVICE_VAL);
static struct bt_uuid_128 drinking_char_uuid = BT_UUID_INIT_128(BT_UUID_ARRAY_CHARACTERISTIC_VAL);
static struct bt_uuid_128 time_constant_char_uuid = BT_UUID_INIT_128(BT_UUID_CALIB_CHAR_VAL);

static void indication_retry_handler(struct k_work *work)
{
    printk("Retrying :(\n");
    int err = bt_gatt_indicate(g_bulk_service.current_conn, &last_ind_params);
    if (err) {
        printk("Retry failed to start: %d\n", err);
    }
}

/* Read/Write callbacks */
static ssize_t read_custom(struct bt_conn *conn,
                           const struct bt_gatt_attr *attr,
                           void *buf, uint16_t len, uint16_t offset)
{
    const char *value = attr->user_data;
    return bt_gatt_attr_read(conn, attr, buf, len, offset, value, strlen(value));
}


void mtu_updated(struct bt_conn *conn, uint16_t tx, uint16_t rx)
{
	printk("Updated MTU: TX: %d RX: %d bytes\n", tx, rx);
    g_bulk_service.sdu_size = MIN(tx, rx) - sizeof(struct ble_packet_header) - 3;
}


static struct bt_gatt_cb gatt_callbacks = {
	.att_mtu_updated = mtu_updated
};


static ssize_t read_time_constant(struct bt_conn *conn,
                                const struct bt_gatt_attr *attr,
                                void *buf, uint16_t len, uint16_t offset)
{
    return bt_gatt_attr_read(conn, attr, buf, len, offset,
                             &g_timer_tick_duration, sizeof(g_timer_tick_duration));
}


/* Define custom service */
BT_GATT_SERVICE_DEFINE(custom_svc,
    BT_GATT_PRIMARY_SERVICE(&custom_service_uuid),
    /* Drinking Speed Characteristic */
    BT_GATT_CHARACTERISTIC(&drinking_char_uuid.uuid,
                           BT_GATT_CHRC_INDICATE,
                           BT_GATT_PERM_NONE ,
                           NULL, NULL, NULL),
    BT_GATT_CCC(NULL, BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),

    /* Time Calibration characteristic */
    BT_GATT_CHARACTERISTIC(&time_constant_char_uuid.uuid,
        BT_GATT_CHRC_READ | BT_GATT_CHRC_NOTIFY,
        BT_GATT_PERM_READ,
        read_time_constant, NULL, NULL),
    BT_GATT_DESCRIPTOR(&drinking_char_uuid.uuid,
                       BT_GATT_PERM_READ,
                       read_custom, NULL,
                       "Drinking Speed Service"),
    BT_GATT_CCC(NULL, BT_GATT_PERM_READ | BT_GATT_PERM_WRITE)
    // Ready Signal einfügen
    // Start Signal
);


/* Advertising data */
static const struct bt_data ad[] = {
    BT_DATA_BYTES(BT_DATA_FLAGS, (BT_LE_AD_GENERAL | BT_LE_AD_NO_BREDR)),
    BT_DATA(BT_DATA_NAME_COMPLETE,
            CONFIG_BT_DEVICE_NAME,

            strlen(CONFIG_BT_DEVICE_NAME))
};

static const struct bt_data sd[] = {
BT_DATA_BYTES(BT_DATA_UUID128_ALL, BT_UUID_CUSTOM_SERVICE_VAL)
};
 
/* Connection callbacks */
static void connected(struct bt_conn *conn, uint8_t err)
{
    if (!err) printk("Connected\n");
    if (g_is_connected) {
        bt_conn_disconnect(conn, BT_HCI_ERR_CONN_LIMIT_EXCEEDED);
        return;
    }
    ble_stop_adv();
    g_restart_adv = false;
    g_is_connected = 1;
    g_bulk_service.current_conn = bt_conn_ref(conn);
}


void ble_delete_active_connection()
{
    if (g_bulk_service.current_conn && g_is_connected) {
        bt_conn_disconnect(g_bulk_service.current_conn, BT_HCI_ERR_REMOTE_USER_TERM_CONN);
    }
}


static void disconnected(struct bt_conn *conn, uint8_t reason)
{
    printk("Disconnected (reason 0x%02x)\n", reason);
    g_is_connected = 0;
    bt_conn_unref(g_bulk_service.current_conn);
    g_restart_adv = true;
}


static void recycled()
{
    printk("Recycled; %s starting advertising", g_restart_adv ? "" : "NOT");
    if (g_restart_adv)
    {
        ble_start_adv();
        g_restart_adv = true;
    }
}


BT_CONN_CB_DEFINE(conn_callbacks) = {
    .connected = connected,
    .disconnected = disconnected,
    .recycled = recycled
};


void ble_start_adv()
{
    int err = 0;
    g_is_connected = 0;
    printk("Advertising started");
    if (!g_is_advertising)
    {
        err = bt_le_adv_start(BT_LE_ADV_CONN_FAST_1, ad, ARRAY_SIZE(ad), sd, ARRAY_SIZE(sd));
        if (err) {
            printk("Bluetooth advertising start failed (err %d)\n", err);
            return;
        }
    }
    g_is_advertising = 1;
}


void ble_stop_adv()
{
    int ret = 1;
    if (g_is_advertising)
    {
        ret = bt_le_adv_stop();
        if (ret != 0)
        {
            printk("Advertising could not be stopped");
        } else {
            printk("Advertising stopped successfully");
        }
        g_is_advertising = 0;
    }
}


int init_ble(uint8_t timer_tick_duration)
{
    int err;
    k_work_queue_init(&retry_work);
    k_work_queue_start(&retry_work, retry_work_stack, K_THREAD_STACK_SIZEOF(retry_work_stack), 4, NULL);
    k_work_init(&work, indication_retry_handler);

    err = initialize_and_mount_fs(&fs_ble, NVS_PARTITION_DEVICE_BLE, NVS_PARTITION_OFFSET_BLE, NVS_PARTITION_SIZE_BLE);
	if (err)
	{
		return 0;
	}

    err = bt_enable(NULL);
    if (IS_ENABLED(CONFIG_SETTINGS)) {
        settings_load();
    }
    bt_gatt_cb_register(&gatt_callbacks);

    g_timer_tick_duration = timer_tick_duration;

    return err;
}


bool is_ble_connected()
{
    return g_is_connected;
};


static void indicate_cb(struct bt_conn *conn,
                       struct bt_gatt_indicate_params *params,
                       uint8_t err)
{
    if (err != 0U && indication_retry_count < MAX_INDICATION_RETRIES) {
        printk("Indication failed, retry %d/3\n", indication_retry_count + 1);
        indication_retry_count++;
        
        // Copy parameters for retry
        memcpy(&last_ind_params, params, sizeof(struct bt_gatt_indicate_params));
        
        // Retry after a small delay
        k_work_submit_to_queue(&retry_work, &work);
    } else {
        if (err == 0U) {
            printk("Indication success\n");
            indication_retry_count = 0;
            // Signal success to allow next packet
            k_sem_give(&indication_sem);
        } else {
            printk("Indication failed after %d retries\n", MAX_INDICATION_RETRIES);
        }
    }
}


int ble_send_start()
{
    if (g_bulk_service.transmission_active != 1)
    {
        return 1;
    }
    struct ble_packet_header header = {
        .flag = TX_FLAG_START,
        .chunk_index = 0,
        .data_size_bytes = g_bulk_service.sdu_size
    };

    int err;
    static uint16_t ram_copy_counter = 0;
    err = read_counter_from_rom(&ram_copy_counter);

    memcpy(tx_buffer, &header, sizeof(header));
    memcpy(tx_buffer + sizeof(header), &g_bulk_service.count, sizeof(g_bulk_service.count));
    memcpy(tx_buffer + sizeof(header) + sizeof(g_bulk_service.count), &ram_copy_counter, sizeof(ram_copy_counter));

    ind_params.attr = &custom_svc.attrs[2];
    ind_params.func = indicate_cb;
    ind_params.data = tx_buffer;
    ind_params.len = sizeof(header) + sizeof(g_bulk_service.count) + sizeof(ram_copy_counter);

    k_sem_reset(&indication_sem);

    err = bt_gatt_indicate(g_bulk_service.current_conn, &ind_params);
    if (err)
    {
        printk("Failed to indicate in send start");
    }
    return err;
}


bool ble_is_sending()
{
    return g_bulk_service.transmission_active;
}

bool ble_is_adv()
{
    return g_is_advertising;
}


int ble_prepare_send(uint32_t *data_buffer, const uint32_t num_elements)
{
    if (data_buffer == NULL)
    {
        return 1;
    } else if (num_elements == 0 || num_elements > MAX_TIMESTAMPS)
    {
        return 1;
    };
    //copy buffer to local
    const uint8_t *bytes = (const uint8_t *)data_buffer;
    memcpy(g_bulk_service.timestamp_bytes, bytes, COUNT_BYTES(num_elements));
    printk("Sending Data:\n");
    for (int i = 0; i < COUNT_BYTES(num_elements); i++)
    {
        printk("%02X-", bytes[i]);
        k_msleep(5);
    }
    printk("\n");
    g_bulk_service.count = num_elements;
    g_bulk_service.transmission_active = 1;
    g_bulk_service.idx_to_send = 0;
    return 0;
}



int ble_send_chunk()
{
    printk("Sending chunk");
    if (k_sem_take(&indication_sem, K_MSEC(INDICATION_TIMEOUT_MS)) != 0) {
        printk("Previous indication timeout\n");
        return -ETIMEDOUT;
    }
    if (g_bulk_service.transmission_active != 1)
    {
        return 1;
    }

    int err;

    struct ble_packet_header header;
    const uint16_t next_byte_idx = g_bulk_service.idx_to_send;
    uint16_t tx_length = 0;
    if (next_byte_idx < COUNT_BYTES(g_bulk_service.count))
    {
        header.flag = TX_FLAG_DATA;
        header.chunk_index = next_byte_idx / g_bulk_service.sdu_size; //intentional integer division
        header.data_size_bytes = MIN(g_bulk_service.sdu_size, (COUNT_BYTES(g_bulk_service.count) - g_bulk_service.idx_to_send));
        printk("sending index %d with next idx = %d, header size = %d and data size = %d\n", header.chunk_index, next_byte_idx, sizeof(header), header.data_size_bytes);
       tx_length = sizeof(header) + header.data_size_bytes;

        if (header.data_size_bytes <= (sizeof(tx_buffer)/sizeof(tx_buffer[0])))
        {
            memcpy(tx_buffer, &header, sizeof(header));
            memcpy(tx_buffer + sizeof(header), &g_bulk_service.timestamp_bytes[next_byte_idx], header.data_size_bytes);
        }

    } else {
        header.flag = TX_FLAG_END;
        header.chunk_index = 0;
        header.data_size_bytes = 0;
        tx_length = sizeof(header);
        memcpy(tx_buffer, &header, sizeof(header));
        g_bulk_service.transmission_active = 0;
    }
    

    ind_params.attr = &custom_svc.attrs[2];
    ind_params.func = indicate_cb;
    ind_params.data = tx_buffer;
    ind_params.len = tx_length;


    err = bt_gatt_indicate(g_bulk_service.current_conn, &ind_params);
    if (err)
    {
        k_sem_give(&indication_sem);
        printk("Failed to indicate in send_chunk for chunk %d", next_byte_idx);
        return err;
    }
    g_bulk_service.idx_to_send += g_bulk_service.sdu_size;

    return err;
}
