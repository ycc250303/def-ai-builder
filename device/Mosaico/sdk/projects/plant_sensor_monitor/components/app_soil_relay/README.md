# Soil relay

Call `soil_relay_init()` once before `soil_relay_read(&level)` from the sampling task. Requires ESP-IDF GPIO and FreeRTOS. Reads GPIO48 with a pull-up and two samples 20 ms apart. The result is 0 for closed, 1 for open. An open wire reads as open. An unstable sample returns an error.
