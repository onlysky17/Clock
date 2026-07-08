/**
 ****************************************************************************************
 *
 * @file user_custs1_impl.c
 *
 * @brief Peripheral project Custom1 Server implementation source code.
 *
 * Copyright (C) 2015-2019 Dialog Semiconductor.
 * This computer program includes Confidential, Proprietary Information
 * of Dialog Semiconductor. All Rights Reserved.
 *
 ****************************************************************************************
 */

/*
 * INCLUDE FILES
 ****************************************************************************************
 */

#include "gpio.h"
#include "app_api.h"
#include "app.h"
#include "prf_utils.h"
#include "uart_utils.h"
#include "custs1.h"
#include "custs1_task.h"
#include "user_custs1_def.h"
#include "user_custs1_impl.h"
#include "user_periph_setup.h"
#include "user_callback_config.h"
#include "ImageData.h"
#include "etime.h"
#include "crc32.h"
#include "app.h"
#include "app_bass.h"
#include "battery.h"
#include "user_ota.h"
#include "fonts.h"
#include "GUI_Paint.h"
#include "lunar.h"
/*
 * GLOBAL VARIABLE DEFINITIONS
 ****************************************************************************************
 */
#define APP_PERIPHERAL_CTRL_TIMER_DELAY 10
#define APP_PERIPHERAL_CTRL_TIMER_DELAY_MINUTES 6000
#define Time_To_Refresh 0

#define IMG_HEADER_SIGNATURE1 0x70
#define IMG_HEADER_SIGNATURE2 0x55
#define IMG_HEADER_VALID 0x55
#define IMG_HEADER_VALID 0x55
#define IMG_HEADER_ADDRESS 0x20000
/// Image header
typedef struct
{
    /// Signature
    uint8_t signature[2];
    /// Valid; set to STATUS_VALID_IMAGE at the end of the image update
    uint8_t validflag;
    /// ID to determine which image is the newest one
    uint8_t imageid;
    /// Image size
    uint32_t code_size;
    /// Image CRC
    uint32_t CRC;
} img_header_t;
img_header_t imgheader __SECTION_ZERO("retention_mem_area0");
ke_msg_id_t timer_used __SECTION_ZERO("retention_mem_area0");      //@RETENTION MEMORY
uint16_t indication_counter __SECTION_ZERO("retention_mem_area0"); //@RETENTION MEMORY
uint16_t non_db_val_counter __SECTION_ZERO("retention_mem_area0"); //@RETENTION MEMORY
#define epd_buffer_size (EPD_2IN13_V2_WIDTH * EPD_2IN13_V2_HEIGHT / 8)
#define buffer_size (EPD_2IN13_V2_WIDTH * EPD_2IN13_V2_HEIGHT / 4)
uint32_t byte_pos __SECTION_ZERO("retention_mem_area0");
uint8_t epd_buffer[buffer_size] __SECTION_ZERO("retention_mem_area0");
uint16_t index __SECTION_ZERO("retention_mem_area0");
uint8_t step __SECTION_ZERO("retention_mem_area0");
ke_msg_id_t timer_used_min __SECTION_ZERO("retention_mem_area0"); //@RETENTION MEMORY
uint32_t current_unix_time __SECTION_ZERO("retention_mem_area0");
uint8_t time_offset __SECTION_ZERO("retention_mem_area0");
uint16_t time_refresh_count __SECTION_ZERO("retention_mem_area0");
uint8_t isconnected __SECTION_ZERO("retention_mem_area0");
tm_t g_tm __SECTION_ZERO("retention_mem_area0");
uint8_t is_part __SECTION_ZERO("retention_mem_area0");
uint8_t buf[50];
uint8_t buf2[50];
static const char * const WEEK_VI_ASCII[7] =
    {"CN", "Thu 2", "Thu 3", "Thu 4", "Thu 5", "Thu 6", "Thu 7"};
void bls_att_pushNotifyData(uint16_t attHandle, uint8_t *p, uint8_t len);
void display(void);
void do_time_show(void);
uint8_t dev_id __SECTION_ZERO("retention_mem_area0");
static void spi_flash_peripheral_init(void)
{
    // Release the SPI flash memory from power down
    spi_flash_release_from_power_down();

    // Disable the SPI flash memory protection (unprotect all sectors)
    spi_flash_configure_memory_protection(SPI_FLASH_MEM_PROT_NONE);

    // Try to auto-detect the SPI flash memory
    spi_flash_auto_detect(&dev_id);
    EPD_CS_H;
}
/*
 * FUNCTION DEFINITIONS
 ****************************************************************************************
 */
