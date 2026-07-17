/**
 ****************************************************************************************
 *
 * @file user_peripheral.c
 *
 * @brief å¤–è®¾é¡¹ç›®æºä»£ç æ–‡ä»¶ï¼Œä¸»è¦å®žçŽ°BLEå¤–è®¾åŠŸèƒ½ã€æ—¶é’Ÿç®¡ç†ã€EPDå±å¹•æ˜¾ç¤ºåŠOTPæ•°æ®è¯»å–ç­‰åŠŸèƒ½
 *
 * Copyright (C) 2015-2023 Renesas Electronics Corporation and/or its affiliates.
 * All rights reserved. Confidential Information.
 *
 *
 ****************************************************************************************
 */

/**
 ****************************************************************************************
 * @addtogroup APP
 * @{
 ****************************************************************************************
 */

/*
 * åŒ…å«å¤´æ–‡ä»¶
 ****************************************************************************************
 */

#include "rwip_config.h"             // è½¯ä»¶é…ç½®
#include "gattc_task.h"              // GATTå®¢æˆ·ç«¯ä»»åŠ¡ç›¸å…³å®šä¹‰
#include "gap.h"                     // GAPå±‚ç›¸å…³å®šä¹‰
#include "app_easy_timer.h"          // åº”ç”¨å±‚å®šæ—¶å™¨åŠŸèƒ½
#include "user_peripheral.h"         // æœ¬æ–‡ä»¶æŽ¥å£å£°æ˜Ž
#include "user_custs1_impl.h"        // è‡ªå®šä¹‰æœåŠ¡1å®žçŽ°
#include "user_custs1_def.h"         // è‡ªå®šä¹‰æœåŠ¡1å®šä¹‰
#include "co_bt.h"                   // è“ç‰™åè®®åè®®ç›¸å…³å®šä¹‰
#include "hw_otpc.h"                 // OTPæŽ§åˆ¶å™¨ç¡¬ä»¶æŽ¥å£

#include "epd.h"                     // EPDç”µå­çº¸å±å¹•é©±åŠ¨

/*
 * ç±»åž‹å®šä¹‰
 ****************************************************************************************
 */


/*
 * å…¨å±€å˜é‡å®šä¹‰
 ****************************************************************************************
 */

int app_connection_idx                          __SECTION_ZERO("retention_mem_area0"); // è¿žæŽ¥ç´¢å¼•ï¼Œä½¿ç”¨ retention å†…å­˜åŒºåŸŸä¿å­˜
timer_hnd app_clock_timer_used                  __SECTION_ZERO("retention_mem_area0"); // æ—¶é’Ÿå®šæ—¶å™¨å¥æŸ„ï¼Œretentionå†…å­˜ä¿å­˜
timer_hnd app_param_update_request_timer_used   __SECTION_ZERO("retention_mem_area0"); // å‚æ•°æ›´æ–°è¯·æ±‚å®šæ—¶å™¨å¥æŸ„ï¼Œretentionå†…å­˜ä¿å­˜
static timer_hnd hink_d2_adv_restart_timer_hnd  __SECTION_ZERO("retention_mem_area0");

int adv_state = 0;                          // å¹¿æ’­çŠ¶æ€ï¼š0-æœªå¹¿æ’­ï¼Œ1-æ­£åœ¨å¹¿æ’­
static int otp_btaddr[2];                      // ä»ŽOTPè¯»å–çš„è“ç‰™åœ°å€
static int otp_boot;                           // ä»ŽOTPè¯»å–çš„å¯åŠ¨ç›¸å…³æ•°æ®
static char adv_name[20];                      // å¹¿æ’­åç§°ç¼“å†²åŒº
char *bt_id = adv_name+12;                     // è“ç‰™IDåœ¨å¹¿æ’­åç§°ä¸­çš„èµ·å§‹ä½ç½®
int clock_interval;                            // æ—¶é’Ÿæ›´æ–°é—´éš”ï¼ˆç§’ï¼‰
int clock_fixup_value;                         // æ—¶é’Ÿä¿®æ­£å€¼
int clock_fixup_count;                         // æ—¶é’Ÿä¿®æ­£è®¡æ•°å™¨
static int first_timer_trigger = 0;            // æ ‡å¿—ï¼šæ˜¯å¦ä¸ºç¬¬ä¸€æ¬¡å®šæ—¶å™¨è§¦å‘ï¼ˆç”¨äºŽæ•´åˆ†é’Ÿå¯¹é½ï¼‰
static int first_update_seconds = 0;           // ç¬¬ä¸€æ¬¡è§¦å‘æ—¶éœ€è¦æ›´æ–°çš„ç§’æ•°

// EPDç‰ˆæœ¬ä¿¡æ¯ï¼ˆvolatileç¡®ä¿ä¸è¢«ä¼˜åŒ–ï¼Œç”¨äºŽç‰ˆæœ¬æ£€æµ‹ï¼‰
const volatile u32 epd_version[3] = {0xF9A51379, ~0xF9A51379, EPD_VERSION};

extern int year,month; // å½“å‰æ—¶é—´å˜é‡
extern int second; // å½“å‰ç§’æ•°ï¼Œç”¨äºŽè®¡ç®—åˆ°æ•´åˆ†é’Ÿçš„å‰©ä½™æ—¶é—´
extern uint8_t hink_d2_dedicated_clock_active(void);
extern void hink_d3d_boot_load_last_known_time(void);

