// SPDX-License-Identifier: Apache-2.0
#include "bh1750.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

esp_err_t bh1750_read(i2c_master_dev_handle_t dev, float *lux)
{
    const uint8_t command = 0x20; /* One-time high-resolution mode. */
    esp_err_t err = i2c_master_transmit(dev, &command, 1, 50);
    if (err != ESP_OK) {
        return err;
    }
    vTaskDelay(pdMS_TO_TICKS(180) + 1);
    uint8_t data[2];
    err = i2c_master_receive(dev, data, sizeof(data), 50);
    if (err == ESP_OK) {
        *lux = ((data[0] << 8) | data[1]) / 1.2f;
    }
    return err;
}