void do_img_save(void)
{
    uint32_t actual_size;
    if (imgheader.signature[0] == IMG_HEADER_SIGNATURE1 && imgheader.signature[1] == IMG_HEADER_SIGNATURE2 && imgheader.validflag != IMG_HEADER_VALID)
    {
        imgheader.validflag = IMG_HEADER_VALID;
        img_header_t *imgheadertmp;
        spi_flash_peripheral_init();

        uint8_t buf[20] = {0};
        int8_t status = spi_flash_read_data(buf, IMG_HEADER_ADDRESS, sizeof(img_header_t), &actual_size);
        arch_printf("status0:%d\n", status);
        imgheadertmp = (img_header_t *)buf;
        // if (imgheadertmp->CRC != imgheader.CRC)
        // {
        // status=spi_flash_block_erase(IMG_HEADER_ADDRESS, SPI_FLASH_OP_BE32);
        // arch_printf("status1:%d\n",status);
        // arch_printf("erase\n");
        // status=spi_flash_set_write_enable();
        // arch_printf("status4s:%d\n",status);
        // status=spi_flash_write_data((uint8_t *)&imgheader, IMG_HEADER_ADDRESS, sizeof(img_header_t), &actual_size);
        // arch_printf("status2:%d\n",status);
        // arch_printf("imgheader wr:%d\n", actual_size);
        // status=spi_flash_write_data(epd_buffer, IMG_HEADER_ADDRESS + sizeof(img_header_t), sizeof(epd_buffer), &actual_size);
        // arch_printf("status3:%d\n",status);
        // arch_printf("epd_buffer wr:%d size:%d\n", actual_size,sizeof(epd_buffer));
        // }
        spi_flash_ultra_deep_power_down();
    }
}
void do_time_show(void)
{
    transformTime(current_unix_time, &g_tm);
    Paint_NewImage(epd_buffer, EPD_2IN13_V2_WIDTH, EPD_2IN13_V2_HEIGHT, 270, WHITE);
    Paint_SelectImage(epd_buffer);
    Paint_SetMirroring(MIRROR_VERTICAL);
    Paint_Clear(WHITE);
    sprintf(buf, "%d-%02d-%02d", g_tm.tm_year + YEAR0, g_tm.tm_mon + 1, g_tm.tm_mday);

    EPD_DrawUTF8(5, 1, 1, buf, EPD_ASCII_11X16, EPD_FontUTF8_16x16, BLACK, WHITE);
    sprintf(buf, "%s", WEEK_VI_ASCII[g_tm.tm_wday]);
    EPD_DrawUTF8(5 + 125, 1, 1, buf, EPD_ASCII_11X16, NULL, BLACK, WHITE);
    sprintf(buf, "%02d", g_tm.tm_hour);
    EPD_DrawUTF8(10, 20 + 2, 5, buf, EPD_40X80_TABLE, EPD_FontUTF8_24x24, BLACK, WHITE);
    EPD_DrawUTF8(10 + 86 - 10, 20 + 2, 5, ":", EPD_40X80_TABLE, EPD_FontUTF8_24x24, BLACK, WHITE);
    sprintf(buf, "%02d", g_tm.tm_min);
    EPD_DrawUTF8(10 + 86 + 20, 20 + 2, 5, buf, EPD_40X80_TABLE, EPD_FontUTF8_24x24, BLACK, WHITE);
    Paint_DrawRectangle(212 - 24, 6 + 2, 212 - 24 + 2, 8 + 2 + 2, BLACK, DOT_PIXEL_1X1, DRAW_FILL_FULL);
    Paint_DrawRectangle(212 - 22, 1 + 2, 211, 20 - 5 + 2, BLACK, DOT_PIXEL_1X1, DRAW_FILL_FULL);
    sprintf(buf, "%d", cur_batt_level);
    if (cur_batt_level > 9 && cur_batt_level < 100)
    {
        sprintf(buf, " %d", cur_batt_level);
    }
    else if (cur_batt_level < 10)
    {
        sprintf(buf, "  %d", cur_batt_level);
    }
    EPD_DrawUTF8(212 - 23, 1 + 2, 0, buf, EPD_ASCII_7X12, 0, WHITE, BLACK);
    if (isconnected == 1)
    {
        EPD_DrawUTF8(212 - 10, 104-14, 0, "B", EPD_ASCII_7X12, 0, WHITE, BLACK);
    }
    if (g_tm.tm_min == 0)
    {
        is_part = 0;
    }
    step = 0;
}

