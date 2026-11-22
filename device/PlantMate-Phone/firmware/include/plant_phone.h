#pragma once

#include <stdint.h>
#include "esp_err.h"

typedef struct {
    float temperature_c;
    float humidity_rh;
    float light_lux;
    int soil_gpio;
    int touch_mask;
} plant_phone_sample_t;

/* Start once after NVS initialization. Credentials must be supplied by the application. */
esp_err_t plant_phone_start(const char *ssid, const char *password);

/* Call from task context. Use NAN for failed analog readings, -1 for failed digital readings. */
void plant_phone_publish_sample(const plant_phone_sample_t *sample);

/* Publish a device-to-phone command, 1 to 47 characters from A-Z, 0-9 and underscore. */
esp_err_t plant_phone_publish_command(const char *code);

