# main

`main.c` starts the ESP-Iris Recovery entry point and initializes the display.
`monitor.c` owns the I²C handles, takes independent samples once per second,
and publishes the same results to ESP-IDF logging and LVGL.
The BSP owns the bus and rail for the full boot. Sensor handles are released on
read or initialization failure so the next sample can probe again.