void do_min_work(void)
{
    timer_used_min = app_easy_timer(APP_PERIPHERAL_CTRL_TIMER_DELAY_MINUTES, do_min_work);
    current_unix_time += time_offset;
    time_offset = 60;
    // if (isconnected == 1)
    // {
    //     GPIO_SetActive(GPIO_LED_PORT, GPIO_LED_PIN);
    //     GPIO_SetInactive(GPIO_LED_PORT, GPIO_LED_G_PIN);
    //     DEV_Delay_ms(5);
    // }
    arch_printf("current_unix_time:%d\n", current_unix_time);
    
   
    do_time_show();
    if (step == 0)
    {
        // do_img_save();
        step = 1;
        display();
    }
    // time_refresh_count++;
    // if ((time_refresh_count >= Time_To_Refresh) && (g_tm.tm_min == 0 && g_tm.tm_hour == 0))
    // {
    //     if (step == 0)
    //     {
    //         // do_img_save();
    //         step = 1;
    //         display();
    //     }
    // }
    // GPIO_SetActive(GPIO_LED_PORT, GPIO_LED_G_PIN);
    // GPIO_SetInactive(GPIO_LED_PORT, GPIO_LED_PIN);
}

void my_app_on_db_init_complete(void)
{
    crc32_init(DEFAULT_POLY);
    arch_printf("crc32_init\n");
    CALLBACK_ARGS_0(user_default_app_operations.default_operation_adv)
    arch_printf("my_app_on_db_init_complete\n");
    timer_used_min = app_easy_timer(100, do_min_work);
    spi_flash_peripheral_init();
    uint32_t actual_size;
    int8_t status = spi_flash_read_data((uint8_t *)&imgheader, IMG_HEADER_ADDRESS, sizeof(img_header_t), &actual_size);
    arch_printf("imgheader read:%d,status:%d", actual_size, status);
    if (imgheader.signature[0] == IMG_HEADER_SIGNATURE1 && imgheader.signature[1] == IMG_HEADER_SIGNATURE2 && imgheader.validflag == IMG_HEADER_VALID)
    {
        spi_flash_read_data(epd_buffer, IMG_HEADER_ADDRESS + sizeof(img_header_t), sizeof(epd_buffer), &actual_size);
        arch_printf("epd_buffer read:%d\n", actual_size);
    }
    spi_flash_ultra_deep_power_down();
    cur_batt_level = 101;
    app_batt_lvl();
    // Paint_NewImage(epd_buffer, EPD_2IN9_WIDTH, EPD_2IN9_HEIGHT, 270, WHITE);
    // Paint_SelectImage(epd_buffer);
}
void user_svc1_ctrl_wr_ind_handler(ke_msg_id_t const msgid,
                                   struct custs1_val_write_ind const *param,
                                   ke_task_id_t const dest_id,
                                   ke_task_id_t const src_id)
{
    uint8_t val = 0;
    memcpy(&val, &param->value[0], param->length);

    if (val != CUSTS1_CP_ADC_VAL1_DISABLE)
    {
        timer_used = app_easy_timer(APP_PERIPHERAL_CTRL_TIMER_DELAY, app_adcval1_timer_cb_handler);
    }
    else
    {
        if (timer_used != EASY_TIMER_INVALID_TIMER)
        {
            app_easy_timer_cancel(timer_used);
            timer_used = EASY_TIMER_INVALID_TIMER;
        }
    }
}

