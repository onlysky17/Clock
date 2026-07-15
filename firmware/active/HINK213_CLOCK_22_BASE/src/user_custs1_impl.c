/**
 ****************************************************************************************
 *
 * @file user_custs1_impl.c
 *
 * @brief Peripheral project Custom1 Server implementation source code.
 *
 * Copyright (C) 2015-2023 Renesas Electronics Corporation and/or its affiliates.
 * All rights reserved. Confidential Information.
 *
 * This software ("Software") is supplied by Renesas Electronics Corporation and/or its
 * affiliates ("Renesas"). Renesas grants you a personal, non-exclusive, non-transferable,
 * revocable, non-sub-licensable right and license to use the Software, solely if used in
 * or together with Renesas products. You may make copies of this Software, provided this
 * copyright notice and disclaimer ("Notice") is included in all such copies.Â Renesas
 * reserves the right to change or discontinue the Software at any time without notice.
 *
 * THE SOFTWARE IS PROVIDED "AS IS". RENESAS DISCLAIMS ALL WARRANTIES OF ANY KIND,
 * WHETHER EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT.Â TO THE
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

/*
 * INCLUDE FILES
 ****************************************************************************************
 */

#include "gpio.h"               // GPIOæŽ§åˆ¶ç›¸å…³å¤´æ–‡ä»¶
#include "app_api.h"            // åº”ç”¨ç¨‹åºAPI
#include "app.h"                // åº”ç”¨ç¨‹åºæ ¸å¿ƒåŠŸèƒ½
#include "prf_utils.h"          // BLEé…ç½®æ–‡ä»¶å·¥å…·
#include "custs1.h"             // è‡ªå®šä¹‰æœåŠ¡1
#include "custs1_task.h"        // è‡ªå®šä¹‰æœåŠ¡1ä»»åŠ¡
#include "user_custs1_def.h"    // è‡ªå®šä¹‰æœåŠ¡1å®šä¹‰
#include "user_custs1_impl.h"   // è‡ªå®šä¹‰æœåŠ¡1å®žçŽ°
#include "user_peripheral.h"    // ç”¨æˆ·å¤–è®¾ç›¸å…³
#include "user_periph_setup.h"  // ç”¨æˆ·å¤–è®¾è®¾ç½®
#include "adc.h"                // ADC(æ¨¡æ•°è½¬æ¢)ç›¸å…³

#include "epd.h"                // ç”µå­å¢¨æ°´å±é©±åŠ¨

/*
 * å…¨å±€å˜é‡å®šä¹‰
 * è¿™äº›å˜é‡ä½¿ç”¨__SECTION_ZERO("retention_mem_area0")å±žæ€§æ”¾ç½®åœ¨æŽ‰ç”µä¿æŒå†…å­˜åŒºåŸŸ
 ****************************************************************************************
 */

// å®šæ—¶å™¨IDï¼Œç”¨äºŽç³»ç»Ÿå®šæ—¶ä»»åŠ¡
ke_msg_id_t timer_used      __SECTION_ZERO("retention_mem_area0"); //@RETENTION MEMORY
// æŒ‡ç¤ºè®¡æ•°å™¨ï¼Œç”¨äºŽBLEé€šçŸ¥è®¡æ•°
uint16_t indication_counter __SECTION_ZERO("retention_mem_area0"); //@RETENTION MEMORY
// éžæ•°æ®åº“å€¼è®¡æ•°å™¨
uint16_t non_db_val_counter __SECTION_ZERO("retention_mem_area0"); //@RETENTION MEMORY
// ADCé‡‡æ ·å€¼ï¼Œç”¨äºŽç”µæ± ç”µé‡æ£€æµ‹
int adcval;

/* TASK B: bounded E4 command session over the HINK 128-bit BLE service. */
static uint8_t hink_e4_conidx               __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_e4_session_active       __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_e4_session_token        __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_e4_session_owner_conidx __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_e4_timer_running        __SECTION_ZERO("retention_mem_area0");
static ke_msg_id_t hink_e4_timer            __SECTION_ZERO("retention_mem_area0");
static uint8_t h24_format = 1; // 24å°æ—¶åˆ¶æ ‡å¿—

#define HINK_E5_WIDTH          EPD_FRAME_WIDTH
#define HINK_E5_HEIGHT         EPD_FRAME_HEIGHT
#define HINK_E5_STRIDE         EPD_FRAME_STRIDE
#define HINK_E5_TOTAL_BYTES    EPD_FRAME_BYTES
#define HINK_E5_CHUNK_MAX      14U
#define HINK_E5_TOTAL_CHUNKS   286U
#define HINK_E5_STAGING_BUFFER fb_bw
#define HINK_E5_STATE_NONE     0U
#define HINK_E5_STATE_ACTIVE   1U
#define HINK_E5_STATE_COMPLETE 2U

#define HINK_E5_STATUS_OK             0x00
#define HINK_E5_STATUS_INVALID        0x01
#define HINK_E5_STATUS_NOT_OPEN       0x02
#define HINK_E5_STATUS_WRONG_OWNER    0x03
#define HINK_E5_STATUS_BAD_GEOMETRY   0x04
#define HINK_E5_STATUS_BAD_ID         0x05
#define HINK_E5_STATUS_BAD_SEQUENCE   0x06
#define HINK_E5_STATUS_OVERFLOW       0x07
#define HINK_E5_STATUS_BAD_COUNT      0x08
#define HINK_E5_STATUS_BAD_CRC        0x09
#define HINK_E5_STATUS_UNSUPPORTED    0x0A

static uint8_t hink_e5_state;
static uint8_t hink_e5_transfer_id;
static uint16_t hink_e5_next_seq;
static uint16_t hink_e5_bytes;
static uint16_t hink_e5_crc;

#define HINK_E6_STATE_IDLE               0x00
#define HINK_E6_STATE_ACCEPTED_PENDING   0x01
#define HINK_E6_STATE_REFRESHING         0x02
#define HINK_E6_STATE_COMPLETE           0x03
#define HINK_E6_STATE_ERROR              0x04

static uint8_t hink_e6_state             __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_e6_transfer_id       __SECTION_ZERO("retention_mem_area0");
static timer_hnd hink_e6_timer_hnd       __SECTION_ZERO("retention_mem_area0");

#define HINK_D2_SET_TIME_LEN        9U
#define HINK_D2_GET_STATUS_LEN      2U
#define HINK_D2_STATUS_LEN          15U
#define HINK_D2_EPOCH_MIN           1704067200UL
#define HINK_D2_EPOCH_MAX           4102444799UL
#define HINK_D2_STALE_SECONDS       86400UL
#define HINK_D2_FLAGS_RESERVED_MASK 0xFCU

#define HINK_D2_RESULT_OK             0x00U
#define HINK_D2_RESULT_INVALID_LENGTH 0x01U
#define HINK_D2_RESULT_INVALID_FLAGS  0x02U
#define HINK_D2_RESULT_INVALID_TIME   0x03U
#define HINK_D2_RESULT_NOT_INIT       0x04U
#define HINK_D2_RESULT_INTERNAL       0x05U

#define HINK_D2_STATE_UNSET   0x00U
#define HINK_D2_STATE_SYNCED  0x01U
#define HINK_D2_STATE_RUNNING 0x02U
#define HINK_D2_STATE_STALE   0x03U

static uint32_t hink_d2_uptime_seconds     __SECTION_ZERO("retention_mem_area0");
static uint32_t hink_d2_synced_epoch       __SECTION_ZERO("retention_mem_area0");
static uint32_t hink_d2_uptime_at_sync     __SECTION_ZERO("retention_mem_area0");
static int16_t hink_d2_timezone_minutes    __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_d2_flags               __SECTION_ZERO("retention_mem_area0");

static void hink_e6_timer_cb(void);

static void get_holiday(void);
static void hink_e4_arm_timer(void);

extern int adv_state;
/*
 * FUNCTION DEFINITIONS
 ****************************************************************************************
 */


/**
 * @brief æ›´æ–°ADCé‡‡æ ·å€¼å¹¶é€šè¿‡BLEå‘é€ç”µæ± ç”µåŽ‹æ•°æ®
 * 
 * è¯¥å‡½æ•°æ‰§è¡Œä»¥ä¸‹æ“ä½œï¼š
 * 1. æ ¡å‡†ADCåç§»é‡
 * 2. èŽ·å–ç”µæ± ç”µåŽ‹é‡‡æ ·å€¼
 * 3. å°†é‡‡æ ·å€¼è½¬æ¢ä¸ºå®žé™…ç”µåŽ‹å€¼
 * 4. é€šè¿‡BLEå‘é€ç”µåŽ‹å€¼ç»™è¿žæŽ¥çš„è®¾å¤‡
 * 
 * @return è¿”å›žè®¡ç®—åŽçš„ç”µåŽ‹å€¼
 */
int adc1_update(void)
{
    return 0;
}


/****************************************************************************************/

/**
 * å†œåŽ†å¹´ä»½æ•°æ®è¡¨ï¼ˆ2020-2051å¹´ï¼‰
 * æ¯ä¸ª16ä½æ•°æ®åŒ…å«ä»¥ä¸‹ä¿¡æ¯ï¼š
 * - é«˜4ä½(bit 15-12): é—°æœˆæœˆä»½ï¼Œ0è¡¨ç¤ºå½“å¹´æ— é—°æœˆ
 * - ä½Ž12ä½(bit 11-0): æ¯ä¸ªæœˆçš„å¤§å°æœˆæ ‡è®°ï¼Œ1è¡¨ç¤ºå¤§æœˆ(30å¤©)ï¼Œ0è¡¨ç¤ºå°æœˆ(29å¤©)
 * ä¾‹å¦‚ï¼š0x07954
 * - 0: æ— é—°æœˆ
 * - 7954: ä»Žæ­£æœˆåˆ°åäºŒæœˆçš„å¤§å°æœˆæƒ…å†µ
 */
static const uint16_t lunar_year_info[32] =
{
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530, //2020-2029
    0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x0d0b6, 0x0d250, 0x0d520, 0x0dd45, //2030-2039
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x0b255, 0x06d20, 0x0ada0, //2040-2049
    0x04b63, 0x09370,                                                                         //2050-2051
};