/*
 * å‡½æ•°å®šä¹‰
 ****************************************************************************************
*/


/**
 ****************************************************************************************
 * @brief åœ¨GAPM_START_ADVERTISE_CMDå‚æ•°ç»“æž„çš„å¹¿æ’­æˆ–æ‰«æå“åº”æ•°æ®ä¸­æ·»åŠ ADç»“æž„
 * @param[in] cmd               GAPM_START_ADVERTISE_CMDå‚æ•°ç»“æž„
 * @param[in] ad_struct_data    ADç»“æž„æ•°æ®ç¼“å†²åŒº
 * @param[in] ad_struct_len     ADç»“æž„é•¿åº¦
 * @param[in] adv_connectable   æ˜¯å¦ä¸ºå¯è¿žæŽ¥å¹¿æ’­äº‹ä»¶ï¼ŒæŽ§åˆ¶å¹¿æ’­æ•°æ®æœ€å¤§é•¿åº¦ï¼ˆå¯è¿žæŽ¥æ—¶28å­—èŠ‚ï¼Œå¦åˆ™31å­—èŠ‚ï¼‰
 ****************************************************************************************
 */
static void app_add_ad_struct(struct gapm_start_advertise_cmd *cmd, void *ad_struct_data, uint8_t ad_struct_len, uint8_t adv_connectable)
{
    // æ ¹æ®æ˜¯å¦å¯è¿žæŽ¥ç¡®å®šå¹¿æ’­æ•°æ®æœ€å¤§é•¿åº¦
    uint8_t adv_data_max_size = (adv_connectable) ? (ADV_DATA_LEN - 3) : (ADV_DATA_LEN);

    // ä¼˜å…ˆæ·»åŠ åˆ°å¹¿æ’­æ•°æ®
    if ((adv_data_max_size - cmd->info.host.adv_data_len) >= ad_struct_len)
    {
        memcpy(&cmd->info.host.adv_data[cmd->info.host.adv_data_len], ad_struct_data, ad_struct_len);
        cmd->info.host.adv_data_len += ad_struct_len;
    }
    // å¹¿æ’­æ•°æ®ç©ºé—´ä¸è¶³æ—¶æ·»åŠ åˆ°æ‰«æå“åº”æ•°æ®
    else if ((SCAN_RSP_DATA_LEN - cmd->info.host.scan_rsp_data_len) >= ad_struct_len)
    {
        memcpy(&cmd->info.host.scan_rsp_data[cmd->info.host.scan_rsp_data_len], ad_struct_data, ad_struct_len);
        cmd->info.host.scan_rsp_data_len += ad_struct_len;
    }
    // ç©ºé—´ä¸è¶³æ—¶è§¦å‘æ–­è¨€è­¦å‘Š
    else
    {
        ASSERT_WARNING(0);
    }
}


/**
 ****************************************************************************************
 * @brief å‚æ•°æ›´æ–°è¯·æ±‚å®šæ—¶å™¨å›žè°ƒå‡½æ•°
 *        å½“å®šæ—¶å™¨è¶…æ—¶ï¼Œå‘èµ·è¿žæŽ¥å‚æ•°æ›´æ–°è¯·æ±‚
 ****************************************************************************************
*/
static void param_update_request_timer_cb()
{
    app_easy_gap_param_update_start(app_connection_idx);  // å‘èµ·å‚æ•°æ›´æ–°
    app_param_update_request_timer_used = EASY_TIMER_INVALID_TIMER;  // é‡ç½®å®šæ—¶å™¨å¥æŸ„
}


/**
 ****************************************************************************************
 * @brief è¯»å–OTPï¼ˆä¸€æ¬¡æ€§å¯ç¼–ç¨‹ï¼‰å­˜å‚¨å™¨ä¸­çš„å€¼
 *        ä¸»è¦è¯»å–è“ç‰™åœ°å€å’Œå¯åŠ¨ä¿¡æ¯ï¼Œå¹¶ç”Ÿæˆå¹¿æ’­åç§°
 ****************************************************************************************
 */