void display(void)
{
    time_refresh_count = 0;
    uint8_t isbusy = 1;
    uint32_t delay = APP_PERIPHERAL_CTRL_TIMER_DELAY;
    uint8_t out_buffer[2];
    spi_set_bitmode(SPI_MODE_8BIT);
    spi_cs_high();
    switch (step)
    {
    case 1:
        cur_batt_level = 100;
        app_batt_lvl();
        arch_printf("epd_init\n");
        EPD_GPIO_init();
        EPD_2IN13_V2_Init(is_part);
        step++;
        break;
    case 2:
        if (is_part == 0)
        {
            EPD_2IN13_V2_DisplayPartBaseImage(epd_buffer);
        }
        else
        {
            EPD_2IN13_V2_DisplayPart(epd_buffer);
        }

        step++;
        break;
    case 3:
        if (is_part == 0)
        {
            is_part = 1;
            EPD_2IN13_V2_TurnOnDisplay();
        }
        else
        {
            EPD_2IN13_V2_TurnOnDisplayPart();
        }

        step++;
        break;
    case 4:
        app_batt_lvl();
        if (EPD_BUSY == 0)
        {
            isbusy = 0;
            step = 0;
            arch_printf("epd_sleep\n");
            EPD_2IN13_V2_Sleep();
            out_buffer[0] = 0xff;
            out_buffer[1] = 0xff;
            bls_att_pushNotifyData(SVC1_IDX_LED_STATE_VAL, out_buffer, 2);
        }

        break;
    default:
        break;
    }

    if (isbusy && (step != 0))
    {
        app_easy_timer(delay, display);
    }
    else
    {
        app_easy_timer_cancel(timer_used);
    }
}

void bls_att_pushNotifyData(uint16_t attHandle, uint8_t *p, uint8_t len)
{
    struct custs1_val_ntf_ind_req *req = KE_MSG_ALLOC_DYN(CUSTS1_VAL_NTF_REQ,
                                                          prf_get_task_from_id(TASK_ID_CUSTS1),
                                                          TASK_APP,
                                                          custs1_val_ntf_ind_req,
                                                          DEF_SVC1_ADC_VAL_1_CHAR_LEN);

    req->handle = attHandle;
    req->length = len;
    req->notification = true;
    memcpy(req->value, p, len);

    ke_msg_send(req);
}

void user_svc1_led_wr_ind_handler(ke_msg_id_t const msgid,
                                  struct custs1_val_write_ind const *param,
                                  ke_task_id_t const dest_id,
                                  ke_task_id_t const src_id)

{
    const uint8_t *payload = param->value;
    uint16_t payload_len = param->length;
    uint8_t out_buffer[20] = {0};
    if (step != 0)
    {
        out_buffer[0] = 0x00;
        out_buffer[1] = 0x00;
        bls_att_pushNotifyData(SVC1_IDX_LED_STATE_VAL, out_buffer, 2);
        return;
    }
    switch (param->value[0])
    {
    // Clear EPD display.
    case 0x00:
        ASSERT_MIN_LEN(payload_len, 2);
        // memset(epd_buffer, payload[1], epd_buffer_size);
        // memset(epd_temp, payload[1], epd_buffer_size);

        return;
    // Push buffer to display.
    case 0x01:
        // EPD_Display(epd_buffer, epd_temp, epd_buffer_size, payload[1]);
        arch_printf("start EPD_Display\r\n");
        imgheader.signature[0] = IMG_HEADER_SIGNATURE1;
        imgheader.signature[1] = IMG_HEADER_SIGNATURE2;
        imgheader.CRC = 0xFFFFFFFF;
        imgheader.CRC = crc32(imgheader.CRC, epd_buffer, sizeof(epd_buffer));
        imgheader.CRC ^= 0xFFFFFFFF;
        imgheader.code_size = sizeof(epd_buffer);
        imgheader.validflag = 0;
        step = 1;

        app_easy_timer(APP_PERIPHERAL_CTRL_TIMER_DELAY, display);
        return;
    // Set byte_pos.
    case 0x02:
        ASSERT_MIN_LEN(payload_len, 3);
        byte_pos = payload[1] << 8 | payload[2];
        return;
    // Write data to image buffer.
    case 0x03:
        if ((payload[2] << 8 | payload[3]) + payload_len - 4 >= epd_buffer_size + 1)
        {
            out_buffer[0] = 0x00;
            out_buffer[1] = 0x00;
            bls_att_pushNotifyData(SVC1_IDX_LED_STATE_VAL, out_buffer, 2);
            return;
        }
        if (payload[1] == 0xff)
        {
            memcpy(epd_buffer + (payload[2] << 8 | payload[3]), payload + 4, payload_len - 4);
        }
        out_buffer[0] = payload_len >> 8;
        out_buffer[1] = payload_len & 0xff;
        bls_att_pushNotifyData(SVC1_IDX_LED_STATE_VAL, out_buffer, 2);
        return;
    case 0x04: // decode & display a TIFF image
        // param_update_request(1);
        return;
    case 0xAA:
        do_img_save();
        break;
    case 0xAB:
        platform_reset(RESET_NO_ERROR);
        break;
    default:
        return;
    }
}