// é¢å¤–çš„å†œåŽ†å¹´ä»½ä¿¡æ¯ï¼Œç”¨äºŽæ ‡è®°ç‰¹æ®Šå¹´ä»½çš„é—°æœˆæƒ…å†µ
static const uint32_t lunar_year_info2 = 0x48010000;


/**
 * 24èŠ‚æ°”æ—¶é—´æ•°æ®è¡¨
 * å­˜å‚¨äº†ä¸€å¹´ä¸­24ä¸ªèŠ‚æ°”ç›¸å¯¹äºŽ"å°å¯’"çš„æ—¶é—´é—´éš”ï¼ˆä»¥ç§’ä¸ºå•ä½ï¼‰
 * 
 * èŠ‚æ°”é¡ºåºï¼š
 * 1-6æœˆï¼šå°å¯’ã€å¤§å¯’ã€ç«‹æ˜¥ã€é›¨æ°´ã€æƒŠè›°ã€æ˜¥åˆ†
 * 7-12æœˆï¼šæ¸…æ˜Žã€è°·é›¨ã€ç«‹å¤ã€å°æ»¡ã€èŠ’ç§ã€å¤è‡³
 * 13-18æœˆï¼šå°æš‘ã€å¤§æš‘ã€ç«‹ç§‹ã€å¤„æš‘ã€ç™½éœ²ã€ç§‹åˆ†
 * 19-24æœˆï¼šå¯’éœ²ã€éœœé™ã€ç«‹å†¬ã€å°é›ªã€å¤§é›ªã€å†¬è‡³
 */
static int jieqi_info[] =
{
    0,        1272283,  2547462,  3828568,  5117483,  6416376,  // å°å¯’åˆ°æ˜¥åˆ†
    7726093,  9047327,  10379235, 11721860, 13072410, 14428379, // æ¸…æ˜Žåˆ°å¤è‡³
    15787551, 17145937, 18501082, 19850188, 21190911, 22520708, // å°æš‘åˆ°ç§‹åˆ†
    23839844, 25146961, 26443845, 27730671, 29010666, 30284551, // å¯’éœ²åˆ°å†¬è‡³
};

/**
 * 2020å¹´"å°å¯’"èŠ‚æ°”çš„åŸºå‡†æ—¶é—´
 * ç›¸å¯¹äºŽ2020å¹´1æœˆ1æ—¥çš„ç§’æ•°
 * ç”¨äºŽè®¡ç®—å…¶ä»–å¹´ä»½çš„èŠ‚æ°”æ—¶é—´
 */
#define xiaohan_2020  451804


/**
 * å…¨å±€æ—¶é—´å˜é‡å®šä¹‰
 * å…¬åŽ†æ—¥æœŸç›¸å…³å˜é‡ï¼š
 * year: å¹´ä»½ï¼Œå¦‚2025
 * month: æœˆä»½ï¼Œ0-11è¡¨ç¤º1-12æœˆ
 * date: æ—¥æœŸï¼Œ0-30è¡¨ç¤º1-31æ—¥
 * wday: æ˜ŸæœŸï¼Œ0-6è¡¨ç¤ºæ˜ŸæœŸæ—¥åˆ°æ˜ŸæœŸå…­
 * 
 * å†œåŽ†æ—¥æœŸç›¸å…³å˜é‡ï¼š
 * l_year: å†œåŽ†å¹´åœ¨lunar_year_infoæ•°ç»„ä¸­çš„ç´¢å¼•ï¼Œå¦‚4è¡¨ç¤º2024å¹´
 * l_month: å†œåŽ†æœˆä»½ï¼Œ0-11è¡¨ç¤ºæ­£æœˆåˆ°è…Šæœˆï¼Œæœ€é«˜ä½1è¡¨ç¤ºé—°æœˆ
 * l_date: å†œåŽ†æ—¥æœŸï¼Œ0-29è¡¨ç¤ºåˆä¸€åˆ°ä¸‰å
 * 
 * æ—¶é—´ç›¸å…³å˜é‡ï¼š
 * hour: å°æ—¶ï¼Œ0-23
 * minute: åˆ†é’Ÿï¼Œ0-59
 * second: ç§’ï¼Œ0-59
 */
int year=2025, month=0, date=0, wday=3;
int l_year=4, l_month=11, l_date=1;
int hour=0, minute=0, second=0;
// ä¸Šæ¬¡å¯¹æ—¶åŽï¼Œç»è¿‡çš„åˆ†é’Ÿæ•°
int cal_minute=-1;


//GUIQRLB
// æ¥è‡ª pic.py è‡ªåŠ¨ç”Ÿæˆçš„ C æ•°ç»„
const unsigned char QR_31x31[31][4] = {
    {0x00, 0x00, 0x00, 0x00},
    {0x7F, 0x1E, 0x99, 0xFC},
    {0x41, 0x3B, 0xC5, 0x04},
    {0x5D, 0x5D, 0x6D, 0x74},
    {0x5D, 0x11, 0x9D, 0x74},
    {0x5D, 0x63, 0xD1, 0x74},
    {0x41, 0x43, 0x59, 0x04},
    {0x7F, 0x55, 0x55, 0xFC},
    {0x00, 0x06, 0xB0, 0x00},
    {0x25, 0x43, 0x96, 0xD0},
    {0x74, 0x55, 0x2C, 0x74},
    {0x7B, 0xB1, 0x22, 0xC4},
    {0x5E, 0xB4, 0xE2, 0xE4},
    {0x53, 0xBA, 0x6E, 0x98},
    {0x72, 0x54, 0xE1, 0xF4},
    {0x0B, 0xC8, 0xD5, 0x1C},
    {0x32, 0xEA, 0xCD, 0x20},
    {0x7B, 0x13, 0xCC, 0x4C},
    {0x4A, 0xC0, 0x1A, 0x9C},
    {0x1B, 0x55, 0xB5, 0x7C},
    {0x1A, 0x8E, 0xF5, 0x54},
    {0x77, 0xBD, 0x27, 0xE0},
    {0x00, 0x6B, 0xDC, 0x74},
    {0x7F, 0x0A, 0xED, 0x54},
    {0x41, 0x1B, 0x3C, 0x64},
    {0x5D, 0x55, 0x9F, 0xE4},
    {0x5D, 0x3E, 0x48, 0x38},
    {0x5D, 0x2B, 0x4E, 0x0C},
    {0x41, 0x60, 0x20, 0x2C},
    {0x7F, 0x0D, 0xB0, 0xC8},
    {0x00, 0x00, 0x00, 0x00},
};

const unsigned char LB_31x31[31][4] = {
    {0x00, 0x00, 0x00, 0x00},
    {0x00, 0x00, 0x00, 0x00},
    {0x00, 0x07, 0xC0, 0x00},
    {0x00, 0x04, 0x40, 0x00},
    {0x00, 0xFF, 0xFE, 0x00},
    {0x00, 0x80, 0x02, 0x00},
    {0x01, 0x80, 0x03, 0x00},
    {0x01, 0x00, 0x01, 0x00},
    {0x01, 0x00, 0x01, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x00, 0x01, 0x00},
    {0x01, 0x00, 0x01, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x03, 0x81, 0x00},
    {0x01, 0x00, 0x01, 0x00},
    {0x01, 0x00, 0x01, 0x00},
    {0x01, 0xC0, 0x07, 0x00},
    {0x00, 0x40, 0x04, 0x00},
    {0x00, 0x7F, 0xFC, 0x00},
    {0x00, 0x00, 0x00, 0x00},
    {0x00, 0x00, 0x00, 0x00},
    {0x00, 0x00, 0x00, 0x00},
};


/**
 * èŽ·å–å†œåŽ†æœˆä»½çš„å¤©æ•°
 * 
 * @param mon æœˆä»½ç¼–å·ï¼Œæœ€é«˜ä½ä¸º1è¡¨ç¤ºé—°æœˆ
 * @param yinfo_out è¾“å‡ºå‚æ•°ï¼Œç”¨äºŽè¿”å›žå¹´ä»½ä¿¡æ¯
 * @return è¿”å›žè¯¥æœˆçš„å¤©æ•°ï¼ˆ29æˆ–30ï¼‰
 */
static int get_lunar_mdays(int mon, int *yinfo_out)
{
    // èŽ·å–é—°æœˆæ ‡å¿—ï¼ˆæœ€é«˜ä½ï¼‰
    int lflag = mon&0x80;
    // èŽ·å–å®žé™…æœˆä»½ï¼ˆåŽ»é™¤é—°æœˆæ ‡å¿—ï¼‰
    mon &= 0x7f;

	// å–å¾—å½“å¹´çš„ä¿¡æ¯
	int yinfo = lunar_year_info[l_year];
	if(lunar_year_info2&(1<<l_year))
		yinfo |= 0x10000;

	// å–å¾—å½“æœˆçš„å¤©æ•°
	int mdays = 29;
	if(lflag){
		if(yinfo&0x10000) mdays += 1;
	}else{
		if(yinfo&(0x8000>>mon))	mdays += 1;
	}

	if(yinfo_out)
		*yinfo_out = yinfo;
	return mdays;
}


// å†œåŽ†å¢žåŠ ä¸€å¤©
void ldate_inc(void)
{
	int lflag = l_month&0x80;
	int mon = l_month&0x7f;
	int yinfo;

	int mdays = get_lunar_mdays(l_month, &yinfo);

	l_date += 1;
	if(l_date==mdays){
		l_date = 0;
		mon += 1;
		if(lflag==0 && mon==(yinfo&0x0f)){
			lflag = 0x80;
			mon -= 1;
		}else{
			lflag = 0;
		}
		if(mon==12){
			mon = 0;
			l_year += 1;
		}
		l_month = lflag|mon;
	}
}