static void read_otp_value(void)
{
	hw_otpc_init();               // åˆå§‹åŒ–OTPæŽ§åˆ¶å™¨
	hw_otpc_manual_read_on(false); // å…³é—­æ‰‹åŠ¨è¯»å–æ¨¡å¼
	
	// ä»ŽOTPç‰¹å®šåœ°å€è¯»å–æ•°æ®
	otp_boot = *(u32*)(0x07f8fe00);    // è¯»å–å¯åŠ¨ç›¸å…³æ•°æ®
	otp_btaddr[0] = *(u32*)(0x07f8ffa8); // è¯»å–è“ç‰™åœ°å€ä½Ž32ä½
	otp_btaddr[1] = *(u32*)(0x07f8ffac); // è¯»å–è“ç‰™åœ°å€é«˜32ä½
	
	hw_otpc_disable();            // ç¦ç”¨OTPæŽ§åˆ¶å™¨

	// å¤„ç†è“ç‰™åœ°å€ï¼Œç”Ÿæˆè®¾å¤‡å”¯ä¸€æ ‡è¯†
	u32 ba0 = otp_btaddr[0];
	u32 ba1 = otp_btaddr[1];

	ba1 = (ba1<<8)|(ba0>>24);
	ba0 &= 0x00ffffff;
	ba0 ^= ba1;

	// ç”Ÿæˆå¹¿æ’­åç§°ï¼ˆæ ¼å¼ï¼šDLG-CLOCK-XXYYZZï¼ŒXXYYZZä¸ºè“ç‰™åœ°å€åŽä¸‰æ®µï¼‰
	u8 *ba = (u8*)&ba0;
	sprintf(adv_name+2, "HINK213-CLOCK");
	int name_len = strlen(adv_name+2);
	
	// å¦‚æžœè®¾å¤‡åç§°æœªè®¾ç½®ï¼Œåˆ™ä½¿ç”¨ç”Ÿæˆçš„åç§°
	if(device_info.dev_name.length==0){
		device_info.dev_name.length = name_len;
		memcpy(device_info.dev_name.name, adv_name+2, name_len);
	}

	// æž„é€ ADç»“æž„ï¼šç¬¬ä¸€ä¸ªå­—èŠ‚ä¸ºé•¿åº¦ï¼Œç¬¬äºŒä¸ªå­—èŠ‚ä¸ºADç±»åž‹ï¼ˆå®Œæ•´åç§°ï¼‰
	adv_name[0] = name_len+1;
	adv_name[1] = GAP_AD_TYPE_COMPLETE_NAME;
}

// å¤–éƒ¨å£°æ˜Žçš„åŒºåŸŸè¡¨åŸºåœ°å€ï¼ˆç”¨äºŽå†…å­˜ç›¸å…³æ“ä½œï¼‰
extern int Region$$Table$$Base;

/**
 ****************************************************************************************
 * @brief åº”ç”¨åˆå§‹åŒ–å‡½æ•°
 *        åˆå§‹åŒ–OTPæ•°æ®ã€å®šæ—¶å™¨ã€å±å¹•ã€è“ç‰™ç­‰æ¨¡å—
 ****************************************************************************************
 */
void user_app_init(void)
{
	read_otp_value();  // è¯»å–OTPæ•°æ®ï¼Œåˆå§‹åŒ–å¹¿æ’­åç§°

	printk("\n\nuser_app_init! %s %08x\n", __TIME__, epd_version[2]);
    app_param_update_request_timer_used = EASY_TIMER_INVALID_TIMER;  // åˆå§‹åŒ–å‚æ•°æ›´æ–°å®šæ—¶å™¨
	app_clock_timer_used = EASY_TIMER_INVALID_TIMER;                 // åˆå§‹åŒ–æ—¶é’Ÿå®šæ—¶å™¨
    hink_d2_adv_restart_timer_hnd = EASY_TIMER_INVALID_TIMER;

	clock_interval = 60; // æ—¶é’Ÿæ›´æ–°é—´éš”è®¾ç½®ä¸º60ç§’
	clock_fixup_value = 0; // åˆå§‹åŒ–æ—¶é’Ÿä¿®æ­£å€¼
	clock_fixup_count = 0; // åˆå§‹åŒ–æ—¶é’Ÿä¿®æ­£è®¡æ•°å™¨

	first_timer_trigger = 0; // åˆå§‹åŒ–ç¬¬ä¸€æ¬¡è§¦å‘æ ‡å¿—

	adv_state = 0; // åˆå§‹åŒ–ä¸ºæœªå¹¿æ’­çŠ¶æ€
	fspi_config(0x00030605); // é…ç½®FSPIæŽ¥å£

	selflash(otp_boot); // æ ¹æ®OTPå¯åŠ¨æ•°æ®æ‰§è¡Œè‡ªé—ªå­˜æ“ä½œ
    hink_d3d_boot_load_last_known_time();

	// åˆå§‹åŒ–EPDå±å¹•ï¼ˆ2.13é»‘ç™½å±ï¼Œ6ä¸ªæµ‹è¯•ç‚¹ï¼‰
	epd_hw_init(0x23200700, 0x05210006, detect_w, detect_h, detect_mode | ROTATE_3);
	if(epd_detect()==0){  // å¦‚æžœæ£€æµ‹ä¸åˆ°å±å¹•ï¼Œå°è¯•å¦ä¸€ç§é…ç½®ï¼ˆ5ä¸ªæµ‹è¯•ç‚¹ï¼‰
		epd_hw_init(0x23111000, 0x07210120, detect_w, detect_h, detect_mode | ROTATE_3);
		epd_detect();
	}

	app_connection_idx = -1; // åˆå§‹åŒ–è¿žæŽ¥ç´¢å¼•ä¸ºæ— æ•ˆå€¼
    default_app_on_init();   // æ‰§è¡Œé»˜è®¤åº”ç”¨åˆå§‹åŒ–
}


