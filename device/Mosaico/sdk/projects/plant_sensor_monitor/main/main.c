// SPDX-License-Identifier: Apache-2.0
#include "app_monitor_view.h"
#include "esp_iris.h"
#include "esp_log.h"
#include "iris_ota_support.h"
#include "monitor.h"
#include "nvs_flash.h"

void app_main(void)
{
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_iris_boot_probe());
    ESP_ERROR_CHECK_WITHOUT_ABORT(nvs_flash_init());
    iris_ota_support_start();
    if (!app_monitor_view_start()) {
        ESP_LOGE("plant", "Display unavailable; serial sampling continues");
    }
    plant_monitor_run();
}
