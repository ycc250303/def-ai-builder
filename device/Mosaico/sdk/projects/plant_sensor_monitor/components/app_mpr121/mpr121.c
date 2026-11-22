// SPDX-License-Identifier: Apache-2.0
#include "mpr121.h"
#include "esp_check.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "mpr121";
enum { AFE_CONFIG2 = 0x5d, ELECTRODE_CONFIG = 0x5e, SOFT_RESET = 0x80 };
enum { RUN_12_ELECTRODES = 0x8c };

static esp_err_t write_reg(i2c_master_dev_handle_t dev, uint8_t reg, uint8_t value)
{
    const uint8_t data[] = {reg, value};
    return i2c_master_transmit(dev, data, sizeof(data), 50);
}

esp_err_t mpr121_init(i2c_master_dev_handle_t dev)
{
    ESP_RETURN_ON_ERROR(write_reg(dev, SOFT_RESET, 0x63), TAG, "reset");
    vTaskDelay(pdMS_TO_TICKS(5) + 1);
    const uint8_t reg = AFE_CONFIG2;
    uint8_t value;
    ESP_RETURN_ON_ERROR(i2c_master_transmit_receive(dev, &reg, 1, &value, 1, 50),
                        TAG, "read reset signature");
    ESP_RETURN_ON_FALSE(value == 0x24, ESP_ERR_INVALID_RESPONSE, TAG, "unexpected reset signature");
    ESP_RETURN_ON_ERROR(write_reg(dev, ELECTRODE_CONFIG, 0), TAG, "stop electrodes");
    const uint8_t filters[] = {0x2b, 1, 1, 0, 0, 1, 1, 0xff, 2, 0, 0, 0};
    ESP_RETURN_ON_ERROR(i2c_master_transmit(dev, filters, sizeof(filters), 50), TAG, "baseline filters");
    for (uint8_t electrode = 0; electrode < 12; ++electrode) {
        const uint8_t thresholds[] = {0x41 + 2 * electrode, 12, 6};
        ESP_RETURN_ON_ERROR(i2c_master_transmit(dev, thresholds, sizeof(thresholds), 50),
                            TAG, "electrode thresholds");
    }
    ESP_RETURN_ON_ERROR(write_reg(dev, 0x5c, 0x10), TAG, "charge current");
    ESP_RETURN_ON_ERROR(write_reg(dev, AFE_CONFIG2, 0x20), TAG, "charge timing");
    return write_reg(dev, ELECTRODE_CONFIG, RUN_12_ELECTRODES);
}

esp_err_t mpr121_read(i2c_master_dev_handle_t dev, uint16_t *channels)
{
    const uint8_t config = ELECTRODE_CONFIG;
    uint8_t value;
    ESP_RETURN_ON_ERROR(i2c_master_transmit_receive(dev, &config, 1, &value, 1, 50),
                        TAG, "read electrode configuration");
    if (value != RUN_12_ELECTRODES) {
        return ESP_ERR_INVALID_STATE; /* Reinitialize after sensor power loss. */
    }
    const uint8_t status = 0;
    uint8_t data[2];
    ESP_RETURN_ON_ERROR(i2c_master_transmit_receive(dev, &status, 1, data, sizeof(data), 50),
                        TAG, "read touch status");
    if (data[1] & 0x80) {
        return ESP_ERR_INVALID_RESPONSE; /* Overcurrent flag. */
    }
    *channels = ((data[1] & 0x0f) << 8) | data[0];
    return ESP_OK;
}
