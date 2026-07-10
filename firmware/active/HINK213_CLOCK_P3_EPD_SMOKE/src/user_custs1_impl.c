/**
 ****************************************************************************************
 *
 * @file user_custs1_impl.c
 *
 * HINK213-CLOCK Phase 2.2
 * - BLE write accepts raw 7-byte time packet: YY MM DD DOW HH MM SS
 * - Also accepts the same packet sent byte-by-byte
 * - Notifies 3 bytes HH MM SS on ADC Value 1 characteristic
 * - Starts a 1-second RAM timer and keeps time in RAM
 *
 ****************************************************************************************
 */

/*
 * INCLUDE FILES
 ****************************************************************************************
 */

#include "gpio.h"
#include "datasheet.h"
#include "app_api.h"
#include "app.h"
#include "prf_utils.h"
#include "custs1.h"
#include "custs1_task.h"
#include "user_custs1_def.h"
#include "user_custs1_impl.h"
#include "user_peripheral.h"
#include "user_periph_setup.h"

/*
 * GLOBAL VARIABLE DEFINITIONS
 ****************************************************************************************
 */

ke_msg_id_t timer_used      __SECTION_ZERO("retention_mem_area0"); //@RETENTION MEMORY
uint16_t indication_counter __SECTION_ZERO("retention_mem_area0"); //@RETENTION MEMORY
uint16_t non_db_val_counter __SECTION_ZERO("retention_mem_area0"); //@RETENTION MEMORY

uint8_t hink_time_rx_ok     __SECTION_ZERO("retention_mem_area0");
uint8_t hink_year           __SECTION_ZERO("retention_mem_area0");
uint8_t hink_month          __SECTION_ZERO("retention_mem_area0");
uint8_t hink_day            __SECTION_ZERO("retention_mem_area0");
uint8_t hink_dow            __SECTION_ZERO("retention_mem_area0");
uint8_t hink_hour           __SECTION_ZERO("retention_mem_area0");
uint8_t hink_minute         __SECTION_ZERO("retention_mem_area0");
uint8_t hink_second         __SECTION_ZERO("retention_mem_area0");

static uint8_t hink_acc[7]       __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_acc_idx      __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_ble_conidx   __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_tick_running __SECTION_ZERO("retention_mem_area0");
static ke_msg_id_t hink_tick_timer __SECTION_ZERO("retention_mem_area0");

/* HL18B dry-run transport state. Counters only; no panel framebuffer is stored. */
static uint8_t hl18b_dry_metadata_ok __SECTION_ZERO("retention_mem_area0");
static uint16_t hl18b_dry_next_seq __SECTION_ZERO("retention_mem_area0");
static uint16_t hl18b_dry_chunks __SECTION_ZERO("retention_mem_area0");
static uint16_t hl18b_dry_bytes __SECTION_ZERO("retention_mem_area0");
static uint8_t hl18b_dry_xor __SECTION_ZERO("retention_mem_area0");

/* HL22A session-bound transfer integrity state. Counters/checksum only. */
static uint8_t hl22_transfer_active __SECTION_ZERO("retention_mem_area0");
static uint8_t hl22_transfer_complete __SECTION_ZERO("retention_mem_area0");
static uint8_t hl22_transfer_id __SECTION_ZERO("retention_mem_area0");
static uint8_t hl22_transfer_session_token __SECTION_ZERO("retention_mem_area0");
static uint16_t hl22_transfer_next_seq __SECTION_ZERO("retention_mem_area0");
static uint16_t hl22_transfer_chunks __SECTION_ZERO("retention_mem_area0");
static uint16_t hl22_transfer_bytes __SECTION_ZERO("retention_mem_area0");
static uint16_t hl22_transfer_expected_crc __SECTION_ZERO("retention_mem_area0");
static uint16_t hl22_transfer_running_crc __SECTION_ZERO("retention_mem_area0");

/* HL21A bounded BLE command-session state (RAM only). */
static uint8_t hl21_session_active __SECTION_ZERO("retention_mem_area0");
static uint8_t hl21_session_token __SECTION_ZERO("retention_mem_area0");
static uint8_t hl21_session_owner_conidx __SECTION_ZERO("retention_mem_area0");
static uint8_t hl21_session_timer_running __SECTION_ZERO("retention_mem_area0");
static ke_msg_id_t hl21_session_timer __SECTION_ZERO("retention_mem_area0");

/* HL25A one-shot panel liveness state. One fire per cold boot. */
static uint8_t hl25_liveness_armed __SECTION_ZERO("retention_mem_area0");
static uint8_t hl25_liveness_used __SECTION_ZERO("retention_mem_area0");
static uint8_t hl25_liveness_arm_id __SECTION_ZERO("retention_mem_area0");
static uint8_t hl25_liveness_owner_conidx __SECTION_ZERO("retention_mem_area0");
static uint8_t hl25_liveness_session_token __SECTION_ZERO("retention_mem_area0");
static uint8_t hl25_liveness_timer_running __SECTION_ZERO("retention_mem_area0");
static ke_msg_id_t hl25_liveness_timer __SECTION_ZERO("retention_mem_area0");

static ke_msg_id_t hink_epd_timer __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_epd_busy_job __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_epd_job_sub __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_epd_phase __SECTION_ZERO("retention_mem_area0");
static uint16_t hink_epd_index __SECTION_ZERO("retention_mem_area0");

static uint8_t hink_epd_inv_dc __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_epd_inv_cs __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_epd_rst_active_high __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_epd_skip_soft_reset __SECTION_ZERO("retention_mem_area0");
static uint8_t hink_epd_spi_cp_mode __SECTION_ZERO("retention_mem_area0");

#define HINK_TIME_PACKET_LEN     7
#define HINK_NOTIFY_LEN          3
#define HINK_TICK_1S_DELAY       100     // app_easy_timer unit is 10 ms in SDK6 examples

/*
 * P3 EPD ORIGMAP SAFE BOOTCFG.
 * Pins are configured once at boot in user_periph_setup.c.
 * BLE handler only toggles already-configured GPIOs.
 *
 * Reverse candidate map:
 *   CLK  = P0_0
 *   CS   = P2_1
 *   RST  = P0_7
 *   DC   = P0_5
 *   MOSI = P0_6
 *   BUSY = P2_0 (defined but not used for wait in this first smoke)
 */
#define HINK_EPD_CLK_PORT       GPIO_PORT_0
#define HINK_EPD_CLK_PIN        GPIO_PIN_0
#define HINK_EPD_CS_PORT        GPIO_PORT_2
#define HINK_EPD_CS_PIN         GPIO_PIN_1
#define HINK_EPD_RST_PORT       GPIO_PORT_0
#define HINK_EPD_RST_PIN        GPIO_PIN_7
#define HINK_EPD_DC_PORT        GPIO_PORT_0
#define HINK_EPD_DC_PIN         GPIO_PIN_5
#define HINK_EPD_MOSI_PORT      GPIO_PORT_0
#define HINK_EPD_MOSI_PIN       GPIO_PIN_6
#define HINK_EPD_BUSY_PORT      GPIO_PORT_2
#define HINK_EPD_BUSY_PIN       GPIO_PIN_0
#define HINK_EPD_PWR_PORT       GPIO_PORT_2
#define HINK_EPD_PWR_PIN        GPIO_PIN_3

#define HINK_EPD_X_BYTES        16
#define HINK_EPD_Y_LINES        296
#define HINK_EPD_TOTAL_BYTES    (HINK_EPD_X_BYTES * HINK_EPD_Y_LINES)
#define HINK_EPD_CHUNK_BYTES    64

#define HL25_LIVENESS_JOB_SUB          0x25
#define HL25_LIVENESS_ARM_TIMEOUT_10MS 1000U
#define HL25_LIVENESS_ARM_TIMEOUT_SEC  10U

static const uint8_t hink_lut0_30[30] = {
    0x50,0xAA,0x55,0xAA,0x11,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0xFF,0xFF,0x1F,0x00,0x00,0x00,0x00,0x00,0x00,0x00
};

static const uint8_t hink_lut1_30[30] = {
    0x10,0x18,0x18,0x08,0x18,0x18,0x08,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x13,0x14,0x44,0x12,0x00,0x00,0x00,0x00,0x00,0x00
};

/*
 * LOCAL FUNCTION PROTOTYPES
 ****************************************************************************************
 */

static void hink_tick_cb_handler(void);
static void hink_notify_bytes(const uint8_t *data, uint8_t len);

static void hl18b_dry_reset(void);
static uint8_t hl18b_dry_handle(struct custs1_val_write_ind const *param,
                                uint8_t conidx);

static void hl22_transfer_reset(void);
static uint8_t hl22_transfer_handle(struct custs1_val_write_ind const *param,
                                    uint8_t conidx);

static void hl21_session_timeout_cb(void);
static uint8_t hl21_session_handle(struct custs1_val_write_ind const *param,
                                   uint8_t conidx);
static uint8_t hl21_session_is_valid(uint8_t conidx);
static void hl21_session_touch(void);

static void hl25_liveness_disarm(void);
static void hl25_liveness_timeout_cb(void);
static uint8_t hl25_liveness_handle(struct custs1_val_write_ind const *param,
                                    uint8_t conidx);

static void hink_epd_notify(uint8_t subcmd, uint8_t status);
static uint8_t hink_epd_panel_job_is_locked(uint8_t subcmd);
static void hink_epd_command(uint8_t subcmd);
static void hink_epd_mini_diag(uint8_t subcmd);
static void hink_epd_gpio_idle_only(void);
static uint8_t hink_epd_busy_bit(void);
static void hink_epd_schedule(uint16_t delay_10ms);
static void hink_epd_job_step_cb(void);
static void hink_epd_idle_pins(void);
static void hink_epd_select(void);
static void hink_epd_deselect(void);
static void hink_epd_dc_cmd(void);
static void hink_epd_dc_data(void);
static void hink_epd_hwspi_init(void);
static uint16_t hink_epd_hwspi_xfer(uint16_t v);
static void hink_epd_spi_byte(uint8_t v);
static void hink_epd_write_cmd(uint8_t cmd);
static void hink_epd_write_data(uint8_t data);
static void hink_epd_cmd1(uint8_t cmd, uint8_t d0);
static void hink_epd_cmd3(uint8_t cmd, uint8_t d0, uint8_t d1, uint8_t d2);
static void hink_epd_cmd4(uint8_t cmd, uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3);
static void hink_epd_write_lut(const uint8_t *lut);
static void hink_epd_set_ram_pos(uint16_t y);
static void hink_epd_init_seq(void);
static uint8_t hink_epd_pattern_byte(uint16_t idx);
static void hink_epd_set_variant(uint8_t inv_dc, uint8_t inv_cs, uint8_t rst_active_high, uint8_t skip_soft_reset, uint8_t spi_cp_mode);
static void hink_epd_start_job(uint8_t subcmd);
static void hink_epd_job_done(uint8_t status);

