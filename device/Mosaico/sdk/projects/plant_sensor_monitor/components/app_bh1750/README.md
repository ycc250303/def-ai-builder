# BH1750

Requires the ESP-IDF I2C master driver and FreeRTOS. The sampling task owns a 7-bit device handle, configured at 100 kHz, and calls `bh1750_read()` synchronously with that handle. Outputs lux. Treat outputs as valid only on ESP_OK. Transfers have a 50 ms timeout per operation.