void user_svc2_wr_ind_handler(ke_msg_id_t const msgid,
                              struct custs1_val_write_ind const *param,
                              ke_task_id_t const dest_id,
                              ke_task_id_t const src_id)
{

    // sprintf(buf2,"HEX %d :",param->length);
    arch_printf("cmd HEX %d:", param->length);
    for (int i = 0; i < param->length; i++)
    {
        arch_printf("%02X", param->value[i]);
    }
    arch_printf("\r\n");
    if ((param->value[0] == 0xDD) && (param->length >= 5))
    {
        current_unix_time = (param->value[1] << 24) + (param->value[2] << 16) + (param->value[3] << 8) + (param->value[4] & 0xff);
        tm_t tm = {0};
        transformTime(current_unix_time, &tm);
        app_easy_timer_cancel(timer_used_min);
        time_offset = 60 - tm.tm_sec;
        timer_used_min = app_easy_timer(time_offset * 100, do_min_work);
        arch_printf("%d-%02d-%02d %02d:%02d:%02d %d\n", tm.tm_year + YEAR0,
                    tm.tm_mon + 1,
                    tm.tm_mday,
                    tm.tm_hour,
                    tm.tm_min,
                    tm.tm_sec,
                    tm.tm_wday);
    }
    else if (param->value[0] == 0xAA)
    {
        platform_reset(RESET_NO_ERROR);
    }
    else if (param->value[0] == 0xAB)
    {
        // do_img_save();
    }
    else if (param->value[0] == 0xE2)
    {
        do_time_show();
        is_part = 0;
        step = 1;
        display();
        
    }
}

void user_svc1_long_val_cfg_ind_handler(ke_msg_id_t const msgid,
                                        struct custs1_val_write_ind const *param,
                                        ke_task_id_t const dest_id,
                                        ke_task_id_t const src_id)
{
    // Generate indication when the central subscribes to it
    // if (param->value[0])
    // {
    //     uint8_t conidx = KE_IDX_GET(src_id);

    //     struct custs1_val_ind_req *req = KE_MSG_ALLOC_DYN(CUSTS1_VAL_IND_REQ,
    //                                                       prf_get_task_from_id(TASK_ID_CUSTS1),
    //                                                       TASK_APP,
    //                                                       custs1_val_ind_req,
    //                                                       sizeof(indication_counter));

    //     req->conidx = app_env[conidx].conidx;
    //     req->handle = SVC1_IDX_INDICATEABLE_VAL;
    //     req->length = sizeof(indication_counter);
    //     req->value[0] = (indication_counter >> 8) & 0xFF;
    //     req->value[1] = indication_counter & 0xFF;

    //     indication_counter++;

    //     ke_msg_send(req);
    // }
}

void user_svc1_long_val_wr_ind_handler(ke_msg_id_t const msgid,
                                       struct custs1_val_write_ind const *param,
                                       ke_task_id_t const dest_id,
                                       ke_task_id_t const src_id)
{
}

void user_svc1_long_val_ntf_cfm_handler(ke_msg_id_t const msgid,
                                        struct custs1_val_write_ind const *param,
                                        ke_task_id_t const dest_id,
                                        ke_task_id_t const src_id)
{
}

void user_svc1_adc_val_1_cfg_ind_handler(ke_msg_id_t const msgid,
                                         struct custs1_val_write_ind const *param,
                                         ke_task_id_t const dest_id,
                                         ke_task_id_t const src_id)
{
}

void user_svc1_adc_val_1_ntf_cfm_handler(ke_msg_id_t const msgid,
                                         struct custs1_val_write_ind const *param,
                                         ke_task_id_t const dest_id,
                                         ke_task_id_t const src_id)
{
}

void user_svc1_button_cfg_ind_handler(ke_msg_id_t const msgid,
                                      struct custs1_val_write_ind const *param,
                                      ke_task_id_t const dest_id,
                                      ke_task_id_t const src_id)
{
}

void user_svc1_button_ntf_cfm_handler(ke_msg_id_t const msgid,
                                      struct custs1_val_write_ind const *param,
                                      ke_task_id_t const dest_id,
                                      ke_task_id_t const src_id)
{
}

void user_svc1_indicateable_cfg_ind_handler(ke_msg_id_t const msgid,
                                            struct custs1_val_write_ind const *param,
                                            ke_task_id_t const dest_id,
                                            ke_task_id_t const src_id)
{
}