// ç»™å‡ºå¹´æœˆæ—¥ï¼Œè¿”å›žæ˜¯å¦æ˜¯èŠ‚æ°”æ—¥
int jieqi(int year, int month, int date)
{
	uint8_t d2m[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
	int is_leap = (year%4)? 0 : (year%100)? 1: (year%400)? 0: 1;
	d2m[1] += is_leap;

	// è®¡ç®—å½“å‰æ—¥æœŸæ˜¯æœ¬å¹´ç¬¬å‡ å¤©
	int i, d=0;
	for(i=0; i<month; i++){
		d += d2m[i];
	}
	d += date;

	// è®¡ç®—é—°å¹´çš„å¤©æ•°ã€‚å› ä¸ºåªè€ƒè™‘2020-2052å¹´ï¼Œè¿™é‡Œåšäº†ç®€åŒ–ã€‚
	int Y = year-2020;
	int L = (Y)? (Y-1)/4+1 : 0;
	// è®¡ç®—å½“å¹´å°å¯’çš„ç§’æ•°
	int xiaohan_sec = xiaohan_2020 + 20950*Y - L*86400;
	//    20926æ˜¯ä¸€ä¸ªå›žå½’å¹´(365.2422)ä¸è¶³ä¸€å¤©çš„ç§’æ•°(.2422*86400).
	//    ç›´æŽ¥ç”¨æœ‰æ˜Žæ˜¾çš„è¯¯å·®ã€‚è¿™é‡Œç¨å¾®å¢žå¤§äº†ä¸€ç‚¹(20926+24)ã€‚

	for(i=0; i<24; i++){
		int sec = xiaohan_sec + jieqi_info[i];
		int day = sec/86400;
		if(day==d)
			return i;
	}

	return -1;
}


/****************************************************************************************/


static int get_month_day(int mon)
{
	uint8_t d2m[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
	int is_leap = (year%4)? 0 : (year%100)? 1: (year%400)? 0: 1;
	d2m[1] += is_leap;

	return d2m[month];
}


// å¢žåŠ 1å¤©
void date_inc(void)
{
	wday += 1;
	if(wday>=7)
		wday = 0;
	
	date += 1;
	if(date==get_month_day(month)){
		date = 0;
		month += 1;
		if(month>=12){
			month = 0;
			year += 1;
		}
	}
}

// 0: çŠ¶æ€ä¸å˜
// 1: åˆ†é’Ÿæ”¹å˜
// 2: åˆ†é’Ÿæ”¹å˜10åˆ†é’Ÿ
// 3: å°æ—¶æ”¹å˜
// 4: å¤©æ•°æ”¹å˜

int clock_update(int inc)
{
	int retv = 0;

    if (inc > 0)
    {
        hink_d2_uptime_seconds += (uint32_t)inc;
    }

	second += inc;
	if(second<60)
		return retv;
	second -= 60;

	minute += 1;
	retv = 1;
	if((minute%10)==0)
		retv = 2;

	if(cal_minute>=0)
		cal_minute += 1;

	if(minute>=60){
		minute = 0;
		hour += 1;
		retv = 3;
		if(hour>=24){
			hour = 0;
			date_inc();
			ldate_inc();
			get_holiday();
			retv = 4;
		}
	}

	return retv;
}

void clock_set(uint8_t *buf)
{
	year   = buf[1] + buf[2]*256;
	month  = buf[3];
	date   = buf[4]-1;
	hour   = buf[5];
	minute = buf[6];
	second = buf[7];
	wday   = buf[8];
	l_year = buf[9];
	l_month= buf[10];
	l_date = buf[11]-1;

	get_holiday();

	cal_minute = 0;

	app_clock_timer_restart();
}


void clock_push(void)
{
}


void clock_print(void)
{
}


/****************************************************************************************/

static char *jieqi_name[] = {
	"å°å¯’", "å¤§å¯’", "ç«‹æ˜¥", "é›¨æ°´", "æƒŠè›°", "æ˜¥åˆ†",
	"æ¸…æ˜Ž", "è°·é›¨", "ç«‹å¤", "å°æ»¡", "èŠ’ç§", "å¤è‡³",
	"å°æš‘", "å¤§æš‘", "ç«‹ç§‹", "å¤„æš‘", "ç™½éœ²", "ç§‹åˆ†",
	"å¯’éœ²", "éœœé™", "ç«‹å†¬", "å°é›ª", "å¤§é›ª", "å†¬è‡³",
};
static char *wday_str[] = {"æ—¥", "ä¸€", "äºŒ", "ä¸‰", "å››", "äº”", "å…­"};
static char *lday_str_lo[] = {"ä¸€", "äºŒ", "ä¸‰", "å››", "äº”", "å…­", "ä¸ƒ", "å…«", "ä¹", "å", "å†¬", "è…Š", "æ­£"};
static char *lday_str_hi[] = {"åˆ", "å", "å»¿", "äºŒ", "ä¸‰"};

static int epd_wait_state;
static timer_hnd epd_wait_hnd;

typedef struct {
    char *name;
    uint8_t mon;
    uint8_t day;
}HOLIDAY_INFO;

HOLIDAY_INFO hday_info[] = {
    // å†œåŽ†ä¼ ç»ŸèŠ‚æ—¥ï¼ˆ0x80 è¡¨ç¤ºå†œåŽ†æ—¥æœŸï¼Œ0xc0 è¡¨ç¤ºæœˆæœ«ï¼‰
    {"è…Šå…«",     0x80|12,  8},   // å†œåŽ†è…Šæœˆåˆå…«
    {"å°å¹´",     0x80|12, 23},   // å†œåŽ†è…Šæœˆå»¿ä¸‰
    {"é™¤å¤•",     0xc0|12, 30},   // å†œåŽ†è…Šæœˆæœ€åŽä¸€å¤©
    {"æ˜¥èŠ‚",     0x80| 1,  1},   // å†œåŽ†æ­£æœˆåˆä¸€
    {"å…ƒå®µèŠ‚",   0x80| 1, 15},   // å†œåŽ†æ­£æœˆåäº”
    {"é¾™æŠ¬å¤´",   0x80| 2,  2},   // å†œåŽ†äºŒæœˆåˆäºŒ
    {"å¯’é£ŸèŠ‚",   0x80| 3,  3},   // å†œåŽ†ä¸‰æœˆåˆä¸‰
    {"ç«¯åˆèŠ‚",   0x80| 5,  5},   // å†œåŽ†äº”æœˆåˆäº”
    {"ä¸ƒå¤•èŠ‚",   0x80| 7,  7},   // å†œåŽ†ä¸ƒæœˆåˆä¸ƒ
    {"ä¸­å…ƒèŠ‚",   0x80| 7, 15},   // å†œåŽ†ä¸ƒæœˆåäº”
    {"ä¸­ç§‹èŠ‚",   0x80| 8, 15},   // å†œåŽ†å…«æœˆåäº”
    {"é‡é˜³èŠ‚",   0x80| 9,  9},   // å†œåŽ†ä¹æœˆåˆä¹
    {"ä¸‹å…ƒèŠ‚",   0x80|10, 15},   // å†œåŽ†åæœˆåäº”

    // é˜³åŽ†æ³•å®šèŠ‚å‡æ—¥å’Œçºªå¿µæ—¥
    {"å…ƒæ—¦",         1,  1},
    {"æ¹¿åœ°æ—¥",       2,  2},
    {"æƒ…äººèŠ‚",       2, 14},
    {"å¦‡å¥³èŠ‚",       3,  8},
    {"æ¤æ ‘èŠ‚",       3, 12},
    {"æƒç›Šæ—¥",       3, 15},
    {"æ„šäººèŠ‚",       4,  1},
    {"è¯»ä¹¦æ—¥",       4, 23},
    {"èˆªå¤©æ—¥",       4, 24},
    {"åŠ³åŠ¨èŠ‚",       5,  1},
    {"é’å¹´èŠ‚",       5,  4},
    {"æŠ¤å£«èŠ‚",       5, 12},
    {"å„¿ç«¥èŠ‚",       6,  1},
    {"çŽ¯å¢ƒæ—¥",       6,  5},
    {"é—äº§æ—¥",       6,  8},
    {"å»ºå…šèŠ‚",       7,  1},
    {"å»ºå†›èŠ‚",       8,  1},
    {"æŠ—æˆ˜æ—¥",       9,  3},
    {"æ•™å¸ˆèŠ‚",       9, 10},
    {"å®‰å…¨æ—¥",       9, 15},
    {"çƒˆå£«æ—¥",       9, 30},
    {"å›½åº†èŠ‚",      10,  1},
	{"ç¨‹åºå‘˜èŠ‚",    10, 24},
	{"ä¸‡åœ£èŠ‚",      10, 31},
    {"æ¶ˆé˜²æ—¥",      11,  9},
    {"è®°è€…èŠ‚",      11,  8},
	{"å…‰æ£èŠ‚",      11, 11},
    {"å®ªæ³•æ—¥",      12,  4},
    {"å¿—æ„¿æ—¥",      12,  5},
    {"å…¬ç¥­æ—¥",      12, 13},
	{"åœ£è¯žèŠ‚",      12, 25},

    // ç‰¹æ®Šå‘¨æœŸæ€§èŠ‚æ—¥
    {"æ¯äº²èŠ‚",       5, 0x97},  // 5æœˆç¬¬äºŒä¸ªå‘¨æ—¥
    {"çˆ¶äº²èŠ‚",       6, 0xa7},  // 6æœˆç¬¬ä¸‰ä¸ªå‘¨æ—¥
    {"æ„Ÿæ©èŠ‚",      11, 0xa4},  // 11æœˆç¬¬å››ä¸ªå‘¨å››

    {"",             0,  0}     // ç»“æŸæ ‡è®°
};


static char *jieqi_str = "å°å¯’";
static char *holiday_str = "å…ƒæ—¦";

static void ldate_str(char *buf)
{
	char *lflag = (l_month&0x80)? "é—°" : "";
	int lm = l_month&0x7f;
	if(lm==0){
		lm = 12;
	}

	int hi = l_date/10;
	int lo = l_date%10;
	
	if(lo==9){
		if(hi==1)
			hi = 3;
		else if(hi==2)
			hi = 4;
	}
	
	sprintf(buf, "%s%sæœˆ%s%s", lflag, lday_str_lo[lm], lday_str_hi[hi], lday_str_lo[lo]);
}


static void set_holiday(int index)
{
	if(holiday_str==NULL){
		holiday_str = hday_info[index].name;
	}else if(jieqi_str==NULL){
		// å·²ç»æœ‰ä¸€ä¸ªå†œåŽ†èŠ‚æ—¥äº†ï¼Œå°†å…¶è½¬ç§»åˆ°èŠ‚æ°”ä½ç½®ã€‚
		jieqi_str = holiday_str;
		holiday_str = hday_info[index].name;
	}else{
		// printf("OOPS! èŠ‚æ—¥æº¢å‡º!\n");
	}
}

void get_holiday(void)
{
	int i;

	jieqi_str = NULL;
	holiday_str = NULL;

	i = jieqi(year, month, date);
	if(i>=0){
		jieqi_str = jieqi_name[i];
	}

	i = 0;
	while(hday_info[i].mon){
		int mon = hday_info[i].mon;
		int day = hday_info[i].day;
		int mflag = mon&0xc0;
		int dflag = day;
		mon = (mon&0x0f)-1;
		day = (day&0x1f)-1;
		if(mflag&0x80){
			// å†œåŽ†èŠ‚æ—¥
			if(mflag&0x40){
				// å½“æœˆæœ€åŽä¸€å¤©
				int mdays = get_lunar_mdays(l_month, NULL);
				day = mdays-1;
			}
			if(l_month==mon && l_date==day){
				set_holiday(i);
			}
		}else{
			// å…¬åŽ†èŠ‚æ—¥
			if(dflag&0x80){
				// ç¬¬å‡ ä¸ªå‘¨å¤©
				int wc = date/7;
				int hwc = (dflag>>4)&0x03;
				day &= 0x07;
				if(month==mon && wc==hwc && wday==day){
					set_holiday(i);
				}
			}else if(month==mon && date==day){
				set_holiday(i);
			}
		}
		i += 1;
	}

	return;
}


/****************************************************************************************/


static uint8_t batt_cal(uint16_t adc_sample)
{
    uint8_t batt_lvl;

    if (adc_sample > 1705)
        batt_lvl = 100;
    else if (adc_sample <= 1705 && adc_sample > 1584)
        batt_lvl = 28 + (uint8_t)(( ( ((adc_sample - 1584) << 16) / (1705 - 1584) ) * 72 ) >> 16) ;
    else if (adc_sample <= 1584 && adc_sample > 1360)
        batt_lvl = 4 + (uint8_t)(( ( ((adc_sample - 1360) << 16) / (1584 - 1360) ) * 24 ) >> 16) ;
    else if (adc_sample <= 1360 && adc_sample > 1136)
        batt_lvl = (uint8_t)(( ( ((adc_sample - 1136) << 16) / (1360 - 1136) ) * 4 ) >> 16) ;
    else
        batt_lvl = 0;

    return batt_lvl;
}


/**
 * ç»˜åˆ¶ç”µæ± ç”µé‡å›¾æ ‡
 * 
 * @param x å›¾æ ‡å·¦ä¸Šè§’çš„xåæ ‡
 * @param y å›¾æ ‡ä¸­å¿ƒçš„yåæ ‡
 * 
 * å›¾æ ‡è¯´æ˜Žï¼š
 * - å¤–æ¡†å¤§å°ï¼š16x8åƒç´ 
 * - ç”µé‡æ˜¾ç¤ºï¼šæ ¹æ®å®žé™…ç”µé‡ç™¾åˆ†æ¯”å¡«å……å†…éƒ¨
 * - ç”µæ± æ­£æžï¼š2x2åƒç´ 
 */
static void draw_batt(int x, int y)
{
    // èŽ·å–ç”µæ± ç”µé‡ç™¾åˆ†æ¯”å¹¶è½¬æ¢ä¸ºæ˜¾ç¤ºæ®µæ•°ï¼ˆ0-10ï¼‰
    int p = batt_cal(adcval);
    p /= 10;

    // ç»˜åˆ¶ç”µæ± å¤–æ¡†
    draw_rect(x, y-4, x+14, y+4, BLACK);
    // ç»˜åˆ¶ç”µæ± æ­£æž
    draw_box(x-2, y-1, x-1, y+1, BLACK);

    // ç»˜åˆ¶ç”µé‡å¡«å……éƒ¨åˆ†
    draw_box(x+12-p, y-2, x+12, y+2, BLACK);
}


const u8 font_bt[] = {
	0x08, 0x08, 0x0f, 0x00, 0x00,
	0x10, 0x18, 0x14, 0x92, 0x51, 0x32, 0x14, 0x18,
	0x14, 0x32, 0x51, 0x92, 0x14, 0x18, 0x10,
};

/**
 * ç»˜åˆ¶è“ç‰™å›¾æ ‡
 * 
 * @param x å›¾æ ‡ä¸­å¿ƒçš„xåæ ‡
 * @param y å›¾æ ‡ä¸­å¿ƒçš„yåæ ‡
 * 
 * å›¾æ ‡è¯´æ˜Ž: ä¸€ä¸ª8x15çš„å­—ç¬¦
 */
static void draw_bt(int x, int y)
{
	fb_draw_font_info(x, y, font_bt, BLACK);
}


/****************************************************************************************/

typedef struct {
	int xres, yres;
	int font_char;
	int font_dseg;
	u16 x[8];
	u16 y[8];
}LAYOUT;

// åæ ‡0: å…¬åŽ†æ—¥æœŸ
// åæ ‡1: è“ç‰™å›¾æ ‡
// åæ ‡2: ç”µæ± å›¾æ ‡
// åæ ‡3: æ—¶é—´
// åæ ‡4: å†œåŽ†æ—¥æœŸ
// åæ ‡5: èŠ‚æ°”
// åæ ‡6: èŠ‚æ—¥
// åæ ‡7: ä¸Šä¸‹åˆ

LAYOUT layouts[3] = {
	/* Legacy 212x104 slot disabled for the fixed HINK-E0213A53 physical override. */
	{0, 0, 0, 1,
		{15, 172, 190,  16,  12,  98, 150, 12},
		{ 6,   7,  14,  27,  82,  82,  82, 44},
	},
	{250, 122, 2, 3,
		{15, 206, 226,  12,  12, 118, 176, 15},
		{ 6,   8,  15,  28,  98,  98,  98, 50},
	},
	{296, 128, 2, 3,
		{15, 246, 268,  30,  12, 140, 220, 15,},
		{ 6,   8,  15,  30, 102, 102, 102, 52,},
	},
};

int current_layout = 0;

void select_layout(int xres, int yres)
{
	int i;

	for(i=0; i<3; i++){
		if(layouts[i].xres==xres && layouts[i].yres==yres){
			current_layout = i;
			return;
		}
	}
}


/**
 * ç”µå­å¢¨æ°´å±æ›´æ–°ç­‰å¾…å®šæ—¶å™¨
 * 
 * åŠŸèƒ½è¯´æ˜Žï¼š
 * - æ£€æŸ¥ç”µå­å¢¨æ°´å±æ˜¯å¦å¤„äºŽå¿™çŠ¶æ€
 * - å¦‚æžœå¿™ï¼Œåˆ™40msåŽå†æ¬¡æ£€æŸ¥
 * - å¦‚æžœç©ºé—²ï¼Œåˆ™å®Œæˆæ›´æ–°æµç¨‹å¹¶è¿›å…¥çœç”µæ¨¡å¼
 * 
 * ç”µå­å¢¨æ°´å±æ›´æ–°å®ŒæˆåŽçš„å¤„ç†ï¼š
 * 1. å‘é€æ·±åº¦ç¡çœ å‘½ä»¤(0x10, 0x01)
 * 2. å…³é—­ç”µæº
 * 3. å…³é—­ç¡¬ä»¶æŽ¥å£
 * 4. è®¾ç½®ç³»ç»Ÿè¿›å…¥æ‰©å±•ç¡çœ æ¨¡å¼
 */
static void epd_wait_timer(void)
{
    if(epd_busy()){
        // å±å¹•ä»åœ¨å¿™ï¼Œ40msåŽå†æ¬¡æ£€æŸ¥
        epd_wait_hnd = app_easy_timer(40, epd_wait_timer);
    }else{
        // å±å¹•æ›´æ–°å®Œæˆ
        epd_wait_hnd = EASY_TIMER_INVALID_TIMER;
        // å‘é€æ·±åº¦ç¡çœ å‘½ä»¤
        epd_cmd1(0x10, 0x01);
        // å…³é—­ç”µæº
        epd_power(0);
        // å…³é—­ç¡¬ä»¶æŽ¥å£
        epd_hw_close();
        // è®¾ç½®ç³»ç»Ÿè¿›å…¥æ‰©å±•ç¡çœ æ¨¡å¼
        arch_set_sleep_mode(ARCH_EXT_SLEEP_ON);
        if (hink_e6_state == HINK_E6_STATE_REFRESHING) {
            hink_e6_state = HINK_E6_STATE_COMPLETE;
        }
    }
}


void QR_draw()
{
	if(hink_e6_state >= HINK_E6_STATE_REFRESHING){
		return;
	}

	// æ­¤å¤„æ·»åŠ QRç ç»˜åˆ¶é€»è¾‘
	epd_hw_open();

	epd_update_mode(UPDATE_FULL);

	memset(fb_bw, 0xff, scr_h*line_bytes);
	memset(fb_rr, 0x00, scr_h*line_bytes);	

	draw_qr_code(5, 5, 3, QR_31x31);
	draw_text(100, 5,"HL27C TEST", BLACK);
	draw_text(100, 20, "HINK213 OK", BLACK);
	draw_text(170,20,bt_id,BLACK);
		
	draw_text(110,40,"-------------",BLACK);
	
	draw_text(100, 60, "HMCLOCK DRIVER", BLACK);
	draw_text(100, 75, "PANEL REFRESH OK", BLACK);
	// å¢¨æ°´å±æ›´æ–°æ˜¾ç¤º
	epd_init();
	epd_screen_update();
	epd_update();
	// æ›´æ–°æ—¶å¦‚æžœæ·±åº¦ä¼‘çœ ï¼Œä¼šèŠ±å±ã€‚ è¿™é‡Œæš‚æ—¶å…³é—­ä¼‘çœ ã€‚
	arch_set_sleep_mode(ARCH_SLEEP_OFF);
	epd_wait_hnd = app_easy_timer(40, epd_wait_timer);
}

void LB_draw()
{
	if(hink_e6_state >= HINK_E6_STATE_REFRESHING){
		return;
	}

	// æ­¤å¤„æ·»åŠ ä½Žç”µåŽ‹ç çš„ç»˜åˆ¶é€»è¾‘
	epd_hw_open();

	epd_update_mode(UPDATE_FULL);

	memset(fb_bw, 0xff, scr_h*line_bytes);
	memset(fb_rr, 0x00, scr_h*line_bytes);	

	draw_qr_code(60, 10, 4, LB_31x31);

	// å¢¨æ°´å±æ›´æ–°æ˜¾ç¤º
	epd_init();
	epd_screen_update();
	epd_update();
	// æ›´æ–°æ—¶å¦‚æžœæ·±åº¦ä¼‘çœ ï¼Œä¼šèŠ±å±ã€‚ è¿™é‡Œæš‚æ—¶å…³é—­ä¼‘çœ ã€‚
	arch_set_sleep_mode(ARCH_SLEEP_OFF);
	epd_wait_hnd = app_easy_timer(40, epd_wait_timer);
}

/**
 * ç»˜åˆ¶æ—¶é’Ÿç•Œé¢
 * 
 * @param flags æ˜¾ç¤ºæŽ§åˆ¶æ ‡å¿—
 *             bit0-1: æ›´æ–°æ¨¡å¼ï¼ˆå¿«é€Ÿ/æ­£å¸¸ï¼‰
 *             bit2: æ˜¯å¦æ˜¾ç¤ºè“ç‰™å›¾æ ‡
 * 
 * æ˜¾ç¤ºå†…å®¹åŒ…æ‹¬ï¼š
 * - ç”µæ± ç”µé‡å›¾æ ‡
 * - è“ç‰™è¿žæŽ¥çŠ¶æ€å›¾æ ‡ï¼ˆå¯é€‰ï¼‰
 * - å¤§å­—å·æ—¶é—´æ˜¾ç¤º
 * - å…¬åŽ†æ—¥æœŸå’Œæ˜ŸæœŸ
 * - å†œåŽ†æ—¥æœŸ
 * - èŠ‚æ°”å’ŒèŠ‚æ—¥ä¿¡æ¯
 */
void clock_draw(int flags)
{
	char tbuf[64];
	LAYOUT *lt = &layouts[current_layout];

	if(hink_e6_state >= HINK_E6_STATE_REFRESHING){
		return;
	}

	if(ota_state){
		return;
	}

	epd_hw_open();

	epd_update_mode(flags&3);

	memset(fb_bw, 0xff, scr_h*line_bytes);
	memset(fb_rr, 0x00, scr_h*line_bytes);

	// æ˜¾ç¤ºç”µæ± ç”µé‡
	draw_batt(lt->x[2], lt->y[2]);
	if(flags&DRAW_BT){
		// æ˜¾ç¤ºè“ç‰™å›¾æ ‡
		draw_bt(lt->x[1], lt->y[1]);
	}

	// ä½¿ç”¨å¤§å­—æ˜¾ç¤ºæ—¶é—´
	if(h24_format){
		// 24å°æ—¶åˆ¶
		select_font(lt->font_dseg);
		sprintf(tbuf, "%02d:%02d", hour, minute);
		draw_text(lt->x[3], lt->y[3], tbuf, BLACK);
	}else{
		// 12å°æ—¶åˆ¶
		int h = hour;
		int ampm = 0;
		if(h>=12){
			if(h>12)
				h -= 12;
			ampm = 1;
		}else if(h==0){
			h = 12; // 0ç‚¹æ˜¾ç¤ºä¸º12ç‚¹
		}
		select_font(lt->font_dseg);
		sprintf(tbuf, "%2d:%02d", h, minute);
		draw_text(lt->x[3], lt->y[3], tbuf, BLACK);

		// æ˜¾ç¤ºä¸Šåˆ/ä¸‹åˆ
		select_font(lt->font_char);
		if(ampm){
			strcpy(tbuf, "ä¸‹åˆ");
		}else{
			strcpy(tbuf, "ä¸Šåˆ");
		}
		draw_text(lt->x[7], lt->y[7], tbuf, BLACK);
	}

	// æ˜¾ç¤ºå…¬åŽ†æ—¥æœŸ
	sprintf(tbuf, "%4då¹´%2dæœˆ%2dæ—¥   æ˜ŸæœŸ%s", year, month+1, date+1, wday_str[wday]);
	select_font(lt->font_char);
	draw_text(lt->x[0], lt->y[0], tbuf, BLACK);

	// æ˜¾ç¤ºå†œåŽ†æ—¥æœŸ(ä¸æ˜¾ç¤ºå¹´)
	ldate_str(tbuf);
	draw_text(lt->x[4], lt->y[4], tbuf, BLACK);
	// æ˜¾ç¤ºèŠ‚æ°”
	if(jieqi_str)
		draw_text(lt->x[5], lt->y[5], jieqi_str, BLACK);
	// æ˜¾ç¤ºèŠ‚å‡æ—¥
	if(flags&DRAW_BT){
		draw_text(lt->x[6], lt->y[6], bt_id, BLACK);
	}else if(holiday_str){
		draw_text(lt->x[6], lt->y[6], holiday_str, BLACK);
	}

	// å¢¨æ°´å±æ›´æ–°æ˜¾ç¤º
	epd_init();
	epd_screen_update();
	epd_update();
	// æ›´æ–°æ—¶å¦‚æžœæ·±åº¦ä¼‘çœ ï¼Œä¼šèŠ±å±ã€‚ è¿™é‡Œæš‚æ—¶å…³é—­ä¼‘çœ ã€‚
	arch_set_sleep_mode(ARCH_SLEEP_OFF);
	epd_wait_hnd = app_easy_timer(40, epd_wait_timer);
}


/****************************************************************************************/


/**
 * æŽ§åˆ¶ç‚¹å†™å…¥æŒ‡ç¤ºå¤„ç†å‡½æ•°
 * 
 * @param msgid æ¶ˆæ¯ID
 * @param param å†™å…¥å‚æ•°
 * @param dest_id ç›®æ ‡ä»»åŠ¡ID
 * @param src_id æºä»»åŠ¡ID
 * 
 * å¤„ç†é€šè¿‡BLEæŽ¥æ”¶åˆ°çš„æŽ§åˆ¶å‘½ä»¤
 */
#define HINK_E4_TIMEOUT_10MS     2000U
#define HINK_E4_TIMEOUT_SECONDS  20U

#define HINK_E4_STATUS_OK           0x00
#define HINK_E4_STATUS_INVALID      0x01
#define HINK_E4_STATUS_BAD_TOKEN    0x02
#define HINK_E4_STATUS_NOT_OPEN     0x03
#define HINK_E4_STATUS_WRONG_OWNER  0x04
#define HINK_E4_STATUS_UNSUPPORTED  0x05

static void hink_e4_notify_bytes(const uint8_t *data, uint8_t len)
{
    struct custs1_val_set_req *set_req;
    struct custs1_val_ntf_ind_req *ntf_req;

    if (ke_state_get(TASK_APP) != APP_CONNECTED)
    {
        return;
    }

    set_req = KE_MSG_ALLOC_DYN(CUSTS1_VAL_SET_REQ,
                               prf_get_task_from_id(TASK_ID_CUSTS1),
                               TASK_APP,
                               custs1_val_set_req,
                               len);
    set_req->conidx = hink_e4_conidx;
    set_req->handle = SVC2_IDX_HINK_NOTIFY_VAL;
    set_req->length = len;
    memcpy(set_req->value, data, len);
    KE_MSG_SEND(set_req);

    ntf_req = KE_MSG_ALLOC_DYN(CUSTS1_VAL_NTF_REQ,
                               prf_get_task_from_id(TASK_ID_CUSTS1),
                               TASK_APP,
                               custs1_val_ntf_ind_req,
                               len);
    ntf_req->conidx = hink_e4_conidx;
    ntf_req->handle = SVC2_IDX_HINK_NOTIFY_VAL;
    ntf_req->length = len;
    ntf_req->notification = true;
    memcpy(ntf_req->value, data, len);
    KE_MSG_SEND(ntf_req);
}

#define hink_u16_le(data) ((uint16_t)(data)[0] | ((uint16_t)(data)[1] << 8))
#define hink_u32_le(data) (((uint32_t)(data)[0]) | \
                           ((uint32_t)(data)[1] << 8) | \
                           ((uint32_t)(data)[2] << 16) | \
                           ((uint32_t)(data)[3] << 24))
#define hink_put_u32_le(data, value) do { \
        (data)[0] = (uint8_t)((value) & 0xFFU); \
        (data)[1] = (uint8_t)(((value) >> 8) & 0xFFU); \
        (data)[2] = (uint8_t)(((value) >> 16) & 0xFFU); \
        (data)[3] = (uint8_t)(((value) >> 24) & 0xFFU); \
    } while (0)
