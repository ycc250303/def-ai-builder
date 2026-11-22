idf_component_register(SRCS "main.c" "monitor.c"
    PRIV_REQUIRES app_monitor_view app_sht31 app_bh1750 app_mpr121 app_soil_relay
        esp-mosaico-bsp esp_iris esp_mosaico_app_recovery nvs_flash log freertos)