/**
 ****************************************************************************************
 * @brief æ—¶é’Ÿå¿«æ…¢ä¿®æ­£å‡½æ•°
 * @param[in] diff_sec  è‡ªä¸Šæ¬¡å¯¹æ—¶åŽçš„è¯¯å·®ç§’æ•°ï¼ˆæ­£æ•°è¡¨ç¤ºå¿«äº†ï¼Œè´Ÿæ•°è¡¨ç¤ºæ…¢äº†ï¼‰
 * @param[in] minutes   è‡ªä¸Šæ¬¡å¯¹æ—¶åŽç»è¿‡çš„åˆ†é’Ÿæ•°
 * @note è®¡ç®—å¹¶ç´¯ç§¯æ—¶é’Ÿä¿®æ­£å€¼ï¼Œç”¨äºŽè°ƒæ•´å®šæ—¶å™¨é—´éš”ï¼Œè¡¥å¿æ—¶é’Ÿè¯¯å·®
 ****************************************************************************************
 */
void clock_fixup_set(int diff_sec, int minutes)
{
	// è®¡ç®—æ–°çš„ä¿®æ­£å€¼ï¼ˆåŸºäºŽ4096ç²¾åº¦çš„åˆ†æ•°è®¡ç®—ï¼‰
	int new_fixup_value = diff_sec*100*4096/minutes;
	clock_fixup_value += new_fixup_value; // ç´¯ç§¯ä¿®æ­£å€¼
}


/**
 ****************************************************************************************
 * @brief åº”ç”¨æ—¶é’Ÿä¿®æ­£å€¼
 * @return æœ¬æ¬¡éœ€è¦è°ƒæ•´çš„æ¯«ç§’æ•°
 * @note ä»Žç´¯ç§¯çš„ä¿®æ­£è®¡æ•°å™¨ä¸­æå–æ•´æ•°éƒ¨åˆ†ä½œä¸ºæœ¬æ¬¡è°ƒæ•´å€¼ï¼Œä¿ç•™ä½™æ•°
 ****************************************************************************************
 */
static int clock_fixup(void)
{
	int value;

	clock_fixup_count += clock_fixup_value; // ç´¯ç§¯ä¿®æ­£è®¡æ•°

	value = clock_fixup_count>>12; // å³ç§»12ä½ï¼ˆé™¤ä»¥4096ï¼‰å¾—åˆ°æ•´æ•°éƒ¨åˆ†
	clock_fixup_count &= 0xfff;    // ä¿ç•™ä½Ž12ä½ä½œä¸ºä½™æ•°

	return value; // è¿”å›žæœ¬æ¬¡è°ƒæ•´çš„æ¯«ç§’æ•°
}

extern int adcval;  // ADCç”µåŽ‹å€¼å˜é‡
/**
 ****************************************************************************************
 * @brief åº”ç”¨æ—¶é’Ÿå®šæ—¶å™¨å›žè°ƒå‡½æ•°
 *        å®šæ—¶æ›´æ–°æ—¶é’Ÿã€æŽ¨é€æ—¶é’Ÿæ•°æ®ã€å¤„ç†å±å¹•æ˜¾ç¤ºï¼Œå¹¶æ ¹æ®éœ€è¦é‡å¯å¹¿æ’­
 ****************************************************************************************
 */
static void app_clock_timer_cb(void)
{
	int adj = clock_fixup(); // èŽ·å–æ—¶é’Ÿä¿®æ­£å€¼
	int update_seconds;
	
	if(first_timer_trigger) {
		first_timer_trigger = 0;
		update_seconds = first_update_seconds;
		printk("First trigger: second=%d, update_seconds=%d\n", second, update_seconds);
	} else {
		update_seconds = clock_interval;
	}
	
	// é‡å¯å®šæ—¶å™¨ï¼Œåº”ç”¨ä¿®æ­£åŽçš„é—´éš”ï¼ˆå•ä½ï¼š10msï¼Œæ•…ä¹˜ä»¥100ï¼‰
	app_clock_timer_used = app_easy_timer(clock_interval*100+adj, app_clock_timer_cb);

	// ç¡®å®šå±å¹•æ›´æ–°æ ‡å¿—ï¼ˆæ ¹æ®æ—¶é’ŸçŠ¶æ€ï¼‰
	int flags = UPDATE_FLY; // é»˜è®¤å¿«é€Ÿæ›´æ–°
	// æ›´æ–°æ—¶é’Ÿå¹¶æ‰“å°
	int stat = clock_update(update_seconds);
	clock_print();

	// å¦‚æžœå·²è¿žæŽ¥ï¼Œåˆ™æŽ¨é€æ—¶é’Ÿæ•°æ®
	if(app_connection_idx!=-1){
		clock_push();
	}
	
    //æœªè¿›è¡Œåˆå§‹åŒ–,åˆ™å§‹ç»ˆå±•ç¤ºäºŒç»´ç 
    if(year==2025 && month<=5){
        // åœ¨2024å¹´2æœˆæ‰§è¡Œç‰¹å®šæ“ä½œï¼ˆå ä½ç¬¦ï¼‰
        QR_draw();
        user_app_adv_start();//æŒç»­å¼€å¯å¹¿æ’­
        return;
    }

    // å¦‚æžœæ˜¯å¿«é€Ÿæ›´æ–°ï¼Œæ›´æ–°ADCæ•°æ®,è‹¥ç”µé‡ä¸è¶³åˆ™ä¸ç»§ç»­æ‰§è¡Œä»»åŠ¡
	if(flags==4){
		adc1_update();
		//ADCç”µåŽ‹å°äºŽ2.6V
        if(adcval<1360){
					//ç»˜åˆ¶ä½Žç”µé‡å›¾æ ‡
            LB_draw();
					//æ¸…é™¤å®šæ—¶å™¨å”¤é†’ä»»åŠ¡
					app_easy_timer_cancel(app_clock_timer_used);
            return;
        }
	}

	if(stat>=3){
		flags = DRAW_BT | UPDATE_FULL; // éœ€è¦è“ç‰™å›¾æ ‡+å…¨é‡æ›´æ–°
	}else if(stat>=2){
		flags = DRAW_BT | UPDATE_FAST; // éœ€è¦è“ç‰™å›¾æ ‡+å¿«é€Ÿæ›´æ–°
	}

	// å¦‚æžœéœ€è¦æ˜¾ç¤ºè“ç‰™å›¾æ ‡ï¼Œå¯åŠ¨å¹¿æ’­
	if(flags&DRAW_BT){
		user_app_adv_start();
	}

	// æ ¹æ®çŠ¶æ€æˆ–æ ‡å¿—æ›´æ–°å±å¹•æ˜¾ç¤º
	if(stat>0 || flags&DRAW_BT){
		clock_draw(flags);
	}
}