#define hink_put_u16_le(data, value) do { \
        (data)[0] = (uint8_t)((value) & 0xFFU); \
        (data)[1] = (uint8_t)((value) >> 8); \
    } while (0)
#define hink_d2_elapsed_seconds() (hink_d2_uptime_seconds - hink_d2_uptime_at_sync)
#define hink_d2_current_epoch() ((hink_d2_synced_epoch == 0UL) ? \
                                 0UL : \
                                 (hink_d2_synced_epoch + hink_d2_elapsed_seconds()))

#if 0
static uint8_t hink_d2_runtime_state(void)
{
    if (hink_d2_synced_epoch == 0UL)
    {
        return HINK_D2_STATE_UNSET;
    }

    return (hink_d2_elapsed_seconds() >= HINK_D2_STALE_SECONDS) ?
           HINK_D2_STATE_STALE :
           HINK_D2_STATE_RUNNING;
}

static void hink_d2_notify(uint8_t result, uint8_t state) __attribute__((unused));
static void hink_d2_notify(uint8_t result, uint8_t state)
{
    uint8_t msg[HINK_D2_STATUS_LEN];
    uint32_t epoch = hink_d2_current_epoch();
    uint32_t uptime = hink_d2_uptime_seconds;

    msg[0] = 0xD2;
    msg[1] = 0x81;
    msg[2] = result;
    msg[3] = state;
    hink_put_u32_le(&msg[4], epoch);
    hink_put_u16_le(&msg[8], (uint16_t)hink_d2_timezone_minutes);
    msg[10] = hink_d2_flags;
    hink_put_u32_le(&msg[11], uptime);
    hink_e4_notify_bytes(msg, HINK_D2_STATUS_LEN);
}
#endif

