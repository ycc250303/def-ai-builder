# MPR121

Requires the ESP-IDF I2C master driver and FreeRTOS. The sampling task owns a 7-bit device handle, configured at 100 kHz, and calls `mpr121_read()` synchronously with that handle. Call `mpr121_init()` first. Bits 0–11 correspond to ELE0–ELE11. Treat outputs as valid only on ESP_OK. Transfers have a 50 ms timeout per operation.
