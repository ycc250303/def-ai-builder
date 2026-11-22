#include "plant_phone.h"

#include <math.h>
#include <string.h>
#include <stdio.h>
#include "esp_event.h"
#include "esp_http_server.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/portmacro.h"

extern const char index_html_start[] asm("_binary_index_html_start");

static portMUX_TYPE state_lock = portMUX_INITIALIZER_UNLOCKED;
static struct {
    plant_phone_sample_t sensors;
    uint32_t sequence;
    uint32_t command_id;
    char command[48];
} state = {
    .sensors = { NAN, NAN, NAN, -1, -1 },
};

void plant_phone_publish_sample(const plant_phone_sample_t *sample)
{
    portENTER_CRITICAL(&state_lock);
    state.sensors = *sample;
    ++state.sequence;
    portEXIT_CRITICAL(&state_lock);
}

esp_err_t plant_phone_publish_command(const char *code)
{
    if (!code || !*code || strlen(code) >= sizeof(state.command) || strspn(code, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_") != strlen(code)) {
        return ESP_ERR_INVALID_ARG;
    }
    portENTER_CRITICAL(&state_lock);
    strcpy(state.command, code);
    ++state.command_id;
    portEXIT_CRITICAL(&state_lock);
    return ESP_OK;
}

static esp_err_t send_page(httpd_req_t *request)
{
    httpd_resp_set_type(request, "text/html; charset=utf-8");
    httpd_resp_set_hdr(request, "Cache-Control", "no-store");
    return httpd_resp_sendstr(request, index_html_start);
}

static void encode_reading(char *output, size_t capacity, float value)
{
    if (isfinite(value)) {
        snprintf(output, capacity, "%.6g", value);
    } else {
        strcpy(output, "null");
    }
}

static esp_err_t send_state(httpd_req_t *request)
{
    portENTER_CRITICAL(&state_lock);
    __typeof__(state) snapshot = state;
    portEXIT_CRITICAL(&state_lock);

    char temperature[24], humidity[24], light[24], touch[8], command[88], body[400];
    encode_reading(temperature, sizeof(temperature), snapshot.sensors.temperature_c);
    encode_reading(humidity, sizeof(humidity), snapshot.sensors.humidity_rh);
    encode_reading(light, sizeof(light), snapshot.sensors.light_lux);
    const char *soil = snapshot.sensors.soil_gpio == 0 ? "\"low\""
        : snapshot.sensors.soil_gpio == 1 ? "\"high\"" : "null";
    if (snapshot.sensors.touch_mask >= 0 && snapshot.sensors.touch_mask <= 4095) {
        snprintf(touch, sizeof(touch), "%d", snapshot.sensors.touch_mask);
    } else {
        strcpy(touch, "null");
    }
    if (snapshot.command_id) {
        snprintf(command, sizeof(command), "{\"id\":%lu,\"code\":\"%s\"}",
            (unsigned long)snapshot.command_id, snapshot.command);
    } else {
        strcpy(command, "null");
    }
    int length = snprintf(body, sizeof(body),
        "{\"source\":\"device\",\"sequence\":%lu,\"sensors\":{"
        "\"temperature_c\":%s,\"humidity_rh\":%s,\"light_lux\":%s,"
        "\"soil_level\":%s,\"touch_mask\":%s},\"command\":%s}",
        (unsigned long)snapshot.sequence, temperature, humidity, light, soil, touch, command);
    if (length < 0 || length >= (int)sizeof(body)) {
        return httpd_resp_send_err(request, HTTPD_500_INTERNAL_SERVER_ERROR, "Unable to encode state");
    }
    httpd_resp_set_type(request, "application/json; charset=utf-8");
    httpd_resp_set_hdr(request, "Cache-Control", "no-store");
    return httpd_resp_send(request, body, length);
}

esp_err_t plant_phone_start(const char *ssid, const char *password)
{
    wifi_config_t wifi = {};
    if (!ssid || !password || !*ssid || strlen(ssid) >= sizeof(wifi.ap.ssid)
        || strlen(password) < 8 || strlen(password) >= sizeof(wifi.ap.password)) {
        return ESP_ERR_INVALID_ARG;
    }
    memcpy(wifi.ap.ssid, ssid, strlen(ssid));
    memcpy(wifi.ap.password, password, strlen(password));
    wifi.ap.authmode = WIFI_AUTH_WPA2_PSK;
    wifi.ap.channel = 1;
    wifi.ap.max_connection = 2;

    esp_err_t result = esp_netif_init();
    if (result != ESP_OK) return result;
    result = esp_event_loop_create_default();
    if (result != ESP_OK && result != ESP_ERR_INVALID_STATE) return result;
    esp_netif_t *ap = esp_netif_create_default_wifi_ap();
    if (!ap) return ESP_FAIL;

    wifi_init_config_t config = WIFI_INIT_CONFIG_DEFAULT();
    result = esp_wifi_init(&config);
    if (result != ESP_OK) goto destroy_ap;
    result = esp_wifi_set_storage(WIFI_STORAGE_RAM);
    if (result == ESP_OK) result = esp_wifi_set_mode(WIFI_MODE_AP);
    if (result == ESP_OK) result = esp_wifi_set_config(WIFI_IF_AP, &wifi);
    if (result == ESP_OK) result = esp_wifi_start();
    if (result != ESP_OK) goto deinit_wifi;

    httpd_handle_t server = NULL;
    httpd_config_t http_config = HTTPD_DEFAULT_CONFIG();
    const httpd_uri_t page = { .uri = "/", .method = HTTP_GET, .handler = send_page };
    const httpd_uri_t api = { .uri = "/api/state", .method = HTTP_GET, .handler = send_state };
    result = httpd_start(&server, &http_config);
    if (result == ESP_OK) result = httpd_register_uri_handler(server, &page);
    if (result == ESP_OK) result = httpd_register_uri_handler(server, &api);
    if (result == ESP_OK) return ESP_OK;

    if (server) httpd_stop(server);
    esp_wifi_stop();
deinit_wifi:
    esp_wifi_deinit();
destroy_ap:
    esp_netif_destroy_default_wifi(ap);
    return result;
}


