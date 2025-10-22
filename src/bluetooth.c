#include <zephyr/kernel.h>
#include <zephyr/kernel_structs.h>
#include <zephyr/sys/printk.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/conn.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/bluetooth/uuid.h>
#include "bluetooth.h"

#define MAX_TIMESTAMPS          300
#define CHUNK_SIZE              10
#define MAX_INDICATION_RETRIES  3
#define INDICATION_TIMEOUT_MS   5000
#define MAX_SDU_SIZE_BYTE       243 //247 MTU - 4 byte header            

static bool g_is_advertising = 1;
static bool g_is_connected = 0;

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

//Header
struct ble_packet_header {
    uint8_t flag;           // Packet type flag
    uint16_t chunk_index;   // Current chunk number
    uint8_t data_size_bytes;     // Size of one chunk in byte (= Number of timestamps * 4)
} __packed;

//Data Package buffer
struct ble_transmission_packet {
    struct ble_packet_header header;
    uint32_t *data_buff;        // Pointing to a location within bulk_data_service.timestamps
} __packed;

//Datastructure for Characteristic holding the data
struct bulk_data_service {
    uint32_t timestamps[MAX_TIMESTAMPS];
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

/* Custom 128-bit UUIDs */
#define BT_UUID_CUSTOM_SERVICE_VAL \
    BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef0)

#define BT_UUID_CUSTOM_CHAR_VAL \
    BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef1)


static struct bt_uuid_128 custom_service_uuid = BT_UUID_INIT_128(BT_UUID_CUSTOM_SERVICE_VAL);
static struct bt_uuid_128 custom_char_uuid = BT_UUID_INIT_128(BT_UUID_CUSTOM_CHAR_VAL);

static uint8_t custom_value[] = "Hello BLE";

static struct bt_gatt_indicate_params ind_params;

static void indication_retry_handler(struct k_work *work)
{
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


static ssize_t write_custom(struct bt_conn *conn,
                            const struct bt_gatt_attr *attr,
                            const void *buf, uint16_t len, uint16_t offset,
                            uint8_t flags)
{
    uint8_t *value = attr->user_data;
    memcpy(value, buf, MIN(len, sizeof(custom_value) - 1));
    value[len] = '\0';
    printk("Wrote: %s\n", value);
    return len;
}


void mtu_updated(struct bt_conn *conn, uint16_t tx, uint16_t rx)
{
	printk("Updated MTU: TX: %d RX: %d bytes\n", tx, rx);
    //minimum of tx and rx, but make it divisible by size of uint32 (4, most likely)
    uint16_t tx_sdu = tx - (tx % sizeof(g_bulk_service.timestamps[0]));
    uint16_t rx_sdu = tx - (tx % sizeof(g_bulk_service.timestamps[0]));
    g_bulk_service.sdu_size = MIN(tx_sdu, rx_sdu) - 4; //4 = header size
}


static struct bt_gatt_cb gatt_callbacks = {
	.att_mtu_updated = mtu_updated
};


/* Define custom service */
BT_GATT_SERVICE_DEFINE(custom_svc,
    BT_GATT_PRIMARY_SERVICE(&custom_service_uuid),
    BT_GATT_CHARACTERISTIC(&custom_char_uuid.uuid,
                           BT_GATT_CHRC_READ | BT_GATT_CHRC_WRITE | BT_GATT_CHRC_INDICATE,
                           BT_GATT_PERM_READ | BT_GATT_PERM_WRITE,
                           read_custom, write_custom, custom_value),
    BT_GATT_DESCRIPTOR(&custom_char_uuid.uuid,
                       BT_GATT_PERM_READ,
                       bt_gatt_attr_read, NULL,
                       "Drinking Speed Service"),
    BT_GATT_CCC(NULL, BT_GATT_PERM_READ | BT_GATT_PERM_WRITE)
);


/* Advertising data */
static const struct bt_data ad[] = {
    BT_DATA_BYTES(BT_DATA_FLAGS, (BT_LE_AD_GENERAL | BT_LE_AD_NO_BREDR)),
    BT_DATA_BYTES(BT_DATA_UUID128_ALL, BT_UUID_CUSTOM_SERVICE_VAL),
};

static const struct bt_data sd[] = {
	BT_DATA(BT_DATA_NAME_COMPLETE, CONFIG_BT_DEVICE_NAME, sizeof(CONFIG_BT_DEVICE_NAME) - 1),
};

/* Connection callbacks */
static void connected(struct bt_conn *conn, uint8_t err)
{
    if (!err) printk("Connected\n");
    ble_stop_adv();
    g_is_connected = 1;
    g_bulk_service.current_conn = conn;
}

static void disconnected(struct bt_conn *conn, uint8_t reason)
{
    printk("Disconnected (reason 0x%02x)\n", reason);
    ble_start_adv();
    g_is_connected = 0;
}

BT_CONN_CB_DEFINE(conn_callbacks) = {
    .connected = connected,
    .disconnected = disconnected,
};


void ble_start_adv()
{

    int err = 0;
    g_is_connected = 0;
    printk("Advertising started");
    err = bt_le_adv_start(BT_LE_ADV_CONN_FAST_1, ad, ARRAY_SIZE(ad), sd, ARRAY_SIZE(sd));
    if (err) {
        printk("Bluetooth init failed (err %d)\n", err);
        return;
    }
    g_is_advertising = 1;
    printk("Bluetooth initialized\n");
    bt_gatt_cb_register(&gatt_callbacks);
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

int init_ble()
{
    k_work_queue_init(&retry_work);
    k_work_queue_start(&retry_work, retry_work_stack, K_THREAD_STACK_SIZEOF(retry_work_stack), 4, NULL);
    k_work_init(&work, indication_retry_handler);

    int err = bt_enable(NULL);
    if (IS_ENABLED(CONFIG_SETTINGS)) {
        settings_load();
    }
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
            // Handle complete failure - could transition state machine to error
        }
    }
}

