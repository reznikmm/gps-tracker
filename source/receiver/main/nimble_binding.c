#include "nvs_flash.h"
#include "esp_nimble_hci.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/util/util.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

#define MAX_CHARS 10
#define MAX_SVCS 4

static ble_uuid16_t v_uids[MAX_CHARS + MAX_SVCS];
static struct ble_gatt_chr_def v_chr_def[MAX_CHARS];
static uint16_t v_chr_handle[MAX_CHARS];  //  indexed by characteristic_index
static bool v_notify_state[MAX_CHARS];  //  indexed by characteristic_index
static int v_last_handle = 0;
static int v_next_chr = 0;

static struct ble_gatt_svc_def v_svc_def[MAX_SVCS];
static int v_next_svc = 0;

static uint8_t own_addr_type;

static uint16_t conn_handle;

static int
blehr_gap_event(struct ble_gap_event *event, void *arg)
{
    void (*callback)(int) = (void (*)(int))(arg);
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        /* A new connection was established or a connection attempt failed */
        MODLOG_DFLT(INFO, "connection %s; status=%d conn_handle=%d\n",
                    event->connect.status == 0 ? "established" : "failed",
                    event->connect.status,
                    event->connect.conn_handle);

        if (event->connect.status != 0) {
            /* Connection failed; resume advertising */
            (*callback)(0);
        }
        conn_handle = event->connect.conn_handle;
        break;

    case BLE_GAP_EVENT_DISCONNECT:
        MODLOG_DFLT(INFO, "disconnect; reason=%d\n", event->disconnect.reason);

        /* Connection terminated; resume advertising */
        (*callback)(0);

        break;

    case BLE_GAP_EVENT_ADV_COMPLETE:
        MODLOG_DFLT(INFO, "adv complete\n");
        (*callback)(0);
        break;

    case BLE_GAP_EVENT_SUBSCRIBE:
        MODLOG_DFLT(INFO, "subscribe event; cur_notify=%d\n value handle; "
                    "val_handle=%d\n",
                    event->subscribe.cur_notify, event->subscribe.attr_handle);
        for (int index = 0; index <= v_last_handle; index++){
            if(v_chr_handle[index] == event->subscribe.attr_handle){
                v_notify_state[index] = event->subscribe.cur_notify;
                break;
            }
        }
        ESP_LOGI("BLE_GAP_SUBSCRIBE_EVENT", "conn_handle from subscribe=%d", event->subscribe.conn_handle);
        break;

    case BLE_GAP_EVENT_MTU:
        MODLOG_DFLT(INFO, "mtu update event; conn_handle=%d mtu=%d\n",
                    event->mtu.conn_handle,
                    event->mtu.value);
        break;

    }

    return 0;
}

void ble_notify_chr_change (int p_index, const uint8_t *data, int data_len)
{
    struct os_mbuf *om;
    if (v_notify_state[p_index]){
        om = ble_hs_mbuf_from_flat(data, data_len);
        ble_gattc_notify_custom(conn_handle, v_chr_handle[p_index], om);
    }
}

int chr_callback (uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    void (*callback)(int code,int index, uint8_t *buffer, int *size) =
      (void (*)(int,int, uint8_t*, int*))(arg);
    int index, rc, size;
    uint8_t buffer[32];
    MODLOG_DFLT(INFO, "chr_callback attr=%x\n", attr_handle);
    for (index = 0; index <= v_last_handle; index++){
        if(v_chr_handle[index] == attr_handle){
            callback (0, index, buffer, &size);
            rc = os_mbuf_append(ctxt->om, buffer, size);

            return rc == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
        }
    }
    return 0;
}

void add_svc_def(int p_uid)
{
    if (v_next_svc != 0){
        v_chr_def[v_next_chr++].uuid = NULL;
    }

    v_uids[MAX_CHARS + v_next_svc] = (ble_uuid16_t)BLE_UUID16_INIT(p_uid);
    v_svc_def[v_next_svc].type = BLE_GATT_SVC_TYPE_PRIMARY;
    v_svc_def[v_next_svc].uuid = (ble_uuid_t *)&v_uids[MAX_CHARS + v_next_svc];
    v_svc_def[v_next_svc].includes = NULL;
    v_svc_def[v_next_svc].characteristics = &v_chr_def[v_next_chr];
    v_next_svc++;
}

void add_chr_def(int p_index, int p_uid, unsigned flags, void *callback)
{
    v_uids[v_next_chr] = (ble_uuid16_t)BLE_UUID16_INIT(p_uid);
    v_chr_def[v_next_chr].uuid = (ble_uuid_t *)&v_uids[v_next_chr];
    v_chr_def[v_next_chr].access_cb = chr_callback;
    v_chr_def[v_next_chr].arg = callback;
    v_chr_def[v_next_chr].descriptors = NULL;
    v_chr_def[v_next_chr].flags = 0
      + (flags & 1 ? BLE_GATT_CHR_F_READ : 0)
      + (flags & 2 ? BLE_GATT_CHR_F_WRITE : 0)
      + (flags & 4 ? BLE_GATT_CHR_F_NOTIFY : 0);
    v_chr_def[v_next_chr].min_key_size = 0;
    v_chr_def[v_next_chr].val_handle = &v_chr_handle[p_index];
    v_notify_state[p_index] = 0;
    v_last_handle = (v_last_handle > p_index) ? v_last_handle : p_index;
    v_next_chr++;
}

void complete_svc_def()
{
    int rc;
    
    v_svc_def[v_next_svc].uuid = NULL;
    v_chr_def[v_next_chr].uuid = NULL;
    
    ble_svc_gap_init();
    ble_svc_gatt_init();

    rc = ble_gatts_count_cfg(v_svc_def);
    ESP_ERROR_CHECK(rc);
    rc = ble_gatts_add_svcs(v_svc_def);
    ESP_ERROR_CHECK(rc);
}

void ble_app_set_addr(void)
{
    int rc;

    rc = ble_hs_util_ensure_addr(0);
    ESP_ERROR_CHECK(rc);

    /* Figure out address to use while advertising (no privacy for now) */
    rc = ble_hs_id_infer_auto(0, &own_addr_type);
    if (rc != 0) {
        ESP_LOGE("aaa", "error determining address type; rc=%d", rc);
        return;
    }
}

void ble_app_advertise(const uint8_t *data, int data_len, void *callback)
{
    struct ble_gap_adv_params adv_params = (struct ble_gap_adv_params){ 0 };
    int rc;

    rc = ble_gap_adv_set_data(data, data_len);
    assert(rc == 0);

    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND;
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN;
    /* Begin advertising. */
    rc = ble_gap_adv_start(own_addr_type, NULL, BLE_HS_FOREVER,
                           &adv_params, blehr_gap_event, callback);
    assert(rc == 0);
}

void bleprph_host_task(void *param)
{
    ESP_LOGI("aaa", "BLE Host Task Started");
    /* This function will return only when nimble_port_stop() is executed */
    nimble_port_run();

    nimble_port_freertos_deinit();
}

void internal_bt_init(void (*callback)()){
    /* Initialize NVS — it is used to store PHY calibration data */
    esp_err_t ret = nvs_flash_init();

    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    ESP_ERROR_CHECK(esp_nimble_hci_and_controller_init());

    nimble_port_init();
    ble_hs_cfg.sync_cb = callback;
}

void internal_bt_start()
{
    esp_err_t ret = ble_svc_gap_device_name_set("MyTest");
    assert(ret == 0);

    // nimble_port_freertos_init(bleprph_host_task);
    bleprph_host_task (NULL);

    puts("Here's C!\n");
}