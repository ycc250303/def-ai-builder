# SHT31

Requires the ESP-IDF I2C master driver and FreeRTOS. The sampling task owns a 7-bit device handle, configured at 100 kHz, and calls `sht31_read()` synchronously with that handle. Outputs °C and 0–100 %RH. Treat outputs as valid only on ESP_OK. Transfers have a 50 ms timeout per operation.