void user_svc1_indicateable_ind_cfm_handler(ke_msg_id_t const msgid,
                                            struct custs1_val_write_ind const *param,
                                            ke_task_id_t const dest_id,
                                            ke_task_id_t const src_id)
{
}

void user_svc1_long_val_att_info_req_handler(ke_msg_id_t const msgid,
                                             struct custs1_att_info_req const *param,
                                             ke_task_id_t const dest_id,
                                             ke_task_id_t const src_id)
{
    struct custs1_att_info_rsp *rsp = KE_MSG_ALLOC(CUSTS1_ATT_INFO_RSP,
                                                   src_id,
                                                   dest_id,
                                                   custs1_att_info_rsp);
    // Provide the connection index.
    rsp->conidx = app_env[param->conidx].conidx;
    // Provide the attribute index.
    rsp->att_idx = param->att_idx;
    // Provide the current length of the attribute.
    rsp->length = 0;
    // Provide the ATT error code.
    rsp->status = ATT_ERR_NO_ERROR;

    ke_msg_send(rsp);
}

void user_svc1_rest_att_info_req_handler(ke_msg_id_t const msgid,
                                         struct custs1_att_info_req const *param,
                                         ke_task_id_t const dest_id,
                                         ke_task_id_t const src_id)
{
    struct custs1_att_info_rsp *rsp = KE_MSG_ALLOC(CUSTS1_ATT_INFO_RSP,
                                                   src_id,
                                                   dest_id,
                                                   custs1_att_info_rsp);
    // Provide the connection index.
    rsp->conidx = app_env[param->conidx].conidx;
    // Provide the attribute index.
    rsp->att_idx = param->att_idx;
    // Force current length to zero.
    rsp->length = 0;
    // Provide the ATT error code.
    rsp->status = ATT_ERR_WRITE_NOT_PERMITTED;

    ke_msg_send(rsp);
}

void app_adcval1_timer_cb_handler()
{
    // struct custs1_val_ntf_ind_req *req = KE_MSG_ALLOC_DYN(CUSTS1_VAL_NTF_REQ,
    //                                                       prf_get_task_from_id(TASK_ID_CUSTS1),
    //                                                       TASK_APP,
    //                                                       custs1_val_ntf_ind_req,
    //                                                       DEF_SVC1_ADC_VAL_1_CHAR_LEN);

    // // ADC value to be sampled
    // static uint16_t sample __SECTION_ZERO("retention_mem_area0");
    // sample = (sample <= 0xffff) ? (sample + 1) : 0;

    // // req->conhdl = app_env->conhdl;
    // req->handle = SVC1_IDX_ADC_VAL_1_VAL;
    // req->length = DEF_SVC1_ADC_VAL_1_CHAR_LEN;
    // req->notification = true;
    // memcpy(req->value, &sample, DEF_SVC1_ADC_VAL_1_CHAR_LEN);

    // ke_msg_send(req);

    if (ke_state_get(TASK_APP) == APP_CONNECTED)
    {
        // Set it once again until Stop command is received in Control Characteristic
        timer_used = app_easy_timer(APP_PERIPHERAL_CTRL_TIMER_DELAY, app_adcval1_timer_cb_handler);
    }
}

void user_svc3_read_non_db_val_handler(ke_msg_id_t const msgid,
                                       struct custs1_value_req_ind const *param,
                                       ke_task_id_t const dest_id,
                                       ke_task_id_t const src_id)
{
    // Increase value by one
    non_db_val_counter++;

    // struct custs1_value_req_rsp *rsp = KE_MSG_ALLOC_DYN(CUSTS1_VALUE_REQ_RSP,
    //                                                     prf_get_task_from_id(TASK_ID_CUSTS1),
    //                                                     TASK_APP,
    //                                                     custs1_value_req_rsp,
    //                                                     DEF_SVC3_READ_VAL_4_CHAR_LEN);

    // // Provide the connection index.
    // rsp->conidx = app_env[param->conidx].conidx;
    // // Provide the attribute index.
    // rsp->att_idx = param->att_idx;
    // // Force current length to zero.
    // rsp->length = sizeof(non_db_val_counter);
    // // Provide the ATT error code.
    // rsp->status = ATT_ERR_NO_ERROR;
    // // Copy value
    // memcpy(&rsp->value, &non_db_val_counter, rsp->length);
    // // Send message
    // ke_msg_send(rsp);
}
