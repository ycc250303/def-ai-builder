// SPDX-License-Identifier: Apache-2.0
#include "sht31.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static uint8_t crc(const uint8_t *data)
{
    uint8_t value = 0xff;
    for (int i = 0; i < 2; ++i) {
        value ^= data[i];
        for (int bit = 0; bit < 8; ++bit) {
            value = (value << 1) ^ ((value & 0x80) ? 0x31 : 0);
        }
    }
    return value;
}

esp_err_t sht31_read(i2c_master_dev_handle_t dev, float *temperature, float *humidity)
{
    const uint8_t command[] = {0x24, 0x00};
    esp_err_t err = i2c_master_transmit(dev, command, sizeof(command), 50);
    if (err != ESP_OK) {
        return err;
    }
    vTaskDelay(pdMS_TO_TICKS(20) + 1);
    uint8_t data[6];
    err = i2c_master_receive(dev, data, sizeof(data), 50);
    if (err != ESP_OK) {
        return err;
    }
    if (crc(data) != data[2] || crc(data + 3) != data[5]) {
        return ESP_ERR_INVALID_CRC;
    }
    *temperature = -45.0f + 175.0f * ((data[0] << 8) | data[1]) / 65535.0f;
    *humidity = 100.0f * ((data[3] << 8) | data[4]) / 65535.0f;
    return ESP_OK;
}
