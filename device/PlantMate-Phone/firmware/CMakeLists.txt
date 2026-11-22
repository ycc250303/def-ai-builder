idf_component_register(SRCS "plant_phone.c"
    INCLUDE_DIRS "include"
    PRIV_REQUIRES esp_http_server esp_wifi esp_event esp_netif
    EMBED_TXTFILES "../index.html")