static uint8_t hink_d2_time_handle(struct custs1_val_write_ind const *param)
{
    uint8_t subcmd;
    uint8_t msg[HINK_D2_STATUS_LEN];
    uint32_t epoch;
    uint32_t uptime;
    int16_t timezone;
    uint8_t flags;

    if ((param->length < 2U) || (param->value[0] != 0xD2))
    {
        return 0U;
    }

    subcmd = param->value[1];
    msg[2] = HINK_D2_RESULT_INVALID_LENGTH;

    if (subcmd == 0x00U)
    {
        if (param->length != HINK_D2_SET_TIME_LEN)
        {
            goto notify_runtime;
        }

        flags = param->value[8];
        if ((flags & HINK_D2_FLAGS_RESERVED_MASK) != 0U)
        {
            msg[2] = HINK_D2_RESULT_INVALID_FLAGS;
            goto notify_runtime;
        }

        epoch = hink_u32_le(&param->value[2]);
        timezone = (int16_t)hink_u16_le(&param->value[6]);
        if (((epoch - HINK_D2_EPOCH_MIN) > (HINK_D2_EPOCH_MAX - HINK_D2_EPOCH_MIN)) ||
            ((uint16_t)(timezone + 720) > 1560U))
        {
            /* Equivalent to epoch < HINK_D2_EPOCH_MIN, epoch > HINK_D2_EPOCH_MAX,
             * timezone < -720, or timezone > 840.
             */
            msg[2] = HINK_D2_RESULT_INVALID_TIME;
            goto notify_runtime;
        }

        hink_d2_synced_epoch = epoch;
        hink_d2_timezone_minutes = timezone;
        hink_d2_flags = flags;
        hink_d2_uptime_at_sync = hink_d2_uptime_seconds;
        /* D2 smoke anchor: hink_d2_notify(HINK_D2_RESULT_OK, HINK_D2_STATE_SYNCED) */
        msg[2] = HINK_D2_RESULT_OK;
        msg[3] = HINK_D2_STATE_SYNCED;
        goto notify_state;
    }

    if (subcmd == 0x01U)
    {
        if (param->length != HINK_D2_GET_STATUS_LEN)
        {
            goto notify_runtime;
        }

        if (hink_d2_synced_epoch == 0UL)
        {
            msg[2] = HINK_D2_RESULT_NOT_INIT;
            goto notify_runtime;
        }

        msg[2] = HINK_D2_RESULT_OK;
        goto notify_runtime;
    }

notify_runtime:
    msg[3] = (hink_d2_synced_epoch == 0UL) ? HINK_D2_STATE_UNSET :
             ((hink_d2_elapsed_seconds() >= HINK_D2_STALE_SECONDS) ?
              HINK_D2_STATE_STALE :
              HINK_D2_STATE_RUNNING);
notify_state:
    epoch = hink_d2_current_epoch();
    uptime = hink_d2_uptime_seconds;
    msg[0] = 0xD2;
    msg[1] = 0x81;
    hink_put_u32_le(&msg[4], epoch);
    hink_put_u16_le(&msg[8], (uint16_t)hink_d2_timezone_minutes);
    msg[10] = hink_d2_flags;
    hink_put_u32_le(&msg[11], uptime);
    hink_e4_notify_bytes(msg, HINK_D2_STATUS_LEN);
    return 1U;
}

