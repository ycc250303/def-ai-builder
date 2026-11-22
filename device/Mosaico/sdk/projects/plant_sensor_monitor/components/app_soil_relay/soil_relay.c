// SPDX-License-Identifier: Apache-2.0
#include "soil_relay.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define RELAY_PIN GPIO_NUM_48

esp_err_t soil_relay_init(void)
{
    const gpio_config_t config = {
        .pin_bit_mask = 1ULL << RELAY_PIN,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
    };
    return gpio_config(&config);
}

esp_err_t soil_relay_read(int *level)
{
    const int first = gpio_get_level(RELAY_PIN);
    vTaskDelay(pdMS_TO_TICKS(20) + 1);
    *level = gpio_get_level(RELAY_PIN);
    return first == *level ? ESP_OK : ESP_ERR_INVALID_STATE;
}