static void hink_epd_notify(uint8_t subcmd, uint8_t status)
{
    uint8_t msg[3];
    msg[0] = 0xE2;
    msg[1] = subcmd;
    msg[2] = status;
    hink_notify_bytes(msg, 3);
}

static void hink_epd_schedule(uint16_t delay_10ms)
{
    hink_epd_timer = app_easy_timer(delay_10ms, hink_epd_job_step_cb);
}

static void hink_epd_gpio_idle_only(void)
{
    // Idle pins only. Variant-safe: CS/RST/DC polarity can be changed per job.
    if (hink_epd_inv_cs)
    {
        GPIO_SetInactive(HINK_EPD_CS_PORT, HINK_EPD_CS_PIN);   // active-high CS: idle low
    }
    else
    {
        GPIO_SetActive(HINK_EPD_CS_PORT, HINK_EPD_CS_PIN);     // active-low CS: idle high
    }

    if (hink_epd_rst_active_high)
    {
        GPIO_SetInactive(HINK_EPD_RST_PORT, HINK_EPD_RST_PIN); // active-high reset: idle low
    }
    else
    {
        GPIO_SetActive(HINK_EPD_RST_PORT, HINK_EPD_RST_PIN);   // active-low reset: idle high
    }

    if (hink_epd_inv_dc)
    {
        GPIO_SetActive(HINK_EPD_DC_PORT, HINK_EPD_DC_PIN);     // inverted DC command idle
    }
    else
    {
        GPIO_SetInactive(HINK_EPD_DC_PORT, HINK_EPD_DC_PIN);   // normal DC command idle
    }
}

static uint8_t hink_epd_busy_bit(void)
{
    return GPIO_GetPinStatus(HINK_EPD_BUSY_PORT, HINK_EPD_BUSY_PIN) ? 1 : 0;
}

static void hink_epd_idle_pins(void)
{
    /* Original vendor firmware configures P2_3 as output HIGH before EPD access.
     * Keep it HIGH here as a suspected panel/SPI rail enable.
     */
    GPIO_SetActive(HINK_EPD_PWR_PORT, HINK_EPD_PWR_PIN);
    hink_epd_gpio_idle_only();
    hink_epd_hwspi_init();
}

static void hink_epd_select(void)
{
    if (hink_epd_inv_cs)
    {
        GPIO_SetActive(HINK_EPD_CS_PORT, HINK_EPD_CS_PIN);
    }
    else
    {
        GPIO_SetInactive(HINK_EPD_CS_PORT, HINK_EPD_CS_PIN);
    }
}

static void hink_epd_deselect(void)
{
    if (hink_epd_inv_cs)
    {
        GPIO_SetInactive(HINK_EPD_CS_PORT, HINK_EPD_CS_PIN);
    }
    else
    {
        GPIO_SetActive(HINK_EPD_CS_PORT, HINK_EPD_CS_PIN);
    }
}

static void hink_epd_dc_cmd(void)
{
    if (hink_epd_inv_dc)
    {
        GPIO_SetActive(HINK_EPD_DC_PORT, HINK_EPD_DC_PIN);
    }
    else
    {
        GPIO_SetInactive(HINK_EPD_DC_PORT, HINK_EPD_DC_PIN);
    }
}

static void hink_epd_dc_data(void)
{
    if (hink_epd_inv_dc)
    {
        GPIO_SetInactive(HINK_EPD_DC_PORT, HINK_EPD_DC_PIN);
    }
    else
    {
        GPIO_SetActive(HINK_EPD_DC_PORT, HINK_EPD_DC_PIN);
    }
}

static void hink_epd_hwspi_init(void)
{
    /*
     * HWSPI CLKEN fix:
     * The previous TXH_FIX wrote SPI registers directly but did not explicitly
     * enable the SPI peripheral clock in CLK_PER_REG. SDK spi_initialize() does
     * that before touching SPI_CTRL_REGF. Without the clock, TXH can accept a
     * write but SPI_BUSY may never clear.
     */
    volatile uint16_t *spi = (volatile uint16_t *)0x50001200UL;
    uint16_t r;

    GPIO_SetActive(HINK_EPD_PWR_PORT, HINK_EPD_PWR_PIN);
    SetBits16(CLK_PER_REG, SPI_ENABLE, 1);

    /* Switch SPI off while changing mode/speed/word fields. */
    r = spi[0];
    r &= (uint16_t)~0x0001;
    spi[0] = r;

    /* Master, selectable CPOL/CPHA, slowest speed selector 0, 8-bit word. */
    r = spi[0];
    r &= (uint16_t)~(SPI_PHA | SPI_POL | SPI_CLK | SPI_SMN | SPI_WORD | SPI_MINT);
    if (hink_epd_spi_cp_mode & 0x01)
    {
        r |= SPI_PHA;
    }
    if (hink_epd_spi_cp_mode & 0x02)
    {
        r |= SPI_POL;
    }
    spi[0] = r;

    /* FIFO write-only mode default for send path. */
    spi[4] &= (uint16_t)~SPI_FIFO_MODE;
    spi[4] |= 0x0002;

    /* Clear stale IRQ. */
    spi[3] = 0x0001;

    /* Switch SPI on. */
    spi[0] |= SPI_ON;
}

static uint16_t hink_epd_hwspi_xfer(uint16_t v)
{
    /*
     * HWSPI TXH fix for DA14585/SDK6:
     * SDK spi_send() waits for SPI_TXH == 0, writes SPI_RX_TX_REG0F,
     * clears SPI_CLEAR_INT_REGF, then waits SPI_BUSY to clear.
     * The previous diagnostic waited for SPI_INT_BIT, which can stay 0
     * in write-only FIFO mode and caused F1 timeouts.
     */
    volatile uint16_t *spi = (volatile uint16_t *)0x50001200UL;
    uint32_t guard;
    uint16_t r;
    volatile uint16_t dump;

    /* FIFO write-only mode: SPI_CTRL_REG1F.SPI_FIFO_MODE = 2 */
    r = spi[4];
    r &= (uint16_t)~0x0003;
    r |= 0x0002;
    spi[4] = r;

    /* Clear any stale interrupt condition, bounded. */
    for (guard = 0; guard < 16UL; guard++)
    {
        if ((spi[0] & SPI_INT_BIT) == 0)
        {
            break;
        }
        dump = spi[1];
        (void)dump;
        spi[3] = 0x0001;
    }

    /* Wait until TX FIFO is not high/full: SPI_CTRL_REGF.SPI_TXH == 0. */
    for (guard = 0; guard < 20000UL; guard++)
    {
        if ((spi[0] & SPI_TXH) == 0)
        {
            break;
        }
    }
    if (guard >= 20000UL)
    {
        return 0x00F1;       /* TXH stuck */
    }

    /* Send 8-bit data. */
    spi[1] = (uint16_t)(v & 0x00FF);
    spi[3] = 0x0001;

    /* Wait until SPI is no longer busy: SPI_CTRL_REG1F.SPI_BUSY == 0. */
    for (guard = 0; guard < 20000UL; guard++)
    {
        if ((spi[4] & SPI_BUSY) == 0)
        {
            return 0x0002;   /* success */
        }
    }

    return 0x00F2;           /* BUSY stuck */
}

static void hink_epd_spi_byte(uint8_t v)
{
    hink_epd_hwspi_xfer(v);
}

static void hink_epd_write_cmd(uint8_t cmd)
{
    hink_epd_dc_cmd();
    hink_epd_select();
    hink_epd_spi_byte(cmd);
    hink_epd_deselect();
}

static void hink_epd_write_data(uint8_t data)
{
    hink_epd_dc_data();
    hink_epd_select();
    hink_epd_spi_byte(data);
    hink_epd_deselect();
}

static void hink_epd_cmd1(uint8_t cmd, uint8_t d0)
{
    hink_epd_write_cmd(cmd);
    hink_epd_write_data(d0);
}

static void hink_epd_cmd3(uint8_t cmd, uint8_t d0, uint8_t d1, uint8_t d2)
{
    hink_epd_write_cmd(cmd);
    hink_epd_write_data(d0);
    hink_epd_write_data(d1);
    hink_epd_write_data(d2);
}

static void hink_epd_cmd4(uint8_t cmd, uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3)
{
    hink_epd_write_cmd(cmd);
    hink_epd_write_data(d0);
    hink_epd_write_data(d1);
    hink_epd_write_data(d2);
    hink_epd_write_data(d3);
}

static void hink_epd_write_lut(const uint8_t *lut)
{
    uint8_t i;
    hink_epd_write_cmd(0x32);
    for (i = 0; i < 30; i++)
    {
        hink_epd_write_data(lut[i]);
    }
}

static void hink_epd_set_ram_pos(uint16_t y)
{
    hink_epd_cmd1(0x4E, 0x00);
    hink_epd_write_cmd(0x4F);
    hink_epd_write_data((uint8_t)(y & 0xFF));
    hink_epd_write_data((uint8_t)(y >> 8));
}

static void hink_epd_init_seq(void)
{
    const uint8_t *lut = (hink_epd_job_sub == 0x04) ? hink_lut1_30 : hink_lut0_30;

    // Exact sequence extracted from PP_14585_2.13L_BW_DC.bin around epd_init/EPD_Display.
    // No 0x12 soft reset here: original code uses hardware reset then this sequence.
    hink_epd_cmd3(0x01, 0x27, 0x01, 0x00);
    hink_epd_cmd3(0x0C, 0xD7, 0xD6, 0x9D);
    hink_epd_cmd1(0x2C, 0xA8);
    hink_epd_cmd1(0x3A, 0x1A);
    hink_epd_cmd1(0x3B, 0x08);
    hink_epd_cmd1(0x3C, 0x03);
    hink_epd_cmd1(0x11, 0x03);
    hink_epd_write_lut(lut);
    hink_epd_write_cmd(0x44);
    hink_epd_write_data(0x00);
    hink_epd_write_data(0x10);
    hink_epd_cmd4(0x45, 0x00, 0x00, 0x28, 0x01);
}