static uint16_t hink_e5_crc16_ccitt_update(uint16_t crc, const uint8_t *data, uint8_t len)
{
    uint8_t i;
    uint8_t bit;

    for (i = 0; i < len; i++)
    {
        crc ^= ((uint16_t)data[i] << 8);
        for (bit = 0; bit < 8U; bit++)
        {
            if (crc & 0x8000U)
            {
                crc = (uint16_t)((crc << 1) ^ 0x1021U);
            }
            else
            {
                crc = (uint16_t)(crc << 1);
            }
        }
    }

    return crc;
}

static void hink_e5_reset_state(void)
{
    hink_e5_state = HINK_E5_STATE_NONE;
    hink_e5_transfer_id = 0U;
    hink_e5_next_seq = 0U;
    hink_e5_bytes = 0U;
    hink_e5_crc = 0U;
}

static void hink_e5_notify(uint8_t response, uint8_t status, uint8_t transfer_id, uint8_t mode)
{
    uint8_t msg[11];
    uint8_t len = 5U;

    msg[0] = 0xE5;
    msg[1] = response;
    msg[2] = status;
    msg[3] = transfer_id;

    if (mode == 1U)
    {
        msg[4] = (uint8_t)(hink_e5_next_seq & 0xFFU);
        msg[5] = (uint8_t)(hink_e5_next_seq >> 8);
        msg[6] = (uint8_t)(hink_e5_bytes & 0xFFU);
        msg[7] = (uint8_t)(hink_e5_bytes >> 8);
        len = 8U;
    }
    else
    {
        msg[4] = hink_e5_state;
        if (mode == 2U)
        {
            msg[5] = (uint8_t)(hink_e5_next_seq & 0xFFU);
            msg[6] = (uint8_t)(hink_e5_next_seq >> 8);
            msg[7] = (uint8_t)(hink_e5_bytes & 0xFFU);
            msg[8] = (uint8_t)(hink_e5_bytes >> 8);
            msg[9] = (uint8_t)(hink_e5_crc & 0xFFU);
            msg[10] = (uint8_t)(hink_e5_crc >> 8);
            len = 11U;
        }
    }

    hink_e4_notify_bytes(msg, len);
}

static uint8_t hink_e5_require_session(uint8_t conidx, uint8_t response, uint8_t transfer_id)
{
    if (!hink_e4_session_active)
    {
        hink_e5_notify(response, HINK_E5_STATUS_NOT_OPEN, transfer_id, 0U);
        return 0U;
    }

    if (hink_e4_session_owner_conidx != conidx)
    {
        hink_e5_notify(response, HINK_E5_STATUS_WRONG_OWNER, transfer_id, 0U);
        return 0U;
    }

    return 1U;
}

static uint8_t hink_e5_handle_start(struct custs1_val_write_ind const *param, uint8_t conidx)
{
    uint8_t transfer_id = (param->length >= 3U) ? param->value[2] : 0U;
    uint16_t width;
    uint16_t height;
    uint16_t total;

    if (!hink_e5_require_session(conidx, 0x80, transfer_id))
    {
        return 1U;
    }

    if (param->length != 11U)
    {
        hink_e5_notify(0x80, HINK_E5_STATUS_INVALID, transfer_id, 0U);
        return 1U;
    }

    width = hink_u16_le(&param->value[3]);
    height = hink_u16_le(&param->value[5]);
    total = hink_u16_le(&param->value[9]);

    if ((width != HINK_E5_WIDTH) ||
        (height != HINK_E5_HEIGHT) ||
        (param->value[7] != 0x01U) ||
        (param->value[8] != HINK_E5_STRIDE) ||
        (total != HINK_E5_TOTAL_BYTES))
    {
        hink_e5_notify(0x80, HINK_E5_STATUS_BAD_GEOMETRY, transfer_id, 0U);
        return 1U;
    }

    memset(HINK_E5_STAGING_BUFFER, 0, HINK_E5_TOTAL_BYTES);
    hink_e5_state = HINK_E5_STATE_ACTIVE;
    hink_e5_transfer_id = transfer_id;
    hink_e5_next_seq = 0U;
    hink_e5_bytes = 0U;
    hink_e5_crc = 0xFFFFU;
    hink_e4_arm_timer();
    hink_e5_notify(0x80, HINK_E5_STATUS_OK, transfer_id, 2U);
    return 1U;
}

static uint8_t hink_e5_handle_chunk(struct custs1_val_write_ind const *param, uint8_t conidx)
{
    uint8_t transfer_id = (param->length >= 3U) ? param->value[2] : 0U;
    uint16_t seq;
    uint8_t len;

    if (!hink_e5_require_session(conidx, 0x81, transfer_id))
    {
        return 1U;
    }

    if (param->length < 6U)
    {
        hink_e5_notify(0x81, HINK_E5_STATUS_INVALID, transfer_id, 1U);
        return 1U;
    }

    seq = hink_u16_le(&param->value[3]);
    len = param->value[5];

    if ((hink_e5_state != HINK_E5_STATE_ACTIVE) || (transfer_id != hink_e5_transfer_id))
    {
        hink_e5_notify(0x81, HINK_E5_STATUS_BAD_ID, transfer_id, 1U);
        return 1U;
    }

    if ((len == 0U) || (len > HINK_E5_CHUNK_MAX) || (param->length != (uint8_t)(6U + len)))
    {
        hink_e5_notify(0x81, HINK_E5_STATUS_INVALID, transfer_id, 1U);
        return 1U;
    }

    if (seq != hink_e5_next_seq)
    {
        hink_e5_notify(0x81, HINK_E5_STATUS_BAD_SEQUENCE, transfer_id, 1U);
        return 1U;
    }

    if (((uint16_t)(hink_e5_bytes + len) > HINK_E5_TOTAL_BYTES) ||
        (hink_e5_next_seq >= HINK_E5_TOTAL_CHUNKS))
    {
        hink_e5_notify(0x81, HINK_E5_STATUS_OVERFLOW, transfer_id, 1U);
        return 1U;
    }

    memcpy(&HINK_E5_STAGING_BUFFER[hink_e5_bytes], &param->value[6], len);
    hink_e5_crc = hink_e5_crc16_ccitt_update(hink_e5_crc, &param->value[6], len);
    hink_e5_bytes = (uint16_t)(hink_e5_bytes + len);
    hink_e5_next_seq++;
    hink_e4_arm_timer();
    hink_e5_notify(0x81, HINK_E5_STATUS_OK, transfer_id, 1U);
    return 1U;
}