/**
 ****************************************************************************************
 * @brief é‡å¯åº”ç”¨æ—¶é’Ÿå®šæ—¶å™¨
 *        è®¡ç®—åˆ°ä¸‹ä¸€ä¸ªæ•´åˆ†é’Ÿçš„å‰©ä½™ç§’æ•°ï¼Œè®¾ç½®å®šæ—¶å™¨ä½¿å…¶åœ¨æ•´åˆ†é’Ÿæ—¶è§¦å‘
 ****************************************************************************************
 */
void app_clock_timer_restart(void)
{
	app_easy_timer_cancel(app_clock_timer_used); // å–æ¶ˆå½“å‰å®šæ—¶å™¨
	
	// è®¡ç®—åˆ°ä¸‹ä¸€ä¸ªæ•´åˆ†é’Ÿçš„å‰©ä½™ç§’æ•°
	int remaining_seconds = (second == 0) ? 60 : (60 - second);
	
	// ä¿å­˜ç¬¬ä¸€æ¬¡è§¦å‘æ—¶éœ€è¦æ›´æ–°çš„ç§’æ•°ï¼ˆä½¿æ—¶é’Ÿè¿›ä½åˆ°æ•´åˆ†é’Ÿï¼‰
	first_update_seconds = remaining_seconds;
	
	// æ ‡è®°ä¸ºç¬¬ä¸€æ¬¡è§¦å‘ï¼Œç”¨äºŽåœ¨å›žè°ƒä¸­æ­£ç¡®å¤„ç†æ—¶é’Ÿæ›´æ–°
	first_timer_trigger = 1;
	
	// ç¬¬ä¸€æ¬¡åœ¨æ•´åˆ†é’Ÿè§¦å‘ï¼Œä¹‹åŽæ¯60ç§’è§¦å‘ä¸€æ¬¡
	app_clock_timer_used = app_easy_timer(remaining_seconds*100, app_clock_timer_cb);
}

void app_clock_timer_stop(void)
{
    if (app_clock_timer_used != EASY_TIMER_INVALID_TIMER)
    {
        app_easy_timer_cancel(app_clock_timer_used);
        app_clock_timer_used = EASY_TIMER_INVALID_TIMER;
    }
}


/**
 ****************************************************************************************
 * @brief æ•°æ®åº“åˆå§‹åŒ–å®Œæˆå›žè°ƒå‡½æ•°
 *        å½“GATTæ•°æ®åº“åˆå§‹åŒ–å®ŒæˆåŽè°ƒç”¨ï¼Œåˆå§‹åŒ–ADCã€æ˜¾ç¤ºæ—¶é’Ÿå¹¶å¯åŠ¨å¹¿æ’­
 ****************************************************************************************
 */
void user_app_on_db_init_complete( void )
{
	printk("\nuser_app_on_db_init_complete!\n");

	// æ›´æ–°ADCå€¼å¹¶æ‰“å°ç”µåŽ‹
	int adcval = adc1_update();
	printk("Voltage: %d\n", adcval);

	// æ‰“å°å¹¶æŽ¨é€æ—¶é’Ÿæ•°æ®
	clock_print();
	clock_push();

	// ç»˜åˆ¶æ—¶é’Ÿï¼ˆå¸¦è“ç‰™å›¾æ ‡+å…¨é‡æ›´æ–°ï¼‰å¹¶å¯åŠ¨å¹¿æ’­
	//clock_draw(DRAW_BT|UPDATE_FULL);
	QR_draw();
	user_app_adv_start();

	// å¯åŠ¨æ—¶é’Ÿå®šæ—¶å™¨ï¼Œå¯¹é½åˆ°æ•´åˆ†é’Ÿ
	app_clock_timer_restart();
}


/**
 ****************************************************************************************
 * @brief å¯åŠ¨åº”ç”¨å¹¿æ’­
 *        æž„é€ å¹¿æ’­æ•°æ®ï¼ˆåŒ…å«è®¾å¤‡åç§°å’ŒEPDç‰ˆæœ¬ï¼‰ï¼Œå¹¶å¯åŠ¨å¸¦è¶…æ—¶çš„æ— å‘å¹¿æ’­
 ****************************************************************************************
 */
