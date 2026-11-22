// SPDX-License-Identifier: Apache-2.0
#include "app_monitor_view.h"
#include "esp_iris.h"
#include "esp_log.h"
#include "iris_ota_support.h"
#include "monitor.h"
#include "plant_phone.h"
#include "sdkconfig.h"
#include "nvs_flash.h"

void app_main(void)
{
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_iris_boot_probe());
    ESP_ERROR_CHECK_WITHOUT_ABORT(nvs_flash_init());
    iris_ota_support_start();
    if (!app_monitor_view_start()) {
        ESP_LOGE("plant", "Display unavailable; serial sampling continues");
    }
    esp_err_t phone_result = plant_phone_start(CONFIG_PLANT_PHONE_SSID, CONFIG_PLANT_PHONE_PASSWORD);
    if (phone_result == ESP_OK) {
        plant_phone_publish_command("MONITORING");
        ESP_LOGI("plant", "Phone dashboard: http://192.168.4.1/");
    } else {
        ESP_LOGE("plant", "Phone dashboard unavailable: %s", esp_err_to_name(phone_result));
    }
    plant_monitor_run();
}