static uint8_t hink_e5_handle_commit(struct custs1_val_write_ind const *param, uint8_t conidx)
{
    uint8_t transfer_id = (param->length >= 3U) ? param->value[2] : 0U;
    uint16_t chunks;
    uint16_t bytes;
    uint16_t expected_crc;

    if (!hink_e5_require_session(conidx, 0x82, transfer_id))
    {
        return 1U;
    }

    if (param->length != 9U)
    {
        hink_e5_notify(0x82, HINK_E5_STATUS_INVALID, transfer_id, 2U);
        return 1U;
    }

    chunks = hink_u16_le(&param->value[3]);
    bytes = hink_u16_le(&param->value[5]);
    expected_crc = hink_u16_le(&param->value[7]);

    if ((hink_e5_state != HINK_E5_STATE_ACTIVE) || (transfer_id != hink_e5_transfer_id))
    {
        hink_e5_notify(0x82, HINK_E5_STATUS_BAD_ID, transfer_id, 2U);
        return 1U;
    }

    if ((chunks != HINK_E5_TOTAL_CHUNKS) ||
        (chunks != hink_e5_next_seq) ||
        (bytes != HINK_E5_TOTAL_BYTES) ||
        (bytes != hink_e5_bytes))
    {
        hink_e5_notify(0x82, HINK_E5_STATUS_BAD_COUNT, transfer_id, 2U);
        return 1U;
    }

    if (hink_e5_crc != expected_crc)
    {
        hink_e5_notify(0x82, HINK_E5_STATUS_BAD_CRC, transfer_id, 2U);
        return 1U;
    }

    hink_e5_state = HINK_E5_STATE_COMPLETE;
    hink_e4_arm_timer();
    hink_e5_notify(0x82, HINK_E5_STATUS_OK, transfer_id, 2U);
    return 1U;
}

static uint8_t hink_e5_framebuffer_handle(struct custs1_val_write_ind const *param,
                                          uint8_t conidx)
{
    uint8_t subcmd;
    uint8_t transfer_id;

    if ((param->length < 2U) || (param->value[0] != 0xE5))
    {
        return 0U;
    }

    subcmd = param->value[1];
    transfer_id = (param->length >= 3U) ? param->value[2] : hink_e5_transfer_id;

    switch (subcmd)
    {
        case 0x00:
            if (hink_e6_state == HINK_E6_STATE_ACCEPTED_PENDING ||
                hink_e6_state == HINK_E6_STATE_REFRESHING)
            {
                hink_e5_notify(0x80, HINK_E5_STATUS_INVALID, transfer_id, 0U);
                return 1U;
            }
            return hink_e5_handle_start(param, conidx);

        case 0x01:
            if (hink_e6_state == HINK_E6_STATE_ACCEPTED_PENDING ||
                hink_e6_state == HINK_E6_STATE_REFRESHING)
            {
                hink_e5_notify(0x81, HINK_E5_STATUS_INVALID, transfer_id, 1U);
                return 1U;
            }
            return hink_e5_handle_chunk(param, conidx);

        case 0x02:
            if (hink_e6_state == HINK_E6_STATE_ACCEPTED_PENDING ||
                hink_e6_state == HINK_E6_STATE_REFRESHING)
            {
                hink_e5_notify(0x82, HINK_E5_STATUS_INVALID, transfer_id, 2U);
                return 1U;
            }
            return hink_e5_handle_commit(param, conidx);

        case 0x03:
            if (!hink_e5_require_session(conidx, 0x83, transfer_id))
            {
                return 1U;
            }
            if ((param->length != 3U) || (transfer_id != hink_e5_transfer_id))
            {
                hink_e5_notify(0x83, HINK_E5_STATUS_BAD_ID, transfer_id, 2U);
                return 1U;
            }
            hink_e4_arm_timer();
            hink_e5_notify(0x83, HINK_E5_STATUS_OK, transfer_id, 2U);
            return 1U;

        case 0x04:
            if (hink_e6_state == HINK_E6_STATE_ACCEPTED_PENDING ||
                hink_e6_state == HINK_E6_STATE_REFRESHING)
            {
                hink_e5_notify(0x84, HINK_E5_STATUS_INVALID, transfer_id, 0U);
                return 1U;
            }
            if (!hink_e5_require_session(conidx, 0x84, transfer_id))
            {
                return 1U;
            }
            hink_e5_reset_state();
            hink_e4_arm_timer();
            hink_e5_notify(0x84, HINK_E5_STATUS_OK, transfer_id, 0U);
            return 1U;

        default:
            hink_e5_notify(0x8F, HINK_E5_STATUS_UNSUPPORTED, transfer_id, 0U);
            return 1U;
    }
}

static void hink_e6_notify(uint8_t response, uint8_t code, uint8_t transfer_id, uint8_t state)
{
    uint8_t msg[6];
    msg[0] = 0xE6;
    msg[1] = response;
    msg[2] = code;
    msg[3] = transfer_id;
    msg[4] = state;
    msg[5] = 0x14; // E4 timeout in hex (20 seconds)
    hink_e4_notify_bytes(msg, sizeof(msg));
}

static void hink_e6_reset_state(void)
{
    if (hink_e6_timer_hnd != EASY_TIMER_INVALID_TIMER)
    {
        app_easy_timer_cancel(hink_e6_timer_hnd);
        hink_e6_timer_hnd = EASY_TIMER_INVALID_TIMER;
    }
    hink_e6_state = HINK_E6_STATE_IDLE;
    hink_e6_transfer_id = 0U;
}

static void hink_e6_timer_cb(void)
{
    hink_e6_timer_hnd = EASY_TIMER_INVALID_TIMER;

    if (hink_e6_state != HINK_E6_STATE_ACCEPTED_PENDING)
    {
        return;
    }

    hink_e6_state = HINK_E6_STATE_REFRESHING;
    epd_hw_open();
    epd_update_mode(UPDATE_FULL);
    epd_init();
    epd_screen_update();
    epd_update();
    arch_set_sleep_mode(ARCH_SLEEP_OFF);
    epd_wait_hnd = app_easy_timer(40, epd_wait_timer);

    if (epd_wait_hnd == EASY_TIMER_INVALID_TIMER)
    {
        hink_e6_state = HINK_E6_STATE_ERROR;
        epd_cmd1(0x10, 0x01);
        epd_power(0);
        epd_hw_close();
        arch_set_sleep_mode(ARCH_EXT_SLEEP_ON);
    }
}

static uint8_t hink_e6_handle_request(struct custs1_val_write_ind const *param, uint8_t conidx, uint8_t transfer_id)
{
    if (param->length != 3U)
    {
        hink_e6_notify(0x80, 0x01, transfer_id, hink_e6_state); // MALFORMED
        return 1U;
    }

    if (!hink_e4_session_active)
    {
        hink_e6_notify(0x80, 0x02, transfer_id, hink_e6_state); // NO_E4_SESSION
        return 1U;
    }

    if (hink_e4_session_owner_conidx != conidx)
    {
        hink_e6_notify(0x80, 0x03, transfer_id, hink_e6_state); // WRONG_OWNER
        return 1U;
    }

    if (hink_e5_state != HINK_E5_STATE_COMPLETE)
    {
        hink_e6_notify(0x80, 0x04, transfer_id, hink_e6_state); // FRAME_NOT_COMPLETE
        return 1U;
    }

    if (transfer_id != hink_e5_transfer_id)
    {
        hink_e6_notify(0x80, 0x07, transfer_id, hink_e6_state); // WRONG_TRANSFER_ID
        return 1U;
    }

    if (hink_e6_state == HINK_E6_STATE_ACCEPTED_PENDING ||
        hink_e6_state == HINK_E6_STATE_REFRESHING ||
        epd_wait_hnd != EASY_TIMER_INVALID_TIMER)
    {
        hink_e6_notify(0x80, 0x05, transfer_id, hink_e6_state); // BUSY
        return 1U;
    }

    hink_e6_state = HINK_E6_STATE_ACCEPTED_PENDING;
    hink_e6_transfer_id = transfer_id;

    hink_e6_timer_hnd = app_easy_timer(5, hink_e6_timer_cb);
    if (hink_e6_timer_hnd == EASY_TIMER_INVALID_TIMER)
    {
        hink_e6_state = HINK_E6_STATE_ERROR;
        hink_e6_notify(0x80, 0x06, transfer_id, hink_e6_state); // INTERNAL_ERROR
    }
    else
    {
        hink_e4_arm_timer();
        hink_e6_notify(0x80, 0x00, transfer_id, hink_e6_state); // OK
    }

    return 1U;
}

static uint8_t hink_e6_handle_status(struct custs1_val_write_ind const *param, uint8_t conidx, uint8_t transfer_id)
{
    if (param->length != 3U)
    {
        hink_e6_notify(0x81, 0x01, transfer_id, hink_e6_state); // MALFORMED
        return 1U;
    }

    if (transfer_id != hink_e6_transfer_id)
    {
        hink_e6_notify(0x81, 0x07, transfer_id, hink_e6_state); // WRONG_TRANSFER_ID
        return 1U;
    }

    hink_e4_arm_timer();
    hink_e6_notify(0x81, 0x00, transfer_id, hink_e6_state); // OK
    return 1U;
}