static uint8_t hink_epd_pattern_byte(uint16_t idx)
{
    uint16_t row = idx / HINK_EPD_X_BYTES;
    uint8_t col = (uint8_t)(idx % HINK_EPD_X_BYTES);
    uint8_t band;

    if (hink_epd_job_sub == HL25_LIVENESS_JOB_SUB)
    {
        /*
         * Fixed, unmistakable liveness pattern:
         * - 8-pixel border at left/right,
         * - 8-row border at top/bottom,
         * - large alternating checker blocks inside.
         *
         * Pixel polarity is irrelevant to liveness: either polarity still
         * produces a high-contrast geometric pattern after one refresh.
         */
        if ((row < 8U) || (row >= (HINK_EPD_Y_LINES - 8U)) ||
            (col == 0U) || (col == (HINK_EPD_X_BYTES - 1U)))
        {
            return 0xFF;
        }

        band = (uint8_t)(((row / 24U) + (col / 4U)) & 0x01U);
        return band ? 0x00 : 0xFF;
    }

    band = (uint8_t)((row >> 4) & 0x01U);
    return band ? 0x00 : 0xFF;
}

static void hink_epd_set_variant(uint8_t inv_dc, uint8_t inv_cs, uint8_t rst_active_high, uint8_t skip_soft_reset, uint8_t spi_cp_mode)
{
    hink_epd_inv_dc = inv_dc;
    hink_epd_inv_cs = inv_cs;
    hink_epd_rst_active_high = rst_active_high;
    hink_epd_skip_soft_reset = skip_soft_reset;
    hink_epd_spi_cp_mode = spi_cp_mode;
}

static void hink_epd_start_job(uint8_t subcmd)
{
    if (hink_epd_busy_job)
    {
        hink_epd_notify(subcmd, 0xB5);
        return;
    }

    hink_epd_busy_job = 1;
    hink_epd_job_sub = subcmd;
    hink_epd_phase = 1;
    hink_epd_index = 0;
    hink_epd_notify(subcmd, 0x10);
    GPIO_SetActive(HINK_EPD_PWR_PORT, HINK_EPD_PWR_PIN);
    hink_epd_idle_pins();
    hink_epd_schedule(1);
}

static void hink_epd_job_done(uint8_t status)
{
    uint8_t sub = hink_epd_job_sub;
    hink_epd_busy_job = 0;
    hink_epd_phase = 0;
    hink_epd_idle_pins();
    hink_epd_notify(sub, status);
}

static void hink_epd_job_step_cb(void)
{
    uint16_t n;

    switch (hink_epd_phase)
    {
        case 1:
            // Hardware reset pulse, selectable polarity.
            if (hink_epd_rst_active_high)
            {
                GPIO_SetActive(HINK_EPD_RST_PORT, HINK_EPD_RST_PIN);
            }
            else
            {
                GPIO_SetInactive(HINK_EPD_RST_PORT, HINK_EPD_RST_PIN);
            }
            hink_epd_phase = 2;
            hink_epd_schedule(2);
            break;

        case 2:
            if (hink_epd_rst_active_high)
            {
                GPIO_SetInactive(HINK_EPD_RST_PORT, HINK_EPD_RST_PIN);
            }
            else
            {
                GPIO_SetActive(HINK_EPD_RST_PORT, HINK_EPD_RST_PIN);
            }
            hink_epd_phase = 3;
            hink_epd_schedule(5);
            break;

        case 3:
            // Optional soft reset before init.
            if (hink_epd_skip_soft_reset)
            {
                hink_epd_phase = 4;
                hink_epd_schedule(1);
            }
            else
            {
                hink_epd_write_cmd(0x12);
                hink_epd_phase = 4;
                hink_epd_schedule(20);
            }
            break;

        case 4:
            hink_epd_init_seq();
            if (hink_epd_job_sub == 0x02)
            {
                hink_epd_job_done(0x02);
            }
            else
            {
                hink_epd_phase = 5;
                hink_epd_schedule(1);
            }
            break;

        case 5:
            /* Exact vendor-style RAM write: for every row, set X/Y RAM address,
             * send 0x24, then send exactly 16 bytes. Older builds streamed one
             * long 0x24 payload; this build matches the reversed vendor loop.
             */
            hink_epd_index = 0;     /* row index 0..295 */
            hink_epd_phase = 6;
            hink_epd_schedule(1);
            break;

        case 6:
            n = 0;
            while ((n < 4U) && (hink_epd_index < HINK_EPD_Y_LINES))
            {
                uint8_t col;
                uint16_t row = hink_epd_index;
                hink_epd_set_ram_pos(row);
                hink_epd_write_cmd(0x24);
                for (col = 0; col < HINK_EPD_X_BYTES; col++)
                {
                    hink_epd_write_data(hink_epd_pattern_byte((uint16_t)(row * HINK_EPD_X_BYTES + col)));
                }
                hink_epd_index++;
                n++;
            }

            if (hink_epd_index < HINK_EPD_Y_LINES)
            {
                hink_epd_schedule(1);
            }
            else
            {
                hink_epd_phase = 7;
                hink_epd_schedule(1);
            }
            break;

        case 7:
            hink_epd_cmd1(0x22, 0xC4);
            hink_epd_write_cmd(0x20);
            hink_epd_phase = 8;
            hink_epd_schedule(350);
            break;

        case 8:
            hink_epd_cmd1(0x10, 0x01);
            hink_epd_job_done(0x02);
            break;

        default:
            hink_epd_job_done(0xEE);
            break;
    }
}


static void hink_epd_mini_diag(uint8_t subcmd)
{
    uint16_t st;
    uint8_t code;

    switch (subcmd)
    {
        case 0x40:
            // GPIO idle only. No hardware SPI access.
            hink_epd_gpio_idle_only();
            hink_epd_notify(0x40, 0x02);
            break;

        case 0x41:
            // Hardware SPI register init only. No transfer.
            hink_epd_gpio_idle_only();
            hink_epd_hwspi_init();
            hink_epd_notify(0x41, 0x02);
            break;

        case 0x42:
            // One bounded SPI byte, command-like with CS/DC.
            hink_epd_gpio_idle_only();
            hink_epd_hwspi_init();
            hink_epd_dc_cmd();
            hink_epd_select();
            st = hink_epd_hwspi_xfer(0x00);
            hink_epd_deselect();
            code = (uint8_t)(st & 0xFF);
            hink_epd_notify(0x42, code);
            break;

        case 0x43:
            // Soft reset command 0x12, bounded single byte only.
            hink_epd_gpio_idle_only();
            hink_epd_hwspi_init();
            hink_epd_dc_cmd();
            hink_epd_select();
            st = hink_epd_hwspi_xfer(0x12);
            hink_epd_deselect();
            code = (st == 0x0002) ? (uint8_t)(0x10 | hink_epd_busy_bit()) : (uint8_t)(st & 0xFF);
            hink_epd_notify(0x43, code);
            break;

        case 0x44:
            // Read BUSY only.
            hink_epd_notify(0x44, hink_epd_busy_bit() ? 0x01 : 0x00);
            break;

        case 0x45:
            // Reset pulse only, no SPI.
            hink_epd_gpio_idle_only();
            GPIO_SetInactive(HINK_EPD_RST_PORT, HINK_EPD_RST_PIN);
            // Short bounded pulse.
            for (st = 0; st < 10000; st++) { __asm volatile ("nop"); }
            GPIO_SetActive(HINK_EPD_RST_PORT, HINK_EPD_RST_PIN);
            hink_epd_notify(0x45, (uint8_t)(0x10 | hink_epd_busy_bit()));
            break;

        case 0x46:
            // Reset pulse, then one bounded 0x12 byte.
            hink_epd_gpio_idle_only();
            GPIO_SetInactive(HINK_EPD_RST_PORT, HINK_EPD_RST_PIN);
            for (st = 0; st < 10000; st++) { __asm volatile ("nop"); }
            GPIO_SetActive(HINK_EPD_RST_PORT, HINK_EPD_RST_PIN);
            hink_epd_hwspi_init();
            hink_epd_dc_cmd();
            hink_epd_select();
            st = hink_epd_hwspi_xfer(0x12);
            hink_epd_deselect();
            code = (st == 0x0002) ? (uint8_t)(0x20 | hink_epd_busy_bit()) : (uint8_t)(st & 0xFF);
            hink_epd_notify(0x46, code);
            break;

        default:
            hink_epd_notify(subcmd, 0xEE);
            break;
    }
}

/*
 * HL20A_PANEL_JOB_KILL_SWITCH
 *
 * Block every E2 command that can start an asynchronous panel job.
 * E2 E0 00 00 00 00 00 -> E2 E0 A1
 * blocked command -> E2 <subcmd> F0
 */
#define HINK_EPD_LOCK_SIGNATURE       0xA1
#define HINK_EPD_PANEL_JOB_LOCKED     0xF0

static uint8_t hink_epd_panel_job_is_locked(uint8_t subcmd)
{
    switch (subcmd)
    {
        case 0x02:
        case 0x03:
        case 0x04:
        case 0x30:
        case 0x31:
        case 0x32:
        case 0x33:
        case 0x34:
        case 0x35:
        case 0x36:
        case 0x37:
        case 0x50:
        case 0x51:
        case 0x52:
        case 0x53:
        case 0x54:
            return 1;

        default:
            return 0;
    }
}

