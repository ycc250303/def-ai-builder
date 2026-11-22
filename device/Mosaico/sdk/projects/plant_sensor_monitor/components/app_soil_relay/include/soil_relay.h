// SPDX-License-Identifier: Apache-2.0
#pragma once
#include "esp_err.h"

esp_err_t soil_relay_init(void);
esp_err_t soil_relay_read(int *level);
