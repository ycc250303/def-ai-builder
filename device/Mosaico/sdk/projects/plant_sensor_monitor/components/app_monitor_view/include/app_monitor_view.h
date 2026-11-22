// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>

enum {
    MONITOR_TEMPERATURE, MONITOR_HUMIDITY, MONITOR_LIGHT, MONITOR_SOIL,
    MONITOR_TOUCH, MONITOR_CHANNELS, MONITOR_SHT, MONITOR_BH, MONITOR_MPR,
    MONITOR_RELAY, MONITOR_FIELD_COUNT
};

bool app_monitor_view_start(void);
/* Publish strings from the sampling task. Safe when display startup failed. */
void app_monitor_view_update(const char *const fields[MONITOR_FIELD_COUNT]);