static void hink_epd_command(uint8_t subcmd)
{
    uint8_t msg[3];

    if (hink_epd_panel_job_is_locked(subcmd))
    {
        hink_epd_notify(subcmd, HINK_EPD_PANEL_JOB_LOCKED);
        return;
    }

    switch (subcmd)
    {
        case 0xE0:
            /* Safe query proving the HL20A kill-switch is active. */
            hink_epd_notify(0xE0, HINK_EPD_LOCK_SIGNATURE);
            break;

        case 0x40:
        case 0x41:
        case 0x42:
        case 0x43:
        case 0x44:
        case 0x45:
        case 0x46:
            hink_epd_mini_diag(subcmd);
            break;

        // HL16 panel descriptor for HINK213 2.13 BW.
        // Query with: E2 D0..D5 00 00 00 00 00
        case 0xD0:
            hink_epd_notify(0xD0, 0x01); // driver id: HINK213 2.13 BW
            break;

        case 0xD1:
            hink_epd_notify(0xD1, 0x80); // width low: 128
            break;

        case 0xD2:
            hink_epd_notify(0xD2, 0x00); // width high
            break;

        case 0xD3:
            hink_epd_notify(0xD3, 0x28); // height low: 296 = 0x0128
            break;

        case 0xD4:
            hink_epd_notify(0xD4, 0x01); // height high
            break;

        case 0xD5:
            hink_epd_notify(0xD5, 0x10); // x bytes: 16
            break;
        case 0x00:
            hink_epd_notify(0x00, 0x02);
            break;

        case 0x01:
            // Quick pin-combo ping, no EPD protocol.
            hink_epd_notify(0x01, 0x01);
            hink_epd_idle_pins();
            GPIO_SetInactive(HINK_EPD_DC_PORT, HINK_EPD_DC_PIN);
            GPIO_SetActive(HINK_EPD_DC_PORT, HINK_EPD_DC_PIN);
            GPIO_SetInactive(HINK_EPD_CLK_PORT, HINK_EPD_CLK_PIN);
            GPIO_SetActive(HINK_EPD_CLK_PORT, HINK_EPD_CLK_PIN);
            GPIO_SetInactive(HINK_EPD_CLK_PORT, HINK_EPD_CLK_PIN);
            GPIO_SetInactive(HINK_EPD_MOSI_PORT, HINK_EPD_MOSI_PIN);
            GPIO_SetActive(HINK_EPD_MOSI_PORT, HINK_EPD_MOSI_PIN);
            GPIO_SetInactive(HINK_EPD_MOSI_PORT, HINK_EPD_MOSI_PIN);
            hink_epd_idle_pins();
            hink_epd_notify(0x01, 0x02);
            break;

        case 0x02:
            // Reset + init only. No framebuffer, no refresh.
            hink_epd_start_job(0x02);
            break;

        case 0x03:
            // Exact replay, LUT0, stripe refresh.
            hink_epd_set_variant(0, 0, 0, 0, 0);
            hink_epd_start_job(0x03);
            break;

        case 0x04:
            // Exact replay, LUT1, stripe refresh.
            hink_epd_set_variant(0, 0, 0, 0, 0);
            hink_epd_start_job(0x04);
            break;

        case 0x48:
            // P2_3 suspected EPD/SPI rail enable HIGH only, then report BUSY.
            GPIO_SetActive(HINK_EPD_PWR_PORT, HINK_EPD_PWR_PIN);
            msg[0] = 0xE2;
            msg[1] = subcmd;
            msg[2] = (uint8_t)(0x10 | hink_epd_busy_bit());
            hink_notify_bytes(msg, 3);
            break;

        case 0x49:
            // P2_3 enable HIGH + idle pins only. Safe ping.
            GPIO_SetActive(HINK_EPD_PWR_PORT, HINK_EPD_PWR_PIN);
            hink_epd_idle_pins();
            msg[0] = 0xE2;
            msg[1] = subcmd;
            msg[2] = (uint8_t)(0x20 | hink_epd_busy_bit());
            hink_notify_bytes(msg, 3);
            break;

        case 0x30:
            // HWSPI variant: normal, skip soft reset. P2_3 forced HIGH.
            hink_epd_set_variant(0, 0, 0, 1, 0);
            hink_epd_start_job(0x30);
            break;

        case 0x31:
            // HWSPI variant: normal, with soft reset.
            hink_epd_set_variant(0, 0, 0, 0, 0);
            hink_epd_start_job(0x31);
            break;

        case 0x32:
            // HWSPI variant: invert DC polarity.
            hink_epd_set_variant(1, 0, 0, 1, 0);
            hink_epd_start_job(0x32);
            break;

        case 0x33:
            // HWSPI variant: invert CS polarity.
            hink_epd_set_variant(0, 1, 0, 1, 0);
            hink_epd_start_job(0x33);
            break;

        case 0x34:
            // HWSPI variant: SPI CP mode 1 (CPHA=1, CPOL=0).
            hink_epd_set_variant(0, 0, 0, 1, 1);
            hink_epd_start_job(0x34);
            break;

        case 0x35:
            // HWSPI variant: SPI CP mode 3 (CPHA=1, CPOL=1).
            hink_epd_set_variant(0, 0, 0, 1, 3);
            hink_epd_start_job(0x35);
            break;

        case 0x36:
            // HWSPI variant: reset active-high.
            hink_epd_set_variant(0, 0, 1, 1, 0);
            hink_epd_start_job(0x36);
            break;

        case 0x37:
            // HWSPI variant: invert DC + reset active-high.
            hink_epd_set_variant(1, 0, 1, 1, 0);
            hink_epd_start_job(0x37);
            break;

        case 0x50:
            // ROMSPI + exact row loop: normal, preserve current CPOL/CPHA, skip soft reset.
            hink_epd_set_variant(0, 0, 0, 1, 0xFF);
            hink_epd_start_job(0x50);
            break;

        case 0x51:
            // ROMSPI + exact row loop: normal, preserve current CPOL/CPHA, with soft reset.
            hink_epd_set_variant(0, 0, 0, 0, 0xFF);
            hink_epd_start_job(0x51);
            break;

        case 0x52:
            // ROMSPI + exact row loop: reset active-high, preserve current CPOL/CPHA.
            hink_epd_set_variant(0, 0, 1, 1, 0xFF);
            hink_epd_start_job(0x52);
            break;

        case 0x53:
            // ROMSPI + exact row loop: force CP mode 0 explicitly.
            hink_epd_set_variant(0, 0, 0, 1, 0);
            hink_epd_start_job(0x53);
            break;

        case 0x54:
            // ROMSPI + exact row loop: force CP mode 3.
            hink_epd_set_variant(0, 0, 0, 1, 3);
            hink_epd_start_job(0x54);
            break;

        default:
            msg[0] = 0xE2;
            msg[1] = subcmd;
            msg[2] = 0xEE;
            hink_notify_bytes(msg, 3);
            break;
    }
}

static uint8_t hink_is_leap_year(uint8_t yy)
{
    uint16_t year = 2000 + yy;
    return (((year % 4) == 0) && (((year % 100) != 0) || ((year % 400) == 0)));
}

static uint8_t hink_days_in_month(uint8_t yy, uint8_t mm)
{
    static const uint8_t days[12] = {31,28,31,30,31,30,31,31,30,31,30,31};

    if ((mm < 1) || (mm > 12))
    {
        return 31;
    }

    if ((mm == 2) && hink_is_leap_year(yy))
    {
        return 29;
    }

    return days[mm - 1];
}

static void hink_notify_bytes(const uint8_t *data, uint8_t len)
{
    if (ke_state_get(TASK_APP) != APP_CONNECTED)
    {
        return;
    }

    struct custs1_val_set_req *set_req = KE_MSG_ALLOC_DYN(CUSTS1_VAL_SET_REQ,
                                                          prf_get_task_from_id(TASK_ID_CUSTS1),
                                                          TASK_APP,
                                                          custs1_val_set_req,
                                                          len);

    set_req->handle = SVC1_IDX_ADC_VAL_1_VAL;
    set_req->length = len;
    memcpy(set_req->value, data, len);
    ke_msg_send(set_req);

    struct custs1_val_ntf_ind_req *ntf_req = KE_MSG_ALLOC_DYN(CUSTS1_VAL_NTF_REQ,
                                                              prf_get_task_from_id(TASK_ID_CUSTS1),
                                                              TASK_APP,
                                                              custs1_val_ntf_ind_req,
                                                              len);

    ntf_req->conidx = hink_ble_conidx;
    ntf_req->handle = SVC1_IDX_ADC_VAL_1_VAL;
    ntf_req->length = len;
    ntf_req->notification = true;
    memcpy(ntf_req->value, data, len);
    ke_msg_send(ntf_req);
}

static void hink_notify_time(void)
{
    uint8_t out[HINK_NOTIFY_LEN];
    out[0] = hink_hour;
    out[1] = hink_minute;
    out[2] = hink_second;
    hink_notify_bytes(out, HINK_NOTIFY_LEN);
}

static void hink_notify_debug(uint8_t a, uint8_t b)
{
    uint8_t out[2];
    out[0] = a;
    out[1] = b;
    hink_notify_bytes(out, 2);
}

static void hink_load_time_packet(const uint8_t *v)
{
    hink_year   = v[0];
    hink_month  = v[1];
    hink_day    = v[2];
    hink_dow    = v[3];
    hink_hour   = v[4];
    hink_minute = v[5];
    hink_second = v[6];

    // Minimal guardrails so a bad packet will not make timekeeping weird.
    if (hink_month < 1 || hink_month > 12)  hink_month = 1;
    if (hink_day < 1 || hink_day > 31)      hink_day = 1;
    if (hink_hour > 23)                    hink_hour = 0;
    if (hink_minute > 59)                  hink_minute = 0;
    if (hink_second > 59)                  hink_second = 0;

    hink_time_rx_ok = 1;
}

static void hink_advance_one_second(void)
{
    if (!hink_time_rx_ok)
    {
        return;
    }

    hink_second++;
    if (hink_second < 60)
    {
        return;
    }

    hink_second = 0;
    hink_minute++;
    if (hink_minute < 60)
    {
        return;
    }

    hink_minute = 0;
    hink_hour++;
    if (hink_hour < 24)
    {
        return;
    }

    hink_hour = 0;
    hink_day++;
    hink_dow = (hink_dow + 1) % 7;

    if (hink_day > hink_days_in_month(hink_year, hink_month))
    {
        hink_day = 1;
        hink_month++;
        if (hink_month > 12)
        {
            hink_month = 1;
            hink_year++;
        }
    }
}

static void hink_start_tick_timer(void)
{
    if (hink_tick_running)
    {
        app_easy_timer_cancel(hink_tick_timer);
        hink_tick_running = 0;
    }

    hink_tick_timer = app_easy_timer(HINK_TICK_1S_DELAY, hink_tick_cb_handler);
    hink_tick_running = 1;
}

static void hink_tick_cb_handler(void)
{
    hink_tick_running = 0;

    if (!hink_time_rx_ok)
    {
        return;
    }

    hink_advance_one_second();
    hink_notify_time();
    hink_start_tick_timer();
}