void user_app_adv_start(void)
{
	u8 vbuf[4]; // ç‰ˆæœ¬ä¿¡æ¯ADç»“æž„ç¼“å†²åŒº

	// å¦‚æžœå·²åœ¨å¹¿æ’­çŠ¶æ€ï¼Œç›´æŽ¥è¿”å›ž
	if(adv_state)
		return;
	adv_state = 1; // æ ‡è®°ä¸ºæ­£åœ¨å¹¿æ’­

    // èŽ·å–å¹¿æ’­å‘½ä»¤ç»“æž„
	struct gapm_start_advertise_cmd* cmd = app_easy_gap_undirected_advertise_get_active();
	// æ·»åŠ è®¾å¤‡åç§°ADç»“æž„
	app_add_ad_struct(cmd, adv_name, adv_name[0]+1, 1);

	// æž„é€ ç‰ˆæœ¬ä¿¡æ¯ADç»“æž„ï¼ˆé•¿åº¦+ç±»åž‹+ç‰ˆæœ¬å·ä½Žä¸¤ä½ï¼‰
	vbuf[0] = 0x03;
	vbuf[1] = GAP_AD_TYPE_MANU_SPECIFIC_DATA;
	vbuf[2] = EPD_VERSION&0xff;
	vbuf[3] = (EPD_VERSION>>8)&0xff;
	app_add_ad_struct(cmd, vbuf, vbuf[0]+1, 1);

	// å¯åŠ¨å¸¦è¶…æ—¶çš„æ— å‘å¹¿æ’­
	app_easy_gap_undirected_advertise_with_timeout_start(user_default_hnd_conf.advertise_period, NULL);
	printk("\nuser_app_adv_start! %s\n", adv_name+2);
}

static void hink_d2_adv_restart_timer_cb(void)
{
    hink_d2_adv_restart_timer_hnd = EASY_TIMER_INVALID_TIMER;
    if ((app_connection_idx == -1) && (adv_state == 0))
    {
        user_app_adv_start();
    }
}

static void hink_d2_schedule_adv_restart(void)
{
    if (hink_d2_adv_restart_timer_hnd == EASY_TIMER_INVALID_TIMER)
    {
        timer_hnd hnd = app_easy_timer(1, hink_d2_adv_restart_timer_cb);
        if (hnd != EASY_TIMER_INVALID_TIMER)
        {
            hink_d2_adv_restart_timer_hnd = hnd;
        }
    }
}


/**
 ****************************************************************************************
 * @brief è¿žæŽ¥äº‹ä»¶å›žè°ƒå‡½æ•°
 *        å½“æ”¶åˆ°è¿žæŽ¥è¯·æ±‚æ—¶è°ƒç”¨ï¼Œæ›´æ–°è¿žæŽ¥ç´¢å¼•ï¼Œæ£€æŸ¥è¿žæŽ¥å‚æ•°å¹¶åœ¨éœ€è¦æ—¶è¯·æ±‚å‚æ•°æ›´æ–°
 * @param[in] connection_idx è¿žæŽ¥ç´¢å¼•
 * @param[in] param          è¿žæŽ¥è¯·æ±‚å‚æ•°
 ****************************************************************************************
 */
void user_app_connection(uint8_t connection_idx, struct gapc_connection_req_ind const *param)
{
	printk("user_app_connection: %d\n", connection_idx);

    // æ£€æŸ¥è¿žæŽ¥æ˜¯å¦æœ‰æ•ˆ
    if (app_env[connection_idx].conidx != GAP_INVALID_CONIDX)
    {
        app_connection_idx = connection_idx; // æ›´æ–°è¿žæŽ¥ç´¢å¼•

		// æ‰“å°è¿žæŽ¥å‚æ•°
		printk("  interval: %d\n", param->con_interval);
		printk("  latency : %d\n", param->con_latency);
		printk("  sup_to  : %d\n", param->sup_to);
        
        // æ£€æŸ¥è¿žæŽ¥å‚æ•°æ˜¯å¦ç¬¦åˆé¢„æœŸï¼Œä¸ç¬¦åˆåˆ™è°ƒåº¦å‚æ•°æ›´æ–°è¯·æ±‚
        if ((param->con_interval < user_connection_param_conf.intv_min) ||
            (param->con_interval > user_connection_param_conf.intv_max) ||
            (param->con_latency != user_connection_param_conf.latency) ||
            (param->sup_to != user_connection_param_conf.time_out))
        {
            app_param_update_request_timer_used = app_easy_timer(APP_PARAM_UPDATE_REQUEST_TO, param_update_request_timer_cb);
        }
		
		// æŽ¨é€æ—¶é’Ÿæ•°æ®åˆ°å®¢æˆ·ç«¯
		clock_push();
    } else {
		adv_state = 0; // è¿žæŽ¥æ— æ•ˆæ—¶ï¼Œæ ‡è®°ä¸ºæœªå¹¿æ’­
    }

    // æ‰§è¡Œé»˜è®¤è¿žæŽ¥å¤„ç†
    default_app_on_connection(connection_idx, param);
}

