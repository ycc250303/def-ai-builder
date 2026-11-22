// SPDX-License-Identifier: Apache-2.0
#pragma once
#include "driver/i2c_master.h"

esp_err_t sht31_read(i2c_master_dev_handle_t dev, float *temperature, float *humidity);
