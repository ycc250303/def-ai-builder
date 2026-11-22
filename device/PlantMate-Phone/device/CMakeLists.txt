cmake_minimum_required(VERSION 3.16)
set(MOSAICO_SDK_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../Mosaico/sdk" CACHE PATH "ESP-Mosaico SDK")
set(MOSAICO_UTILS_ROOT "${MOSAICO_SDK_ROOT}/submodule/esp-mosaico-utils")
set(MOSAICO_BSP_ROOT "${MOSAICO_SDK_ROOT}/submodule/esp-mosaico-bsp")
if(NOT SDKCONFIG)
    set(SDKCONFIG "${CMAKE_BINARY_DIR}/sdkconfig")
endif()
if(NOT SDKCONFIG_DEFAULTS)
    set(SDKCONFIG_DEFAULTS "sdkconfig.defaults;sdkconfig.application.defaults")
endif()
list(APPEND EXTRA_COMPONENT_DIRS
    "${CMAKE_CURRENT_LIST_DIR}/../firmware"
    "${MOSAICO_SDK_ROOT}/projects/plant_sensor_monitor/components"
    "${MOSAICO_UTILS_ROOT}/esp-mosaico-vibe-mode/components/esp_mosaico_app_recovery" ${PLANT_PHONE_OFFLINE_COMPONENTS})
include("${MOSAICO_UTILS_ROOT}/esp-mosaico-vibe-mode/cmake/mosaico_idf_project.cmake")
project(plantmate_phone VERSION 1.0.0)