struct ble_packet_header header;
static uint8_t tx_buffer[sizeof(struct ble_packet_header) + MAX_SDU_SIZE_BYTE];

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

    memcpy(tx_buffer, &header, sizeof(header));
    memcpy(tx_buffer + sizeof(header), &g_bulk_service.count, sizeof(g_bulk_service.count));

    ind_params.attr = &custom_svc.attrs[1];  // Your characteristic
    ind_params.func = indicate_cb;
    ind_params.data = tx_buffer;
    ind_params.len = sizeof(header) + sizeof(g_bulk_service.count);

    k_sem_reset(&indication_sem);

    int err = bt_gatt_indicate(g_bulk_service.current_conn, &ind_params);
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
    size_t total_bytes = num_elements * sizeof(uint32_t);
    for (int i = 0; i < num_elements; i++)
    {
        g_bulk_service.timestamps[i] = data_buffer[i];
    }
    for (int i = 0; i < total_bytes; i++)
    {
        printk("%02X", bytes[i]);
    }
    printk("\n");
    g_bulk_service.count = num_elements;
    g_bulk_service.transmission_active = 1;
    g_bulk_service.idx_to_send = 0;
    return 0;
}



int ble_send_chunk()
{
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
    struct ble_transmission_packet pack;
    const uint16_t next_idx = g_bulk_service.idx_to_send;
    uint16_t data_length = 0;
    if (next_idx < g_bulk_service.count)
    {
        header.flag = TX_FLAG_DATA;
        header.chunk_index = next_idx / g_bulk_service.sdu_size; //intentional integer division
        header.data_size_bytes = MIN(g_bulk_service.sdu_size, (MAX_TIMESTAMPS - g_bulk_service.idx_to_send) * sizeof(g_bulk_service.timestamps[0]));

        pack.data_buff = &g_bulk_service.timestamps[next_idx];
        data_length = sizeof(header) + header.data_size_bytes;

        if (header.data_size_bytes <= (sizeof(tx_buffer)/sizeof(tx_buffer[0])))
        {
            memcpy(tx_buffer, &header, sizeof(header));
            memcpy(tx_buffer + sizeof(header), &g_bulk_service.timestamps[next_idx], header.data_size_bytes);
        }

    } else {
        header.flag = TX_FLAG_END;
        header.chunk_index = 0;
        header.data_size_bytes = 0;
        data_length = sizeof(header);
        memcpy(tx_buffer, &header, sizeof(header));
        g_bulk_service.transmission_active = 0;
    }
    

    ind_params.attr = &custom_svc.attrs[1];  // Your characteristic
    ind_params.func = indicate_cb;
    ind_params.data = tx_buffer;
    ind_params.len = data_length;


    err = bt_gatt_indicate(g_bulk_service.current_conn, &ind_params);
    if (err)
    {
        k_sem_give(&indication_sem);
        printk("Failed to indicate in send_chunk for chunk %d", next_idx);
        return err;
    }
    g_bulk_service.idx_to_send += g_bulk_service.sdu_size;

    return err;
}
