/**
 ****************************************************************************************
 *
 * @file user_custs1_def.c
 *
 * @brief Custom Server 1 (CUSTS1) profile database definitions.
 *
 * Copyright (C) 2016-2023 Renesas Electronics Corporation and/or its affiliates.
 * All rights reserved. Confidential Information.
 *
 * This software ("Software") is supplied by Renesas Electronics Corporation and/or its
 * affiliates ("Renesas"). Renesas grants you a personal, non-exclusive, non-transferable,
 * revocable, non-sub-licensable right and license to use the Software, solely if used in
 * or together with Renesas products. You may make copies of this Software, provided this
 * copyright notice and disclaimer ("Notice") is included in all such copies. Renesas
 * reserves the right to change or discontinue the Software at any time without notice.
 *
 * THE SOFTWARE IS PROVIDED "AS IS". RENESAS DISCLAIMS ALL WARRANTIES OF ANY KIND,
 * WHETHER EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. TO THE
 * MAXIMUM EXTENT PERMITTED UNDER LAW, IN NO EVENT SHALL RENESAS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE, EVEN IF RENESAS HAS BEEN ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGES. USE OF THIS SOFTWARE MAY BE SUBJECT TO TERMS AND CONDITIONS CONTAINED IN
 * AN ADDITIONAL AGREEMENT BETWEEN YOU AND RENESAS. IN CASE OF CONFLICT BETWEEN THE TERMS
 * OF THIS NOTICE AND ANY SUCH ADDITIONAL LICENSE AGREEMENT, THE TERMS OF THE AGREEMENT
 * SHALL TAKE PRECEDENCE. BY CONTINUING TO USE THIS SOFTWARE, YOU AGREE TO THE TERMS OF
 * THIS NOTICE.IF YOU DO NOT AGREE TO THESE TERMS, YOU ARE NOT PERMITTED TO USE THIS
 * SOFTWARE.
 *
 ****************************************************************************************
 */

/**
 ****************************************************************************************
 * @defgroup USER_CONFIG
 * @ingroup USER
 * @brief Custom server 1 (CUSTS1) profile database definitions.
 *
 * @{
 ****************************************************************************************
 */

/*
 * INCLUDE FILES
 ****************************************************************************************
 */

#include <stdint.h>
#include "co_utils.h"
#include "prf_types.h"
#include "attm_db_128.h"
#include "user_custs1_def.h"

/*
 * LOCAL VARIABLE DEFINITIONS
 ****************************************************************************************
 */

// Service 1 of the custom server 1
static const uint16_t custs1_svc1     = 0xff00;
static const uint16_t svc1_ctrl_point = 0xff03;
static const uint16_t svc1_adc_val1   = 0xff02;
static const uint16_t svc1_long_value = 0xff01;

/* Product BLE bridge: old Clock UUIDs, kept separate from the FF00 service. */
static const att_svc_desc128_t custs1_svc2 =
    {0x59, 0x5A, 0x08, 0xE4, 0x86, 0x2A, 0x9E, 0x8F,
     0xE9, 0x11, 0xBC, 0x7C, 0x98, 0x43, 0x42, 0x18};
static const uint8_t svc2_hink_write_uuid[ATT_UUID_128_LEN] =
    {0x20, 0xEE, 0x8D, 0x0C, 0xE1, 0xF0, 0x4A, 0x0C,
     0xB3, 0x25, 0xDC, 0x53, 0x6A, 0x68, 0x86, 0x2D};
static const uint8_t svc2_hink_notify_uuid[ATT_UUID_128_LEN] =
    {0x17, 0xB9, 0x67, 0x98, 0x4C, 0x66, 0x4C, 0x01,
     0x96, 0x33, 0x31, 0xB1, 0x91, 0x59, 0x00, 0x15};

// Attribute specifications
static const uint16_t att_decl_svc       = ATT_DECL_PRIMARY_SERVICE;
static const uint16_t att_decl_char      = ATT_DECL_CHARACTERISTIC;
static const uint16_t att_desc_cfg       = ATT_DESC_CLIENT_CHAR_CFG;

/*
 * GLOBAL VARIABLE DEFINITIONS
 ****************************************************************************************
 */

const uint8_t custs1_services[]  = {SVC1_IDX_SVC, SVC2_IDX_SVC, CUSTS1_IDX_NB};
const uint8_t custs1_services_size = ARRAY_LEN(custs1_services) - 1;
const uint16_t custs1_att_max_nb = CUSTS1_IDX_NB;