/**
 ****************************************************************************************
 * @brief æ— å‘å¹¿æ’­å®Œæˆå›žè°ƒå‡½æ•°
 *        å½“å¹¿æ’­è¶…æ—¶æˆ–å¼‚å¸¸ç»“æŸæ—¶è°ƒç”¨ï¼Œæ›´æ–°å¹¿æ’­çŠ¶æ€å¹¶åˆ·æ–°å±å¹•
 * @param[in] status å¹¿æ’­ç»“æŸçŠ¶æ€ç 
 ****************************************************************************************
 */
void user_app_adv_undirect_complete(uint8_t status)
{
	printk("user_app_adv_undirect_complete: %02x\n", status);
	// çŠ¶æ€éž0è¡¨ç¤ºå¼‚å¸¸ç»“æŸï¼Œæ›´æ–°å¹¿æ’­çŠ¶æ€å¹¶åˆ·æ–°å±å¹•
	if(status!=0){
		adv_state = 0;
        if ((app_connection_idx == -1) && hink_d2_dedicated_clock_active())
        {
            hink_d2_schedule_adv_restart();
            return;
        }
		//æœªè¿›è¡Œåˆå§‹åŒ–,åˆ™å§‹ç»ˆå±•ç¤ºäºŒç»´ç 
    if(year==2025 && month<=5){
        // åœ¨2024å¹´2æœˆæ‰§è¡Œç‰¹å®šæ“ä½œï¼ˆå ä½ç¬¦ï¼‰
        QR_draw();
    }
		else
		clock_draw(UPDATE_FLY);
	}
}


/**
 ****************************************************************************************
 * @brief æ–­å¼€è¿žæŽ¥å›žè°ƒå‡½æ•°
 *        å½“è¿žæŽ¥æ–­å¼€æ—¶è°ƒç”¨ï¼Œæ¸…ç†å®šæ—¶å™¨ï¼Œæ›´æ–°è¿žæŽ¥çŠ¶æ€ï¼Œå¹¶æ ¹æ®æ–­å¼€åŽŸå› å†³å®šæ˜¯å¦é‡å¯å¹¿æ’­
 * @param[in] param æ–­å¼€è¿žæŽ¥å‚æ•°ï¼ˆåŒ…å«æ–­å¼€åŽŸå› ï¼‰
 ****************************************************************************************
 */
void user_app_disconnect(struct gapc_disconnect_ind const *param)
{
	extern void hink_e4_session_reset(void);
    hink_e4_session_reset();

    printk("user_app_disconnect! reason=%02x\n", param->reason);

    // å–æ¶ˆå‚æ•°æ›´æ–°è¯·æ±‚å®šæ—¶å™¨
    if (app_param_update_request_timer_used != EASY_TIMER_INVALID_TIMER)
    {
        app_easy_timer_cancel(app_param_update_request_timer_used);
        app_param_update_request_timer_used = EASY_TIMER_INVALID_TIMER;
    }

	app_connection_idx = -1; // é‡ç½®è¿žæŽ¥ç´¢å¼•ä¸ºæ— æ•ˆå€¼
	adv_state = 0; // æ ‡è®°ä¸ºæœªå¹¿æ’­

    if (hink_d2_dedicated_clock_active())
    {
        hink_d2_schedule_adv_restart();
        return;
    }

	// éžè¿œç¨‹ç”¨æˆ·ä¸»åŠ¨æ–­å¼€æ—¶ï¼Œé‡å¯å¹¿æ’­ï¼›å¦åˆ™ä»…åˆ·æ–°å±å¹•
	if(param->reason!=CO_ERROR_REMOTE_USER_TERM_CON){
		user_app_adv_start();
	}else{
		    //æœªè¿›è¡Œåˆå§‹åŒ–,åˆ™å§‹ç»ˆå±•ç¤ºäºŒç»´ç 
    if(year==2025 && month<=5){
        // åœ¨2024å¹´2æœˆæ‰§è¡Œç‰¹å®šæ“ä½œï¼ˆå ä½ç¬¦ï¼‰
        QR_draw();
    }
		else
		clock_draw(UPDATE_FLY);
	}

}


/**
 ****************************************************************************************
 * @brief æœªå¤„ç†æ¶ˆæ¯çš„æ•èŽ·å¤„ç†å‡½æ•°
 *        å¤„ç†å„ç±»æœªè¢«é»˜è®¤å¤„ç†çš„æ¶ˆæ¯ï¼ŒåŒ…æ‹¬ç‰¹å¾å€¼è¯»å†™ã€å‚æ•°æ›´æ–°ã€MTUå˜æ›´ç­‰äº‹ä»¶
 * @param[in] msgid   æ¶ˆæ¯ID
 * @param[in] param   æ¶ˆæ¯å‚æ•°
 * @param[in] dest_id ç›®æ ‡ä»»åŠ¡ID
 * @param[in] src_id  æºä»»åŠ¡ID
 ****************************************************************************************
 */
