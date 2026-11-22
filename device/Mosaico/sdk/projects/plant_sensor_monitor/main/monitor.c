// SPDX-License-Identifier: Apache-2.0
#include "monitor.h"

#include <stdio.h>
#include "app_monitor_view.h"
#include "bh1750.h"
#include "bsp/esp_mosaico.h"
#include "bsp/subboard.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "mpr121.h"
#include "sdkconfig.h"
#include "sht31.h"
#include "soil_relay.h"

static const char *TAG = "plant";

typedef struct {
    const char *name;
    uint8_t address;
    uint8_t alternate;
    i2c_master_dev_handle_t handle;
} sensor_t;

static esp_err_t connect(i2c_master_bus_handle_t bus, sensor_t *sensor)
{
    if (sensor->handle) {
        return ESP_OK;
    }
    if (!bus) {
        return ESP_ERR_INVALID_STATE;
    }
    const uint8_t candidates[] = {sensor->address, sensor->alternate};
    esp_err_t err = ESP_ERR_NOT_FOUND;
    for (unsigned i = 0; i < 2 && candidates[i]; ++i) {
        err = i2c_master_probe(bus, candidates[i], 50);
        if (err == ESP_OK) {
            const i2c_device_config_t config = {
                .dev_addr_length = I2C_ADDR_BIT_LEN_7,
                .device_address = candidates[i],
                .scl_speed_hz = 100000,
            };
            err = i2c_master_bus_add_device(bus, &config, &sensor->handle);
            if (err == ESP_OK) {
                ESP_LOGI(TAG, "%s ACK at 0x%02X", sensor->name, candidates[i]);
            }
            break;
        }
    }
    return err;
}

static void disconnect_on_error(sensor_t *sensor, esp_err_t err)
{
    if (err != ESP_OK && sensor->handle) {
        ESP_LOGW(TAG, "%s read/initialization: %s", sensor->name, esp_err_to_name(err));
        ESP_ERROR_CHECK_WITHOUT_ABORT(i2c_master_bus_rm_device(sensor->handle));
        sensor->handle = NULL;
    }
}

static const char *soil_text(esp_err_t status, int level)
{
    if (status != ESP_OK) {
        return "ERROR";
    }
#if CONFIG_PLANT_SOIL_LOW_DRY
    return level == 0 ? "Dry" : "Wet";
#elif CONFIG_PLANT_SOIL_HIGH_DRY
    return level == 1 ? "Dry" : "Wet";
#else
    return level == 0 ? "Closed / LOW" : "Open / HIGH";
#endif
}