/// Full CUSTS1 Database Description - Used to add attributes into the database
const struct attm_desc_128 custs1_att_db[CUSTS1_IDX_NB] =
{
    /*************************
     * Service 1 configuration
     *************************
     */

    // Service 1 Declaration
    [SVC1_IDX_SVC]                     = {(uint8_t*)&att_decl_svc, ATT_UUID_16_LEN, PERM(RD, ENABLE),
                                            sizeof(custs1_svc1), sizeof(custs1_svc1), (uint8_t*)&custs1_svc1},

    // Control Point Characteristic Declaration
    [SVC1_IDX_CONTROL_POINT_CHAR]      = {(uint8_t*)&att_decl_char, ATT_UUID_16_LEN, PERM(RD, ENABLE), 0, 0, NULL},
    // Control Point Characteristic Value
    [SVC1_IDX_CONTROL_POINT_VAL]       = {(uint8_t*)&svc1_ctrl_point, ATT_UUID_16_LEN, PERM(WR, ENABLE) | PERM(WRITE_REQ, ENABLE),
                                            DEF_SVC1_CTRL_POINT_CHAR_LEN, 0, 0},

    // ADC Value 1 Characteristic Declaration
    [SVC1_IDX_ADC_VAL_1_CHAR]          = {(uint8_t*)&att_decl_char, ATT_UUID_16_LEN, PERM(RD, ENABLE), 0, 0, NULL},
    // ADC Value 1 Characteristic Value
    [SVC1_IDX_ADC_VAL_1_VAL]           = {(uint8_t*)&svc1_adc_val1, ATT_UUID_16_LEN, PERM(RD, ENABLE),
											PERM(RI, ENABLE) | DEF_SVC1_ADC_VAL_1_CHAR_LEN, 0, 0},

    // Long Value Characteristic Declaration
    [SVC1_IDX_LONG_VALUE_CHAR]         = {(uint8_t*)&att_decl_char, ATT_UUID_16_LEN, PERM(RD, ENABLE), 0, 0, NULL},
    // Long Value Characteristic Value
    [SVC1_IDX_LONG_VALUE_VAL]          = {(uint8_t*)&svc1_long_value, ATT_UUID_16_LEN, PERM(RD, ENABLE) | PERM(WR, ENABLE) | PERM(WRITE_REQ, ENABLE),
                                            DEF_SVC1_LONG_VALUE_CHAR_LEN, 0, 0},

    /*************************
     * HINK Clock bridge service
     *************************/
    [SVC2_IDX_SVC] = {(uint8_t*)&att_decl_svc, ATT_UUID_128_LEN, PERM(RD, ENABLE),
                      sizeof(custs1_svc2), sizeof(custs1_svc2), (uint8_t*)&custs1_svc2},

    [SVC2_IDX_HINK_WRITE_CHAR] = {(uint8_t*)&att_decl_char, ATT_UUID_16_LEN, PERM(RD, ENABLE),
                                  0, 0, NULL},
    [SVC2_IDX_HINK_WRITE_VAL] = {(uint8_t*)svc2_hink_write_uuid, ATT_UUID_128_LEN,
                                 PERM(WR, ENABLE) | PERM(WRITE_REQ, ENABLE),
                                 DEF_SVC2_HINK_WRITE_CHAR_LEN, 0, 0},

    [SVC2_IDX_HINK_NOTIFY_CHAR] = {(uint8_t*)&att_decl_char, ATT_UUID_16_LEN, PERM(RD, ENABLE),
                                   0, 0, NULL},
    [SVC2_IDX_HINK_NOTIFY_VAL] = {(uint8_t*)svc2_hink_notify_uuid, ATT_UUID_128_LEN,
                                  PERM(RD, ENABLE) | PERM(NTF, ENABLE),
                                  DEF_SVC2_HINK_NOTIFY_CHAR_LEN, 0, 0},
    [SVC2_IDX_HINK_NOTIFY_NTF_CFG] = {(uint8_t*)&att_desc_cfg, ATT_UUID_16_LEN,
                                      PERM(RD, ENABLE) | PERM(WR, ENABLE) | PERM(WRITE_REQ, ENABLE),
                                      sizeof(uint16_t), 0, 0},};

/// @} USER_CONFIG