static uint8_t hink_e6_refresh_handle(struct custs1_val_write_ind const *param, uint8_t conidx)
{
    uint8_t subcmd;
    uint8_t transfer_id;

    if ((param->length < 2U) || (param->value[0] != 0xE6))
    {
        return 0U;
    }

    subcmd = param->value[1];
    transfer_id = (param->length >= 3U) ? param->value[2] : 0U;

    switch (subcmd)
    {
        case 0x00:
            return hink_e6_handle_request(param, conidx, transfer_id);

        case 0x01:
            return hink_e6_handle_status(param, conidx, transfer_id);

        default:
            hink_e6_notify(0x8F, 0x01, transfer_id, hink_e6_state);
            return 1U;
    }
}

static void hink_e4_session_notify(uint8_t response,
                                   uint8_t status_or_active,
                                   uint8_t token)
{
    uint8_t msg[5];
    msg[0] = 0xE4;
    msg[1] = response;
    msg[2] = status_or_active;
    msg[3] = token;
    msg[4] = HINK_E4_TIMEOUT_SECONDS;
    hink_e4_notify_bytes(msg, sizeof(msg));
}

static void hink_e6_session_cleanup(void)
{
    if (hink_e6_state == HINK_E6_STATE_ACCEPTED_PENDING)
    {
        hink_e6_reset_state();
    }
    else if (hink_e6_timer_hnd != EASY_TIMER_INVALID_TIMER)
    {
        app_easy_timer_cancel(hink_e6_timer_hnd);
        hink_e6_timer_hnd = EASY_TIMER_INVALID_TIMER;
    }
}

void hink_e4_session_reset(void)
{
    if (hink_e4_timer_running)
    {
        app_easy_timer_cancel(hink_e4_timer);
        hink_e4_timer_running = 0;
    }

    hink_e5_reset_state();
    hink_e4_session_active = 0;
    hink_e4_session_owner_conidx = GAP_INVALID_CONIDX;
    hink_e6_session_cleanup();
}

static void hink_e4_timeout_cb(void)
{
    hink_e4_timer_running = 0;
    hink_e5_reset_state();
    hink_e4_session_active = 0;
    hink_e4_session_owner_conidx = GAP_INVALID_CONIDX;
    hink_e6_session_cleanup();
}

static void hink_e4_arm_timer(void)
{
    if (hink_e4_timer_running)
    {
        app_easy_timer_cancel(hink_e4_timer);
        hink_e4_timer_running = 0;
    }

    hink_e4_timer = app_easy_timer(HINK_E4_TIMEOUT_10MS, hink_e4_timeout_cb);
    hink_e4_timer_running = 1;
}

static uint8_t hink_e4_session_is_valid(uint8_t conidx)
{
    return (hink_e4_session_active &&
            (hink_e4_session_owner_conidx == conidx)) ? 1U : 0U;
}

static uint8_t hink_e4_session_handle(struct custs1_val_write_ind const *param,
                                      uint8_t conidx)
{
    uint8_t subcmd;
    uint8_t token;

    if ((param->length < 2U) || (param->value[0] != 0xE4))
    {
        return 0;
    }

    subcmd = param->value[1];

    switch (subcmd)
    {
        case 0x00:
            if ((param->length != 6U) ||
                (param->value[2] != 0x48) ||
                (param->value[3] != 0x4C) ||
                (param->value[4] != 0x32) ||
                (param->value[5] != 0x31))
            {
                hink_e4_session_notify(0x80, HINK_E4_STATUS_INVALID, 0);
                return 1;
            }

            hink_e4_session_reset();
            hink_e4_session_token++;
            if (hink_e4_session_token == 0U)
            {
                hink_e4_session_token = 1U;
            }
            hink_e4_session_active = 1U;
            hink_e4_session_owner_conidx = conidx;
            hink_e4_arm_timer();
            hink_e4_session_notify(0x80, HINK_E4_STATUS_OK, hink_e4_session_token);
            return 1;

        case 0x01:
            if (param->length != 3U)
            {
                hink_e4_session_notify(0x81, HINK_E4_STATUS_INVALID, hink_e4_session_token);
            }
            else if (!hink_e4_session_active)
            {
                hink_e4_session_notify(0x81, HINK_E4_STATUS_NOT_OPEN, hink_e4_session_token);
            }
            else if (hink_e4_session_owner_conidx != conidx)
            {
                hink_e4_session_notify(0x81, HINK_E4_STATUS_WRONG_OWNER, hink_e4_session_token);
            }
            else if (param->value[2] != hink_e4_session_token)
            {
                hink_e4_session_notify(0x81, HINK_E4_STATUS_BAD_TOKEN, hink_e4_session_token);
            }
            else
            {
                hink_e4_arm_timer();
                hink_e4_session_notify(0x81, HINK_E4_STATUS_OK, hink_e4_session_token);
            }
            return 1;

        case 0x02:
            token = hink_e4_session_token;
            if (param->length != 3U)
            {
                hink_e4_session_notify(0x82, HINK_E4_STATUS_INVALID, token);
            }
            else if (!hink_e4_session_active)
            {
                hink_e4_session_notify(0x82, HINK_E4_STATUS_NOT_OPEN, token);
            }
            else if (hink_e4_session_owner_conidx != conidx)
            {
                hink_e4_session_notify(0x82, HINK_E4_STATUS_WRONG_OWNER, token);
            }
            else if (param->value[2] != token)
            {
                hink_e4_session_notify(0x82, HINK_E4_STATUS_BAD_TOKEN, token);
            }
            else
            {
                hink_e4_session_reset();
                hink_e4_session_notify(0x82, HINK_E4_STATUS_OK, token);
            }
            return 1;

        case 0x03:
            if (param->length != 2U)
            {
                hink_e4_session_notify(0x83, HINK_E4_STATUS_INVALID, hink_e4_session_token);
            }
            else if (hink_e4_session_is_valid(conidx))
            {
                hink_e4_session_notify(0x83, 1U, hink_e4_session_token);
            }
            else
            {
                hink_e4_session_notify(0x83, 0U, hink_e4_session_token);
            }
            return 1;

        default:
            hink_e4_session_notify(0x8F, HINK_E4_STATUS_UNSUPPORTED, hink_e4_session_token);
            return 1;
    }
}
void user_svc1_ctrl_wr_ind_handler(ke_msg_id_t const msgid, 
                                  struct custs1_val_write_ind const *param, 
                                  ke_task_id_t const dest_id, 
                                  ke_task_id_t const src_id)
{
    // æ‰“å°æŽ¥æ”¶åˆ°çš„æŽ§åˆ¶å‘½ä»¤
    uint8_t conidx;

    if (param->length == 0U)
    {
        return;
    }

    conidx = KE_IDX_GET(src_id);
    hink_e4_conidx = app_env[conidx].conidx;
    if (hink_e4_session_handle(param, hink_e4_conidx))
    {
        return;
    }
    if (hink_d2_time_handle(param))
    {
        return;
    }
    if (hink_e5_framebuffer_handle(param, hink_e4_conidx))
    {
        return;
    }
    if (hink_e6_refresh_handle(param, hink_e4_conidx))
    {
        return;
    }

}

/**
 * é•¿å€¼ç‰¹å¾å†™å…¥æŒ‡ç¤ºå¤„ç†å‡½æ•°
 * 
 * @param msgid æ¶ˆæ¯ID
 * @param param å†™å…¥å‚æ•°
 * @param dest_id ç›®æ ‡ä»»åŠ¡ID
 * @param src_id æºä»»åŠ¡ID
 * 
 * å¤„ç†å‘½ä»¤ï¼š
 * - 0x91: æ—¶é’Ÿè®¾ç½®å‘½ä»¤
 * - 0xA0åŠä»¥ä¸Š: OTAå‡çº§ç›¸å…³å‘½ä»¤
 */
void user_svc1_long_val_wr_ind_handler(ke_msg_id_t const msgid, 
                                      struct custs1_val_write_ind const *param, 
                                      ke_task_id_t const dest_id, 
                                      ke_task_id_t const src_id)
{
    (void)msgid;
    (void)param;
    (void)dest_id;
    (void)src_id;
}

/**
 * é•¿å€¼ç‰¹å¾å±žæ€§ä¿¡æ¯è¯·æ±‚å¤„ç†å‡½æ•°
 * 
 * @param msgid æ¶ˆæ¯ID
 * @param param è¯·æ±‚å‚æ•°
 * @param dest_id ç›®æ ‡ä»»åŠ¡ID
 * @param src_id æºä»»åŠ¡ID
 * 
 * å“åº”BLEå®¢æˆ·ç«¯çš„å±žæ€§ä¿¡æ¯è¯·æ±‚
 */
void user_svc1_long_val_att_info_req_handler(ke_msg_id_t const msgid, 
                                            struct custs1_att_info_req const *param, 
                                            ke_task_id_t const dest_id, 
                                            ke_task_id_t const src_id)
{
    // åˆ†é…å“åº”æ¶ˆæ¯å†…å­˜
    struct custs1_att_info_rsp *rsp = KE_MSG_ALLOC(CUSTS1_ATT_INFO_RSP, 
                                                   src_id, 
                                                   dest_id, 
                                                   custs1_att_info_rsp);
    // è®¾ç½®è¿žæŽ¥ç´¢å¼•
    rsp->conidx  = app_env[param->conidx].conidx;
    // è®¾ç½®å±žæ€§ç´¢å¼•
    rsp->att_idx = param->att_idx;
    // è®¾ç½®é•¿åº¦ä¸º0
    rsp->length  = 0;
    // è®¾ç½®çŠ¶æ€ä¸ºæ— é”™è¯¯
    rsp->status  = ATT_ERR_NO_ERROR;

    // å‘é€å“åº”æ¶ˆæ¯
    KE_MSG_SEND(rsp);
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
    rsp->conidx  = app_env[param->conidx].conidx;
    // Provide the attribute index.
    rsp->att_idx = param->att_idx;
    // Force current length to zero.
    rsp->length  = 0;
    // Provide the ATT error code.
    rsp->status  = ATT_ERR_WRITE_NOT_PERMITTED;

    KE_MSG_SEND(rsp);
}