static void sample(i2c_master_bus_handle_t bus,
                   sensor_t *sht, sensor_t *bh, sensor_t *mpr,
                   bool touch_allowed, esp_err_t relay_init)
{
    float temperature = 0, humidity = 0, lux = 0;
    uint16_t channels = 0;
    int level = -1;

    esp_err_t sht_result = connect(bus, sht);
    if (sht_result == ESP_OK) {
        sht_result = sht31_read(sht->handle, &temperature, &humidity);
    }
    disconnect_on_error(sht, sht_result);

    esp_err_t bh_result = connect(bus, bh);
    if (bh_result == ESP_OK) {
        bh_result = bh1750_read(bh->handle, &lux);
    }
    disconnect_on_error(bh, bh_result);

    const bool init_touch = mpr->handle == NULL;
    esp_err_t mpr_result = touch_allowed ? connect(bus, mpr) : ESP_ERR_NOT_SUPPORTED;
    if (mpr_result == ESP_OK && init_touch) {
        mpr_result = mpr121_init(mpr->handle);
    }
    if (mpr_result == ESP_OK) {
        mpr_result = mpr121_read(mpr->handle, &channels);
    }
    disconnect_on_error(mpr, mpr_result);

    const esp_err_t soil_result = relay_init == ESP_OK ? soil_relay_read(&level) : relay_init;
    char temp[20] = "ERROR", rh[20] = "ERROR", light[20] = "ERROR", electrodes[13] = "";
    if (sht_result == ESP_OK) {
        snprintf(temp, sizeof(temp), "%.1f °C", temperature);
        snprintf(rh, sizeof(rh), "%.1f %%RH", humidity);
    }
    if (bh_result == ESP_OK) {
        snprintf(light, sizeof(light), "%.1f lux", lux);
    }
    if (mpr_result == ESP_OK) {
        for (unsigned i = 0; i < 12; ++i) {
            electrodes[i] = channels & (1U << i) ? '1' : '0';
        }
    }
    const char *touch = mpr_result != ESP_OK ? "ERROR" : (channels ? "Touched" : "Idle");
    const char *soil = soil_text(soil_result, level);

    ESP_LOGI(TAG, "## Plant Sensor Data | Temperature: %s | Humidity: %s | Light: %s | Soil: %s (GPIO=%d) | Touch: %s | ELE0..11: %s",
             temp, rh, light, soil, level, touch, mpr_result == ESP_OK ? electrodes : "ERROR");
    ESP_LOGI(TAG, "Sensor Connection | SHT31: %s | BH1750: %s | MPR121: %s | Relay input: %s",
             esp_err_to_name(sht_result), esp_err_to_name(bh_result),
             esp_err_to_name(mpr_result), soil_result == ESP_OK ? "READABLE (wiring unverified)" : "ERROR");

    const char *fields[MONITOR_FIELD_COUNT] = {
        temp, rh, light, soil, touch, mpr_result == ESP_OK ? electrodes : "ELE0..11: ERROR",
        sht_result == ESP_OK ? "SHT31: OK" : "SHT31: ERROR",
        bh_result == ESP_OK ? "BH1750: OK" : "BH1750: ERROR",
        mpr_result == ESP_OK ? "MPR121: OK" : "MPR121: ERROR",
        soil_result == ESP_OK ? "Relay: Input OK" : "Relay: ERROR",
    };
    app_monitor_view_update(fields);
}

void plant_monitor_run(void)
{
    bsp_board_variant_t variant;
    const esp_err_t variant_err = bsp_board_variant_get(&variant);
    const esp_err_t bus_err = variant_err == ESP_OK ? bsp_subboard_init() : variant_err;
    i2c_master_bus_handle_t bus = bus_err == ESP_OK ? bsp_subboard_get_i2c_bus() : NULL;
    ESP_LOGI(TAG, "CoreBoard BSP: %s | external I2C GPIO0/GPIO1: %s",
             variant_err != ESP_OK ? "unknown" : variant == BSP_BOARD_VARIANT_V1_0 ? "V1.0" : "V1.2",
             bus ? "ready" : esp_err_to_name(bus_err));

    sensor_t sht = {.name = "SHT31", .address = 0x44, .alternate = 0x45};
    sensor_t bh = {.name = "BH1750", .address = 0x23, .alternate = 0x5c};
    sensor_t mpr = {.name = "MPR121", .address = CONFIG_PLANT_MPR121_ADDRESS};
    const bool touch_allowed = variant_err == ESP_OK && mpr.address != 0x5c &&
                               (variant != BSP_BOARD_VARIANT_V1_0 || mpr.address != 0x5a);
    if (!touch_allowed) {
        ESP_LOGE(TAG, "MPR121 address 0x%02X blocked: check board and ADDR wiring; use 0x5B or 0x5D", mpr.address);
    }
    if (mpr.address == 0x5c) {
        bh.alternate = 0; /* Neither driver may access the potentially overlapping address. */
    }
    const esp_err_t relay_init = variant_err == ESP_OK ? soil_relay_init() : variant_err;
#if CONFIG_PLANT_SOIL_UNCALIBRATED
    ESP_LOGW(TAG, "Soil polarity uncalibrated; reporting raw contact until menuconfig is set");
#endif

    TickType_t last = xTaskGetTickCount();
    for (;;) {
        sample(bus, &sht, &bh, &mpr, touch_allowed, relay_init);
        vTaskDelayUntil(&last, pdMS_TO_TICKS(1000));
    }
}