void user_catch_rest_hndl(ke_msg_id_t const msgid,
                          void const *param,
                          ke_task_id_t const dest_id,
                          ke_task_id_t const src_id)
{
    switch(msgid)
    {
        // ç‰¹å¾å€¼å†™å…¥é€šçŸ¥ï¼ˆå€¼å·²å†™å…¥æ•°æ®åº“ï¼‰
        case CUSTS1_VAL_WRITE_IND:
        {
            struct custs1_val_write_ind const *msg_param = (struct custs1_val_write_ind const *)(param);

            // æ ¹æ®å¥æŸ„åˆ†å‘åˆ°å¯¹åº”çš„å¤„ç†å‡½æ•°
            switch (msg_param->handle)
            {
                case SVC2_IDX_HINK_WRITE_VAL:
                    user_svc1_ctrl_wr_ind_handler(msgid, msg_param, dest_id, src_id);
                    break;
                case SVC1_IDX_CONTROL_POINT_VAL:
                    user_svc1_ctrl_wr_ind_handler(msgid, msg_param, dest_id, src_id);
                    break;

                case SVC1_IDX_LONG_VALUE_VAL:
                    user_svc1_long_val_wr_ind_handler(msgid, msg_param, dest_id, src_id);
                    break;

                default:
                    break;
            }
        } break;

        // Notificationç¡®è®¤ï¼ˆè¯·æ±‚å·²å‘å‡ºï¼‰
        case CUSTS1_VAL_NTF_CFM:
        {
        } break;

        // Indicationç¡®è®¤ï¼ˆè¯·æ±‚å·²å‘å‡ºï¼‰
        case CUSTS1_VAL_IND_CFM:
        {
        } break;

        // è¯»ATT_INFOè¯·æ±‚ï¼ˆéœ€è¦è¿”å›žæ•°æ®ï¼‰
        case CUSTS1_ATT_INFO_REQ:
        {
            struct custs1_att_info_req const *msg_param = (struct custs1_att_info_req const *)param;

            // æ ¹æ®å±žæ€§ç´¢å¼•åˆ†å‘å¤„ç†
            switch (msg_param->att_idx)
            {
                case SVC1_IDX_LONG_VALUE_VAL:
                    user_svc1_long_val_att_info_req_handler(msgid, msg_param, dest_id, src_id);
                    break;

                default:
                    user_svc1_rest_att_info_req_handler(msgid, msg_param, dest_id, src_id);
                    break;
             }
        } break;

        // è¿žæŽ¥å‚æ•°æ›´æ–°é€šçŸ¥
        case GAPC_PARAM_UPDATED_IND:
        {
            struct gapc_param_updated_ind const *msg_param = (struct gapc_param_updated_ind const *)(param);
			printk("GAPC_PARAM_UPDATED_IND!\n");
			// æ‰“å°æ›´æ–°åŽçš„å‚æ•°
			printk("  interval: %d\n", msg_param->con_interval);
			printk("  latency : %d\n", msg_param->con_latency);
			printk("  sup_to  : %d\n", msg_param->sup_to);

            // æ£€æŸ¥æ›´æ–°åŽçš„å‚æ•°æ˜¯å¦ç¬¦åˆé¢„æœŸ
            if ((msg_param->con_interval >= user_connection_param_conf.intv_min) &&
                (msg_param->con_interval <= user_connection_param_conf.intv_max) &&
                (msg_param->con_latency == user_connection_param_conf.latency) &&
                (msg_param->sup_to == user_connection_param_conf.time_out))
            {
				printk("  match!\n");
            }
        } break;

        // ç‰¹å¾å€¼è¯»å–è¯·æ±‚
        case CUSTS1_VALUE_REQ_IND:
        {
			printk("CUSTS1_VALUE_REQ_IND!\n");
            struct custs1_value_req_ind const *msg_param = (struct custs1_value_req_ind const *) param;

            // å¤„ç†æœªå®šä¹‰çš„è¯»å–è¯·æ±‚ï¼Œè¿”å›žé”™è¯¯
            switch (msg_param->att_idx)
            {
                default:
                {
                    struct custs1_value_req_rsp *rsp = KE_MSG_ALLOC(CUSTS1_VALUE_REQ_RSP,
                                                                    src_id,
                                                                    dest_id,
                                                                    custs1_value_req_rsp);

                    rsp->conidx  = app_env[msg_param->conidx].conidx;
                    rsp->att_idx = msg_param->att_idx;
                    rsp->length = 0;
                    rsp->status  = ATT_ERR_APP_ERROR;
                    KE_MSG_SEND(rsp);
                } break;
             }
        } break;

        // GATTäº‹ä»¶è¯·æ±‚æŒ‡ç¤ºï¼ˆç¡®è®¤æœªå¤„ç†çš„æŒ‡ç¤ºä»¥é¿å…è¶…æ—¶ï¼‰
        case GATTC_EVENT_REQ_IND:
        {
            struct gattc_event_ind const *ind = (struct gattc_event_ind const *) param;
            struct gattc_event_cfm *cfm = KE_MSG_ALLOC(GATTC_EVENT_CFM, src_id, dest_id, gattc_event_cfm);
            cfm->handle = ind->handle;
            KE_MSG_SEND(cfm);
        } break;
		
		// MTUï¼ˆæœ€å¤§ä¼ è¾“å•å…ƒï¼‰å˜æ›´æŒ‡ç¤º
		case GATTC_MTU_CHANGED_IND:
		{
			struct gattc_mtu_changed_ind *ind = (struct gattc_mtu_changed_ind *) param;
			printk("GATTC_MTU_CHANGED_IND: %d\n", ind->mtu);
		} break;

        // æœªå¤„ç†çš„æ¶ˆæ¯
        default:
		{
			printk("Unhandled msgid=%08x\n", msgid);
		} break;
    }
}

/// @} APP