/*
 * HL25A_ONE_SHOT_PANEL_LIVENESS
 *
 * Purpose: prove that the white-screen HINK213 panel can execute exactly one
 * fixed-pattern refresh after an explicit BLE arm/fire sequence.
 *
 * This path is intentionally narrow:
 * - requires an active E4 session,
 * - requires the magic ASCII string "HL25",
 * - arm expires after 10 seconds,
 * - fire must use the returned arm id,
 * - the arm is cleared before the panel job starts,
 * - only one fire is allowed per cold boot,
 * - all legacy refresh-capable E2 commands remain blocked by HL20A.
 *
 * Protocol:
 *   Arm:   E6 00 48 4C 32 35              ("HL25")
 *          -> E6 80 status armId state timeoutSec
 *   Fire:  E6 01 armId A5 5A
 *          -> E6 81 status armId state timeoutSec
 *          then E2 25 10 (job started), E2 25 02 (job complete)
 *   Cancel:E6 02 armId
 *          -> E6 82 status armId state timeoutSec
 *   Query: E6 03
 *          -> E6 83 status armId state timeoutSec
 *
 * State bits:
 *   bit0 = armed
 *   bit1 = used this cold boot
 *   bit2 = panel job busy
 */
#define HL25_STATUS_OK               0x00
#define HL25_STATUS_SESSION_REQUIRED 0x01
#define HL25_STATUS_INVALID_SIZE     0x02
#define HL25_STATUS_ALREADY_USED     0x03
#define HL25_STATUS_BUSY             0x04
#define HL25_STATUS_NOT_ARMED        0x05
#define HL25_STATUS_WRONG_OWNER      0x06
#define HL25_STATUS_TOKEN_MISMATCH   0x07
#define HL25_STATUS_ARM_ID_MISMATCH  0x08
#define HL25_STATUS_BAD_MAGIC        0x09
#define HL25_STATUS_UNSUPPORTED      0x0A

static uint8_t hl25_liveness_state(void)
{
    uint8_t state = 0;

    if (hl25_liveness_armed)
    {
        state |= 0x01;
    }

    if (hl25_liveness_used)
    {
        state |= 0x02;
    }

    if (hink_epd_busy_job)
    {
        state |= 0x04;
    }

    return state;
}

static void hl25_liveness_notify(uint8_t response,
                                 uint8_t status,
                                 uint8_t arm_id)
{
    uint8_t msg[6];
    msg[0] = 0xE6;
    msg[1] = response;
    msg[2] = status;
    msg[3] = arm_id;
    msg[4] = hl25_liveness_state();
    msg[5] = HL25_LIVENESS_ARM_TIMEOUT_SEC;
    hink_notify_bytes(msg, 6);
}

static void hl25_liveness_disarm(void)
{
    if (hl25_liveness_timer_running)
    {
        app_easy_timer_cancel(hl25_liveness_timer);
        hl25_liveness_timer_running = 0;
    }

    hl25_liveness_armed = 0;
    hl25_liveness_owner_conidx = 0xFF;
    hl25_liveness_session_token = 0;
}

static void hl25_liveness_timeout_cb(void)
{
    hl25_liveness_timer_running = 0;
    hl25_liveness_armed = 0;
    hl25_liveness_owner_conidx = 0xFF;
    hl25_liveness_session_token = 0;
}

static void hl25_liveness_arm_timer(void)
{
    if (hl25_liveness_timer_running)
    {
        app_easy_timer_cancel(hl25_liveness_timer);
        hl25_liveness_timer_running = 0;
    }

    hl25_liveness_timer =
        app_easy_timer(HL25_LIVENESS_ARM_TIMEOUT_10MS,
                       hl25_liveness_timeout_cb);
    hl25_liveness_timer_running = 1;
}

static uint8_t hl25_liveness_handle(
    struct custs1_val_write_ind const *param,
    uint8_t conidx)
{
    uint8_t subcmd;
    uint8_t arm_id;

    if ((param->length < 2) || (param->value[0] != 0xE6))
    {
        return 0;
    }

    subcmd = param->value[1];
    arm_id = (param->length >= 3) ? param->value[2] : hl25_liveness_arm_id;

    switch (subcmd)
    {
        case 0x00:
            /* Arm: E6 00 "HL25" */
            if (param->length != 6)
            {
                hl25_liveness_notify(0x80,
                                     HL25_STATUS_INVALID_SIZE,
                                     hl25_liveness_arm_id);
            }
            else if (!hl21_session_is_valid(conidx))
            {
                hl25_liveness_notify(0x80,
                                     HL25_STATUS_SESSION_REQUIRED,
                                     hl25_liveness_arm_id);
            }
            else if ((param->value[2] != 0x48) ||
                     (param->value[3] != 0x4C) ||
                     (param->value[4] != 0x32) ||
                     (param->value[5] != 0x35))
            {
                hl25_liveness_notify(0x80,
                                     HL25_STATUS_BAD_MAGIC,
                                     hl25_liveness_arm_id);
            }
            else if (hl25_liveness_used)
            {
                hl25_liveness_notify(0x80,
                                     HL25_STATUS_ALREADY_USED,
                                     hl25_liveness_arm_id);
            }
            else if (hink_epd_busy_job)
            {
                hl25_liveness_notify(0x80,
                                     HL25_STATUS_BUSY,
                                     hl25_liveness_arm_id);
            }
            else
            {
                hl25_liveness_disarm();

                hl25_liveness_arm_id++;
                if (hl25_liveness_arm_id == 0)
                {
                    hl25_liveness_arm_id = 1;
                }

                hl25_liveness_armed = 1;
                hl25_liveness_owner_conidx = conidx;
                hl25_liveness_session_token = hl21_session_token;
                hl25_liveness_arm_timer();
                hl21_session_touch();

                hl25_liveness_notify(0x80,
                                     HL25_STATUS_OK,
                                     hl25_liveness_arm_id);
            }
            return 1;

        case 0x01:
            /* Fire: E6 01 armId A5 5A */
            if (param->length != 5)
            {
                hl25_liveness_notify(0x81,
                                     HL25_STATUS_INVALID_SIZE,
                                     arm_id);
            }
            else if (!hl21_session_is_valid(conidx))
            {
                hl25_liveness_notify(0x81,
                                     HL25_STATUS_SESSION_REQUIRED,
                                     arm_id);
            }
            else if (hl25_liveness_used)
            {
                hl25_liveness_notify(0x81,
                                     HL25_STATUS_ALREADY_USED,
                                     arm_id);
            }
            else if (!hl25_liveness_armed)
            {
                hl25_liveness_notify(0x81,
                                     HL25_STATUS_NOT_ARMED,
                                     arm_id);
            }
            else if (hl25_liveness_owner_conidx != conidx)
            {
                hl25_liveness_notify(0x81,
                                     HL25_STATUS_WRONG_OWNER,
                                     arm_id);
            }
            else if (hl25_liveness_session_token != hl21_session_token)
            {
                hl25_liveness_notify(0x81,
                                     HL25_STATUS_TOKEN_MISMATCH,
                                     arm_id);
            }
            else if (arm_id != hl25_liveness_arm_id)
            {
                hl25_liveness_notify(0x81,
                                     HL25_STATUS_ARM_ID_MISMATCH,
                                     arm_id);
            }
            else if ((param->value[3] != 0xA5) ||
                     (param->value[4] != 0x5A))
            {
                hl25_liveness_notify(0x81,
                                     HL25_STATUS_BAD_MAGIC,
                                     arm_id);
            }
            else if (hink_epd_busy_job)
            {
                hl25_liveness_notify(0x81,
                                     HL25_STATUS_BUSY,
                                     arm_id);
            }
            else
            {
                /*
                 * Auto-lock before touching the panel. From this point onward
                 * another fire cannot be accepted until a cold boot.
                 */
                hl25_liveness_disarm();
                hl25_liveness_used = 1;
                hl21_session_touch();

                hl25_liveness_notify(0x81,
                                     HL25_STATUS_OK,
                                     arm_id);

                hink_epd_set_variant(0, 0, 0, 0, 0);
                hink_epd_start_job(HL25_LIVENESS_JOB_SUB);
            }
            return 1;

        case 0x02:
            /* Cancel: E6 02 armId */
            if (param->length != 3)
            {
                hl25_liveness_notify(0x82,
                                     HL25_STATUS_INVALID_SIZE,
                                     arm_id);
            }
            else if (!hl25_liveness_armed)
            {
                hl25_liveness_notify(0x82,
                                     HL25_STATUS_NOT_ARMED,
                                     arm_id);
            }
            else if (arm_id != hl25_liveness_arm_id)
            {
                hl25_liveness_notify(0x82,
                                     HL25_STATUS_ARM_ID_MISMATCH,
                                     arm_id);
            }
            else
            {
                hl25_liveness_disarm();
                hl25_liveness_notify(0x82,
                                     HL25_STATUS_OK,
                                     arm_id);
            }
            return 1;

        case 0x03:
            /* Query is safe and does not require a session. */
            if (param->length != 2)
            {
                hl25_liveness_notify(0x83,
                                     HL25_STATUS_INVALID_SIZE,
                                     hl25_liveness_arm_id);
            }
            else
            {
                hl25_liveness_notify(0x83,
                                     HL25_STATUS_OK,
                                     hl25_liveness_arm_id);
            }
            return 1;

        default:
            hl25_liveness_notify(0x8F,
                                 HL25_STATUS_UNSUPPORTED,
                                 hl25_liveness_arm_id);
            return 1;
    }
}

/*
 * HL21A_BLE_COMMAND_SESSION
 *
 * Bounded RAM-only safety session for E3 dry-run commands. This is not
 * cryptographic authentication; it prevents stale pages and accidental writes.
 *
 * E4 00 48 4C 32 31 -> E4 80 status token timeoutSec  (open, ASCII "HL21")
 * E4 01 token       -> E4 81 status token timeoutSec  (keepalive)
 * E4 02 token       -> E4 82 status token timeoutSec  (close)
 * E4 03             -> E4 83 active token timeoutSec  (status)
 *
 * A valid E3 command refreshes the 20-second timeout. Close/expiry resets all
 * dry-run counters. No E4/E3 path calls EPD, GPIO or SPI.
 */
#define HL21_SESSION_TIMEOUT_10MS     2000U
#define HL21_SESSION_TIMEOUT_SECONDS  20U

