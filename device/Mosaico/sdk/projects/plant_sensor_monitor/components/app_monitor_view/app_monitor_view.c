// SPDX-License-Identifier: Apache-2.0
#include "app_monitor_view.h"
#include <string.h>
#include "bsp/display.h"
#include "lvgl.h"

static lv_obj_t *values[MONITOR_FIELD_COUNT];

static lv_obj_t *label(lv_obj_t *parent, int x, int y, const char *text, const lv_font_t *font)
{
    lv_obj_t *obj = lv_label_create(parent);
    lv_obj_set_pos(obj, x, y);
    lv_obj_set_style_text_color(obj, lv_color_hex(0x182820), 0);
    lv_obj_set_style_text_font(obj, font, 0);
    lv_label_set_text(obj, text);
    return obj;
}

static lv_obj_t *card(lv_obj_t *screen, int x, int y, int w, int h)
{
    lv_obj_t *obj = lv_obj_create(screen);
    lv_obj_remove_style_all(obj);
    lv_obj_remove_flag(obj, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_pos(obj, x, y);
    lv_obj_set_size(obj, w, h);
    lv_obj_set_style_radius(obj, 12, 0);
    lv_obj_set_style_bg_color(obj, lv_color_hex(0xf1f5f2), 0);
    lv_obj_set_style_bg_opa(obj, LV_OPA_COVER, 0);
    return obj;
}

bool app_monitor_view_start(void)
{
    bsp_display_config_t config = BSP_DISPLAY_DEFAULT_CONFIG();
    config.enable_touch = false;
    lv_display_t *display = bsp_display_start_with_config(&config);
    if (!display || !bsp_display_lock(500)) {
        return false;
    }

    lv_obj_t *screen = lv_display_get_screen_active(display);
    lv_obj_remove_flag(screen, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_style_bg_color(screen, lv_color_white(), 0);
    lv_obj_set_style_bg_opa(screen, LV_OPA_COVER, 0);
    label(screen, 20, 18, "Plant Sensor Data", &lv_font_montserrat_30);

    const char *names[] = {"Temperature", "Humidity", "Light", "Soil"};
    for (unsigned i = 0; i < 4; ++i) {
        lv_obj_t *tile = card(screen, 20 + (i % 2) * 226, 66 + (i / 2) * 85, 214, 75);
        label(tile, 12, 8, names[i], &lv_font_montserrat_18);
        values[i] = label(tile, 12, 34, "Waiting", &lv_font_montserrat_24);
    }

    lv_obj_t *touch = card(screen, 20, 236, 440, 92);
    label(touch, 12, 7, "Touch", &lv_font_montserrat_18);
    values[MONITOR_TOUCH] = label(touch, 12, 31, "Waiting", &lv_font_montserrat_24);
    values[MONITOR_CHANNELS] = label(touch, 12, 61, "ELE0..11", &lv_font_montserrat_18);

    lv_obj_t *status = card(screen, 20, 339, 440, 121);
    label(status, 12, 9, "Sensor Connection", &lv_font_montserrat_24);
    values[MONITOR_SHT] = label(status, 12, 45, "SHT31: Waiting", &lv_font_montserrat_18);
    values[MONITOR_BH] = label(status, 220, 45, "BH1750: Waiting", &lv_font_montserrat_18);
    values[MONITOR_MPR] = label(status, 12, 76, "MPR121: Waiting", &lv_font_montserrat_18);
    values[MONITOR_RELAY] = label(status, 220, 76, "Relay: Waiting", &lv_font_montserrat_18);
    bsp_display_unlock();
    return true;
}

void app_monitor_view_update(const char *const fields[MONITOR_FIELD_COUNT])
{
    if (!values[0] || !bsp_display_lock(100)) {
        return;
    }
    for (unsigned i = 0; i < MONITOR_FIELD_COUNT; ++i) {
        if (strcmp(lv_label_get_text(values[i]), fields[i]) != 0) {
            lv_label_set_text(values[i], fields[i]);
        }
    }
    bsp_display_unlock();
}


