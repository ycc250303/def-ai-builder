# Monitor view

Starts the BSP's LVGL display and creates the 480×480 dashboard.
The sampling task calls `app_monitor_view_update()` with strings in field order.
The view acquires the BSP display lock while updating labels.
Call startup once, before sampling. Labels remain owned by the screen until reset.