#define HL21_SESSION_STATUS_OK             0x00
#define HL21_SESSION_STATUS_INVALID        0x01
#define HL21_SESSION_STATUS_BAD_TOKEN      0x02
#define HL21_SESSION_STATUS_NOT_OPEN       0x03
#define HL21_SESSION_STATUS_WRONG_OWNER    0x04
#define HL21_SESSION_STATUS_UNSUPPORTED    0x05
#define HL21_E3_STATUS_SESSION_REQUIRED    0x06

static void hl21_session_notify(uint8_t response,
                                uint8_t status_or_active,
                                uint8_t token)
{
    uint8_t msg[5];
    msg[0] = 0xE4;
    msg[1] = response;
    msg[2] = status_or_active;
    msg[3] = token;
    msg[4] = HL21_SESSION_TIMEOUT_SECONDS;
    hink_notify_bytes(msg, 5);
}

static void hl21_session_expire(void)
{
    hl21_session_active = 0;
    hl21_session_owner_conidx = 0xFF;
    hl18b_dry_reset();
    hl22_transfer_reset();
    hl25_liveness_disarm();
}

static void hl21_session_timeout_cb(void)
{
    hl21_session_timer_running = 0;
    hl21_session_expire();
}

static void hl21_session_arm_timer(void)
{
    if (hl21_session_timer_running)
    {
        app_easy_timer_cancel(hl21_session_timer);
        hl21_session_timer_running = 0;
    }

    hl21_session_timer = app_easy_timer(HL21_SESSION_TIMEOUT_10MS,
                                        hl21_session_timeout_cb);
    hl21_session_timer_running = 1;
}

static void hl21_session_close(void)
{
    if (hl21_session_timer_running)
    {
        app_easy_timer_cancel(hl21_session_timer);
        hl21_session_timer_running = 0;
    }

    hl21_session_expire();
}

static uint8_t hl21_session_is_valid(uint8_t conidx)
{
    return (hl21_session_active &&
            (hl21_session_owner_conidx == conidx)) ? 1 : 0;
}

static void hl21_session_touch(void)
{
    if (hl21_session_active)
    {
        hl21_session_arm_timer();
    }
}

static uint8_t hl21_session_handle(struct custs1_val_write_ind const *param,
                                   uint8_t conidx)
{
    uint8_t subcmd;
    uint8_t token;

    if ((param->length < 2) || (param->value[0] != 0xE4))
    {
        return 0;
    }

    subcmd = param->value[1];

    switch (subcmd)
    {
        case 0x00:
            if ((param->length != 6) ||
                (param->value[2] != 0x48) ||
                (param->value[3] != 0x4C) ||
                (param->value[4] != 0x32) ||
                (param->value[5] != 0x31))
            {
                hl21_session_notify(0x80, HL21_SESSION_STATUS_INVALID, 0);
                return 1;
            }

            hl21_session_close();
            hl21_session_token++;
            if (hl21_session_token == 0)
            {
                hl21_session_token = 1;
            }

            hl21_session_active = 1;
            hl21_session_owner_conidx = conidx;
            hl21_session_arm_timer();
            hl21_session_notify(0x80, HL21_SESSION_STATUS_OK,
                                hl21_session_token);
            return 1;

        case 0x01:
            if (param->length != 3)
            {
                hl21_session_notify(0x81, HL21_SESSION_STATUS_INVALID,
                                    hl21_session_token);
            }
            else if (!hl21_session_active)
            {
                hl21_session_notify(0x81, HL21_SESSION_STATUS_NOT_OPEN,
                                    hl21_session_token);
            }
            else if (hl21_session_owner_conidx != conidx)
            {
                hl21_session_notify(0x81, HL21_SESSION_STATUS_WRONG_OWNER,
                                    hl21_session_token);
            }
            else if (param->value[2] != hl21_session_token)
            {
                hl21_session_notify(0x81, HL21_SESSION_STATUS_BAD_TOKEN,
                                    hl21_session_token);
            }
            else
            {
                hl21_session_touch();
                hl21_session_notify(0x81, HL21_SESSION_STATUS_OK,
                                    hl21_session_token);
            }
            return 1;

        case 0x02:
            token = hl21_session_token;
            if (param->length != 3)
            {
                hl21_session_notify(0x82, HL21_SESSION_STATUS_INVALID, token);
            }
            else if (!hl21_session_active)
            {
                hl21_session_notify(0x82, HL21_SESSION_STATUS_NOT_OPEN, token);
            }
            else if (hl21_session_owner_conidx != conidx)
            {
                hl21_session_notify(0x82, HL21_SESSION_STATUS_WRONG_OWNER,
                                    token);
            }
            else if (param->value[2] != token)
            {
                hl21_session_notify(0x82, HL21_SESSION_STATUS_BAD_TOKEN, token);
            }
            else
            {
                hl21_session_close();
                hl21_session_notify(0x82, HL21_SESSION_STATUS_OK, token);
            }
            return 1;

        case 0x03:
            if (param->length != 2)
            {
                hl21_session_notify(0x83, HL21_SESSION_STATUS_INVALID,
                                    hl21_session_token);
            }
            else if (hl21_session_is_valid(conidx))
            {
                hl21_session_notify(0x83, 1, hl21_session_token);
            }
            else
            {
                hl21_session_notify(0x83, 0, hl21_session_token);
            }
            return 1;

        default:
            hl21_session_notify(0x8F, HL21_SESSION_STATUS_UNSUPPORTED,
                                hl21_session_token);
            return 1;
    }
}

/*
 * HL22A_SESSION_BOUND_TRANSFER_INTEGRITY
 *
 * E5 stores only metadata, counters and CRC16. It never stores framebuffer
 * bytes and never calls EPD, GPIO or SPI code.
 *
 * Start:  E5 00 id widthLo widthHi heightLo heightHi xBytes totalLo totalHi crcLo crcHi
 * Chunk:  E5 01 id seqLo seqHi len data...
 * Commit: E5 02 id chunksLo chunksHi bytesLo bytesHi crcLo crcHi
 * Status: E5 03 id
 * Reset:  E5 04 id
 *
 * CRC16-CCITT-FALSE: polynomial 0x1021, initial value 0xFFFF.
 */
#define HL22_FB_WIDTH                128U
#define HL22_FB_HEIGHT               296U
#define HL22_FB_X_BYTES              16U
#define HL22_FB_TOTAL                4736U
#define HL22_MAX_CHUNK               14U
#define HL22_CRC16_INITIAL           0xFFFFU

#define HL22_STATUS_OK               0x00
#define HL22_STATUS_SESSION_REQUIRED 0x01
#define HL22_STATUS_INVALID_SIZE     0x02
#define HL22_STATUS_ID_MISMATCH      0x03
#define HL22_STATUS_SEQUENCE_ERROR   0x04
#define HL22_STATUS_OVERFLOW         0x05
#define HL22_STATUS_CRC_MISMATCH     0x06
#define HL22_STATUS_INCOMPLETE       0x07
#define HL22_STATUS_NO_TRANSFER      0x08
#define HL22_STATUS_SESSION_MISMATCH 0x09
#define HL22_STATUS_UNSUPPORTED      0x0A

#define HL22_STATE_NONE              0x00
#define HL22_STATE_ACTIVE            0x01
#define HL22_STATE_COMPLETE          0x02

static uint16_t hl22_u16le(const uint8_t *p)
{
    return (uint16_t)(((uint16_t)p[1] << 8) | p[0]);
}

static uint16_t hl22_crc16_update(uint16_t crc,
                                  const uint8_t *data,
                                  uint8_t len)
{
    uint8_t i;
    uint8_t bit;

    for (i = 0; i < len; i++)
    {
        crc ^= (uint16_t)((uint16_t)data[i] << 8);
        for (bit = 0; bit < 8; bit++)
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

static void hl22_notify_short(uint8_t response,
                              uint8_t status,
                              uint8_t transfer_id)
{
    uint8_t msg[5];
    msg[0] = 0xE5;
    msg[1] = response;
    msg[2] = status;
    msg[3] = transfer_id;
    msg[4] = hl21_session_token;
    hink_notify_bytes(msg, 5);
}

static void hl22_notify_chunk(uint8_t status, uint8_t transfer_id)
{
    uint8_t msg[6];
    msg[0] = 0xE5;
    msg[1] = 0x81;
    msg[2] = status;
    msg[3] = transfer_id;
    msg[4] = (uint8_t)(hl22_transfer_next_seq & 0xFFU);
    msg[5] = (uint8_t)((hl22_transfer_next_seq >> 8) & 0xFFU);
    hink_notify_bytes(msg, 6);
}

static uint8_t hl22_transfer_state(void)
{
    if (hl22_transfer_complete)
    {
        return HL22_STATE_COMPLETE;
    }
    if (hl22_transfer_active)
    {
        return HL22_STATE_ACTIVE;
    }
    return HL22_STATE_NONE;
}

static void hl22_notify_manifest(uint8_t response,
                                 uint8_t status,
                                 uint8_t transfer_id)
{
    uint8_t msg[11];
    msg[0] = 0xE5;
    msg[1] = response;
    msg[2] = status;
    msg[3] = transfer_id;
    msg[4] = hl22_transfer_state();
    msg[5] = (uint8_t)(hl22_transfer_chunks & 0xFFU);
    msg[6] = (uint8_t)((hl22_transfer_chunks >> 8) & 0xFFU);
    msg[7] = (uint8_t)(hl22_transfer_bytes & 0xFFU);
    msg[8] = (uint8_t)((hl22_transfer_bytes >> 8) & 0xFFU);
    msg[9] = (uint8_t)(hl22_transfer_running_crc & 0xFFU);
    msg[10] = (uint8_t)((hl22_transfer_running_crc >> 8) & 0xFFU);
    hink_notify_bytes(msg, 11);
}

static void hl22_transfer_reset(void)
{
    hl22_transfer_active = 0;
    hl22_transfer_complete = 0;
    hl22_transfer_id = 0;
    hl22_transfer_session_token = 0;
    hl22_transfer_next_seq = 0;
    hl22_transfer_chunks = 0;
    hl22_transfer_bytes = 0;
    hl22_transfer_expected_crc = 0;
    hl22_transfer_running_crc = HL22_CRC16_INITIAL;
}

static uint8_t hl22_transfer_session_matches(uint8_t conidx)
{
    return (hl21_session_is_valid(conidx) &&
            (hl22_transfer_session_token == hl21_session_token)) ? 1 : 0;
}

static uint8_t hl22_transfer_handle(struct custs1_val_write_ind const *param,
                                    uint8_t conidx)
{
    uint8_t subcmd;
    uint8_t transfer_id;
    uint8_t chunk_len;
    uint8_t status;
    uint16_t width;
    uint16_t height;
    uint16_t total;
    uint16_t seq;
    uint16_t expected_crc;
    uint16_t expected_chunks;
    uint16_t expected_bytes;
    uint16_t commit_crc;

    if ((param->length < 2) || (param->value[0] != 0xE5))
    {
        return 0;
    }

    subcmd = param->value[1];
    transfer_id = (param->length >= 3) ? param->value[2] : 0;

    if (!hl21_session_is_valid(conidx))
    {
        if (subcmd == 0x01)
        {
            hl22_notify_chunk(HL22_STATUS_SESSION_REQUIRED, transfer_id);
        }
        else if ((subcmd == 0x02) || (subcmd == 0x03))
        {
            hl22_notify_manifest((uint8_t)(0x80U | subcmd),
                                 HL22_STATUS_SESSION_REQUIRED,
                                 transfer_id);
        }
        else
        {
            hl22_notify_short((uint8_t)(0x80U | subcmd),
                              HL22_STATUS_SESSION_REQUIRED,
                              transfer_id);
        }
        return 1;
    }

    hl21_session_touch();

    switch (subcmd)
    {
        case 0x00:
            status = HL22_STATUS_INVALID_SIZE;
            if (param->length == 12)
            {
                width = hl22_u16le(&param->value[3]);
                height = hl22_u16le(&param->value[5]);
                total = hl22_u16le(&param->value[8]);
                expected_crc = hl22_u16le(&param->value[10]);

                if ((transfer_id != 0) &&
                    (width == HL22_FB_WIDTH) &&
                    (height == HL22_FB_HEIGHT) &&
                    (param->value[7] == HL22_FB_X_BYTES) &&
                    (total == HL22_FB_TOTAL))
                {
                    hl22_transfer_reset();
                    hl22_transfer_active = 1;
                    hl22_transfer_id = transfer_id;
                    hl22_transfer_session_token = hl21_session_token;
                    hl22_transfer_expected_crc = expected_crc;
                    status = HL22_STATUS_OK;
                }
            }
            hl22_notify_short(0x80, status, transfer_id);
            return 1;

        case 0x01:
            status = HL22_STATUS_OK;
            if (!hl22_transfer_active)
            {
                status = HL22_STATUS_NO_TRANSFER;
            }
            else if (!hl22_transfer_session_matches(conidx))
            {
                hl22_transfer_reset();
                status = HL22_STATUS_SESSION_MISMATCH;
            }
            else if (transfer_id != hl22_transfer_id)
            {
                status = HL22_STATUS_ID_MISMATCH;
            }
            else if (param->length < 7)
            {
                status = HL22_STATUS_INVALID_SIZE;
            }
            else
            {
                seq = hl22_u16le(&param->value[3]);
                chunk_len = param->value[5];
                if ((chunk_len == 0) || (chunk_len > HL22_MAX_CHUNK) ||
                    ((uint16_t)param->length != (uint16_t)(6U + chunk_len)))
                {
                    status = HL22_STATUS_INVALID_SIZE;
                }
                else if (seq != hl22_transfer_next_seq)
                {
                    status = HL22_STATUS_SEQUENCE_ERROR;
                }
                else if ((uint32_t)hl22_transfer_bytes + chunk_len > HL22_FB_TOTAL)
                {
                    status = HL22_STATUS_OVERFLOW;
                }
                else
                {
                    hl22_transfer_running_crc =
                        hl22_crc16_update(hl22_transfer_running_crc,
                                          &param->value[6],
                                          chunk_len);
                    hl22_transfer_next_seq++;
                    hl22_transfer_chunks++;
                    hl22_transfer_bytes =
                        (uint16_t)(hl22_transfer_bytes + chunk_len);
                }
            }
            hl22_notify_chunk(status, transfer_id);
            return 1;

        case 0x02:
            status = HL22_STATUS_OK;
            if (param->length != 9)
            {
                status = HL22_STATUS_INVALID_SIZE;
            }
            else if (!hl22_transfer_active)
            {
                status = HL22_STATUS_NO_TRANSFER;
            }
            else if (!hl22_transfer_session_matches(conidx))
            {
                hl22_transfer_reset();
                status = HL22_STATUS_SESSION_MISMATCH;
            }
            else if (transfer_id != hl22_transfer_id)
            {
                status = HL22_STATUS_ID_MISMATCH;
            }
            else
            {
                expected_chunks = hl22_u16le(&param->value[3]);
                expected_bytes = hl22_u16le(&param->value[5]);
                commit_crc = hl22_u16le(&param->value[7]);
                if ((hl22_transfer_bytes != HL22_FB_TOTAL) ||
                    (expected_bytes != hl22_transfer_bytes) ||
                    (expected_chunks != hl22_transfer_chunks))
                {
                    status = HL22_STATUS_INCOMPLETE;
                }
                else if ((commit_crc != hl22_transfer_running_crc) ||
                         (commit_crc != hl22_transfer_expected_crc))
                {
                    status = HL22_STATUS_CRC_MISMATCH;
                }
                else
                {
                    hl22_transfer_active = 0;
                    hl22_transfer_complete = 1;
                }
            }
            hl22_notify_manifest(0x82, status, transfer_id);
            return 1;

        case 0x03:
            if (param->length != 3)
            {
                hl22_notify_manifest(0x83, HL22_STATUS_INVALID_SIZE, transfer_id);
            }
            else if (!hl22_transfer_active && !hl22_transfer_complete)
            {
                hl22_notify_manifest(0x83, HL22_STATUS_NO_TRANSFER, transfer_id);
            }
            else if (!hl22_transfer_session_matches(conidx))
            {
                hl22_transfer_reset();
                hl22_notify_manifest(0x83, HL22_STATUS_SESSION_MISMATCH, transfer_id);
            }
            else if (transfer_id != hl22_transfer_id)
            {
                hl22_notify_manifest(0x83, HL22_STATUS_ID_MISMATCH, transfer_id);
            }
            else
            {
                hl22_notify_manifest(0x83, HL22_STATUS_OK, transfer_id);
            }
            return 1;

        case 0x04:
            if (param->length != 3)
            {
                hl22_notify_short(0x84, HL22_STATUS_INVALID_SIZE, transfer_id);
            }
            else if (!hl22_transfer_active && !hl22_transfer_complete)
            {
                hl22_notify_short(0x84, HL22_STATUS_NO_TRANSFER, transfer_id);
            }
            else if (transfer_id != hl22_transfer_id)
            {
                hl22_notify_short(0x84, HL22_STATUS_ID_MISMATCH, transfer_id);
            }
            else
            {
                hl22_transfer_reset();
                hl22_notify_short(0x84, HL22_STATUS_OK, transfer_id);
            }
            return 1;

        default:
            hl22_notify_short(0x8F, HL22_STATUS_UNSUPPORTED, transfer_id);
            return 1;
    }
}

/*
 * HL18B_FRAMEBUFFER_DRYRUN
 * Matches web/clock-app/hl18a-213-dryrun.html.
 *
 * E3 commands only update metadata/counters and return 3-byte notifications.
 * This code does NOT call EPD/GPIO/SPI functions, does NOT store a framebuffer,
 * and does NOT refresh or write anything to the panel.
 */
#define HL18B_FB_WIDTH       128U
#define HL18B_FB_HEIGHT      296U
#define HL18B_FB_X_BYTES     16U
#define HL18B_FB_TOTAL       4736U

#define HL18B_STATUS_OK              0x00
#define HL18B_STATUS_INVALID_SIZE    0x01
#define HL18B_STATUS_BAD_CHECKSUM    0x02
#define HL18B_STATUS_SEQUENCE_ERROR  0x03
#define HL18B_STATUS_LOCKED          0x04
#define HL18B_STATUS_UNSUPPORTED     0x05

static uint16_t hl18b_u16le(const uint8_t *p)
{
    return (uint16_t)(((uint16_t)p[1] << 8) | p[0]);
}

static uint8_t hl18b_xor_bytes(const uint8_t *data, uint8_t len)
{
    uint8_t i;
    uint8_t value = 0;

    for (i = 0; i < len; i++)
    {
        value ^= data[i];
    }

    return value;
}

static void hl18b_notify3(uint8_t response, uint8_t value)
{
    uint8_t msg[3];
    msg[0] = 0xE3;
    msg[1] = response;
    msg[2] = value;
    hink_notify_bytes(msg, 3);
}

static void hl18b_dry_reset(void)
{
    hl18b_dry_metadata_ok = 0;
    hl18b_dry_next_seq = 0;
    hl18b_dry_chunks = 0;
    hl18b_dry_bytes = 0;
    hl18b_dry_xor = 0;
}

static uint8_t hl18b_dry_handle(struct custs1_val_write_ind const *param,
                                uint8_t conidx)
{
    uint8_t subcmd;
    uint8_t status;
    uint8_t page;
    uint8_t value;
    uint8_t chunk_len;
    uint8_t expected_xor;
    uint8_t calculated_xor;
    uint16_t width;
    uint16_t height;
    uint16_t total;
    uint16_t seq;

    if ((param->length < 2) || (param->value[0] != 0xE3))
    {
        return 0;
    }

    subcmd = param->value[1];

    if (!hl21_session_is_valid(conidx))
    {
        switch (subcmd)
        {
            case 0x00:
                hl18b_notify3(0x80, HL21_E3_STATUS_SESSION_REQUIRED);
                break;
            case 0x01:
                hl18b_notify3(0x81, HL21_E3_STATUS_SESSION_REQUIRED);
                break;
            case 0x03:
                hl18b_notify3(0x83, HL21_E3_STATUS_SESSION_REQUIRED);
                break;
            default:
                hl18b_notify3(0x8F, HL21_E3_STATUS_SESSION_REQUIRED);
                break;
        }

        return 1;
    }

    hl21_session_touch();

    switch (subcmd)
    {
        case 0x00:
            /* E3 00 widthLo widthHi heightLo heightHi xBytes totalLo totalHi */
            status = HL18B_STATUS_INVALID_SIZE;

            if (param->length == 9)
            {
                width = hl18b_u16le(&param->value[2]);
                height = hl18b_u16le(&param->value[4]);
                total = hl18b_u16le(&param->value[7]);

                if ((width == HL18B_FB_WIDTH) &&
                    (height == HL18B_FB_HEIGHT) &&
                    (param->value[6] == HL18B_FB_X_BYTES) &&
                    (total == HL18B_FB_TOTAL))
                {
                    hl18b_dry_metadata_ok = 1;
                    hl18b_dry_next_seq = 0;
                    hl18b_dry_chunks = 0;
                    hl18b_dry_bytes = 0;
                    hl18b_dry_xor = 0;
                    status = HL18B_STATUS_OK;
                }
            }

            hl18b_notify3(0x80, status);
            return 1;

        case 0x01:
            /* E3 01 seqLo seqHi len xor data... */
            status = HL18B_STATUS_OK;

            if (!hl18b_dry_metadata_ok)
            {
                status = HL18B_STATUS_LOCKED;
            }
            else if (param->length < 6)
            {
                status = HL18B_STATUS_INVALID_SIZE;
            }
            else
            {
                seq = hl18b_u16le(&param->value[2]);
                chunk_len = param->value[4];
                expected_xor = param->value[5];

                if ((uint16_t)param->length != (uint16_t)(6U + chunk_len))
                {
                    status = HL18B_STATUS_INVALID_SIZE;
                }
                else if (seq != hl18b_dry_next_seq)
                {
                    status = HL18B_STATUS_SEQUENCE_ERROR;
                }
                else if ((uint32_t)hl18b_dry_bytes + chunk_len > HL18B_FB_TOTAL)
                {
                    status = HL18B_STATUS_INVALID_SIZE;
                }
                else
                {
                    calculated_xor = hl18b_xor_bytes(&param->value[6], chunk_len);
                    if (calculated_xor != expected_xor)
                    {
                        status = HL18B_STATUS_BAD_CHECKSUM;
                    }
                    else
                    {
                        hl18b_dry_next_seq++;
                        hl18b_dry_chunks++;
                        hl18b_dry_bytes = (uint16_t)(hl18b_dry_bytes + chunk_len);
                        hl18b_dry_xor ^= calculated_xor;
                    }
                }
            }

            hl18b_notify3(0x81, status);
            return 1;

        case 0x02:
            /* E3 02 page -> E3 82 value */
            if (param->length != 3)
            {
                hl18b_notify3(0x8F, HL18B_STATUS_INVALID_SIZE);
                return 1;
            }

            page = param->value[2];
            value = 0;

            switch (page)
            {
                case 0x00:
                    value = (uint8_t)(hl18b_dry_chunks & 0xFF);
                    break;
                case 0x01:
                    value = (uint8_t)((hl18b_dry_chunks >> 8) & 0xFF);
                    break;
                case 0x02:
                    value = (uint8_t)(hl18b_dry_bytes & 0xFF);
                    break;
                case 0x03:
                    value = (uint8_t)((hl18b_dry_bytes >> 8) & 0xFF);
                    break;
                case 0x04:
                    value = hl18b_dry_xor;
                    break;
                case 0x05:
                    value = hl18b_dry_metadata_ok ? 1 : 0;
                    break;
                default:
                    hl18b_notify3(0x8F, HL18B_STATUS_UNSUPPORTED);
                    return 1;
            }

            hl18b_notify3(0x82, value);
            return 1;

        case 0x03:
            /* E3 03 -> reset all dry-run state. */
            if (param->length != 2)
            {
                hl18b_notify3(0x83, HL18B_STATUS_INVALID_SIZE);
                return 1;
            }

            hl18b_dry_reset();
            hl18b_notify3(0x83, HL18B_STATUS_OK);
            return 1;

        default:
            hl18b_notify3(0x8F, HL18B_STATUS_UNSUPPORTED);
            return 1;
    }
}

static uint8_t hink_handle_time_write(struct custs1_val_write_ind const *param,
                                      ke_task_id_t const src_id)
{
    uint8_t conidx = KE_IDX_GET(src_id);
    hink_ble_conidx = app_env[conidx].conidx;

    /* E6 is the HL25A one-shot panel liveness gate. */
    if (hl25_liveness_handle(param, hink_ble_conidx))
    {
        return 1;
    }

    /* E4 opens, maintains and closes the bounded HL21A session. */
    if (hl21_session_handle(param, hink_ble_conidx))
    {
        return 1;
    }

    /* E5 adds session-bound transfer ID and CRC16 integrity. */
    if (hl22_transfer_handle(param, hink_ble_conidx))
    {
        return 1;
    }

    /* Legacy E3 remains available for regression and precedes every E2 branch. */
    if (hl18b_dry_handle(param, hink_ble_conidx))
    {
        return 1;
    }

    // P3 original-map safe EPD command: E2 <subcmd> 00 00 00 00 00
    if ((param->length == HINK_TIME_PACKET_LEN) && (param->value[0] == 0xE2))
    {
        hink_epd_command(param->value[1]);
        return 1;
    }

    // Keep old E100 BLE-only ping alive, but block all old E1 GPIO probes.
    if ((param->length == HINK_TIME_PACKET_LEN) && (param->value[0] == 0xE1))
    {
        uint8_t out[3];
        out[0] = 0xE1;
        out[1] = param->value[1];
        out[2] = (param->value[1] == 0x00) ? 0x02 : 0xEE;
        hink_notify_bytes(out, 3);
        return 1;
    }

    // Raw packet in one BLE write: YY MM DD DOW HH MM SS
    if (param->length == HINK_TIME_PACKET_LEN)
    {
        hink_load_time_packet(param->value);
        hink_acc_idx = 0;
        hink_notify_time();
        hink_start_tick_timer();
        return 1;
    }

    // Same packet sent byte-by-byte, useful when BLE app UI is annoying.
    if (param->length == 1)
    {
        hink_acc[hink_acc_idx++] = param->value[0];

        if (hink_acc_idx >= HINK_TIME_PACKET_LEN)
        {
            hink_load_time_packet(hink_acc);
            hink_acc_idx = 0;
            hink_notify_time();
            hink_start_tick_timer();
        }
        else
        {
            // Debug while accumulating: AA-01, AA-02, ... AA-06
            hink_notify_debug(0xAA, hink_acc_idx);
        }

        return 1;
    }

    // Unsupported write length: AA-55 means handler is alive but packet format is wrong.
    hink_acc_idx = 0;
    hink_notify_debug(0xAA, 0x55);
    return 1;
}

/*
 * FUNCTION DEFINITIONS
 ****************************************************************************************
 */

void user_svc1_ctrl_wr_ind_handler(ke_msg_id_t const msgid,
                                      struct custs1_val_write_ind const *param,
                                      ke_task_id_t const dest_id,
                                      ke_task_id_t const src_id)
{
    if (hink_handle_time_write(param, src_id))
    {
        return;
    }

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

void user_svc1_led_wr_ind_handler(ke_msg_id_t const msgid,
                                     struct custs1_val_write_ind const *param,
                                     ke_task_id_t const dest_id,
                                     ke_task_id_t const src_id)
{
    if (hink_handle_time_write(param, src_id))
    {
        return;
    }

    uint8_t val = 0;
    memcpy(&val, &param->value[0], param->length);

    if (val == CUSTS1_LED_ON)
    {
        GPIO_SetActive(GPIO_LED_PORT, GPIO_LED_PIN);
    }
    else if (val == CUSTS1_LED_OFF)
    {
        GPIO_SetInactive(GPIO_LED_PORT, GPIO_LED_PIN);
    }
}

void user_svc1_long_val_cfg_ind_handler(ke_msg_id_t const msgid,
                                           struct custs1_val_write_ind const *param,
                                           ke_task_id_t const dest_id,
                                           ke_task_id_t const src_id)
{
    // Generate indication when the central subscribes to it
    if (param->value[0])
    {
        uint8_t conidx = KE_IDX_GET(src_id);

        struct custs1_val_ind_req* req = KE_MSG_ALLOC_DYN(CUSTS1_VAL_IND_REQ,
                                                          prf_get_task_from_id(TASK_ID_CUSTS1),
                                                          TASK_APP,
                                                          custs1_val_ind_req,
                                                          sizeof(indication_counter));

        req->conidx = app_env[conidx].conidx;
        req->handle = SVC1_IDX_INDICATEABLE_VAL;
        req->length = sizeof(indication_counter);
        req->value[0] = (indication_counter >> 8) & 0xFF;
        req->value[1] = indication_counter & 0xFF;

        indication_counter++;

        ke_msg_send(req);
    }
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
    rsp->conidx  = app_env[param->conidx].conidx;
    // Provide the attribute index.
    rsp->att_idx = param->att_idx;
    // Provide the current length of the attribute.
    rsp->length  = 0;
    // Provide the ATT error code.
    rsp->status  = ATT_ERR_NO_ERROR;

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
    rsp->conidx  = app_env[param->conidx].conidx;
    // Provide the attribute index.
    rsp->att_idx = param->att_idx;
    // Force current length to zero.
    rsp->length  = 0;
    // Provide the ATT error code.
    rsp->status  = ATT_ERR_WRITE_NOT_PERMITTED;

    ke_msg_send(rsp);
}

void app_adcval1_timer_cb_handler()
{
    // Original ADC demo timer is intentionally disabled for HINK213-CLOCK.
    // Timekeeping uses hink_tick_cb_handler() instead.
}

void user_svc3_read_non_db_val_handler(ke_msg_id_t const msgid,
                                           struct custs1_value_req_ind const *param,
                                           ke_task_id_t const dest_id,
                                           ke_task_id_t const src_id)
{
    // Increase value by one
    non_db_val_counter++;

    struct custs1_value_req_rsp *rsp = KE_MSG_ALLOC_DYN(CUSTS1_VALUE_REQ_RSP,
                                                        prf_get_task_from_id(TASK_ID_CUSTS1),
                                                        TASK_APP,
                                                        custs1_value_req_rsp,
                                                        DEF_SVC3_READ_VAL_4_CHAR_LEN);

    // Provide the connection index.
    rsp->conidx  = app_env[param->conidx].conidx;
    // Provide the attribute index.
    rsp->att_idx = param->att_idx;
    // Force current length to zero.
    rsp->length  = sizeof(non_db_val_counter);
    // Provide the ATT error code.
    rsp->status  = ATT_ERR_NO_ERROR;
    // Copy value
    memcpy(&rsp->value, &non_db_val_counter, rsp->length);
    // Send message
    ke_msg_send(rsp);
}
