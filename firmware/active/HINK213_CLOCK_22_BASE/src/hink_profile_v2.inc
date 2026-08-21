/*
 * EINK display profile v2 renderers.
 * Included by user_custs1_impl.c after the common framebuffer/time/lunar helpers.
 * No hardware side effects: these functions only draw into fb_bw.
 */

static const int8_t hink_v2_x60[60] = {
     0,  7, 13, 20, 26, 32, 38, 43, 48, 52, 55, 58, 61, 63, 64,
    64, 64, 63, 61, 58, 55, 52, 48, 43, 38, 32, 26, 20, 13,  7,
     0, -7,-13,-20,-26,-32,-38,-43,-48,-52,-55,-58,-61,-63,-64,
   -64,-64,-63,-61,-58,-55,-52,-48,-43,-38,-32,-26,-20,-13, -7
};

static const int8_t hink_v2_y60[60] = {
   -64,-64,-63,-61,-58,-55,-52,-48,-43,-38,-32,-26,-20,-13, -7,
     0,  7, 13, 20, 26, 32, 38, 43, 48, 52, 55, 58, 61, 63, 64,
    64, 64, 63, 61, 58, 55, 52, 48, 43, 38, 32, 26, 20, 13,  7,
     0, -7,-13,-20,-26,-32,-38,-43,-48,-52,-55,-58,-61,-63,-64
};

static int hink_v2_scale(int8_t unit, uint8_t radius)
{
    return ((int)unit * (int)radius) / 64;
}

static void hink_v2_line(int x0, int y0, int x1, int y1, uint8_t color)
{
    int dx = (x1 >= x0) ? (x1 - x0) : (x0 - x1);
    int sx = (x0 < x1) ? 1 : -1;
    int dy_abs = (y1 >= y0) ? (y1 - y0) : (y0 - y1);
    int dy = -dy_abs;
    int sy = (y0 < y1) ? 1 : -1;
    int err = dx + dy;
    int e2;

    while (1)
    {
        hink_d7a_pixel(x0, y0, color);
        if ((x0 == x1) && (y0 == y1))
        {
            break;
        }
        e2 = 2 * err;
        if (e2 >= dy)
        {
            err += dy;
            x0 += sx;
        }
        if (e2 <= dx)
        {
            err += dx;
            y0 += sy;
        }
    }
}

static void hink_v2_circle(int cx, int cy, int radius, uint8_t color)
{
    int x = radius;
    int y = 0;
    int err = 1 - radius;

    while (x >= y)
    {
        hink_d7a_pixel(cx + x, cy + y, color);
        hink_d7a_pixel(cx + y, cy + x, color);
        hink_d7a_pixel(cx - y, cy + x, color);
        hink_d7a_pixel(cx - x, cy + y, color);
        hink_d7a_pixel(cx - x, cy - y, color);
        hink_d7a_pixel(cx - y, cy - x, color);
        hink_d7a_pixel(cx + y, cy - x, color);
        hink_d7a_pixel(cx + x, cy - y, color);
        y++;
        if (err < 0)
        {
            err += (2 * y) + 1;
        }
        else
        {
            x--;
            err += (2 * (y - x)) + 1;
        }
    }
}

static void hink_v2_small_uint_center(int cx, int cy, uint8_t value, uint8_t color)
{
    char buf[3];
    uint8_t len;
    uint8_t x;

    if (value >= 10U)
    {
        buf[0] = (char)('0' + (value / 10U));
        buf[1] = (char)('0' + (value % 10U));
        buf[2] = 0;
        len = 2U;
    }
    else
    {
        buf[0] = (char)('0' + value);
        buf[1] = 0;
        len = 1U;
    }
    x = (uint8_t)(cx - ((len * 6U) / 2U));
    draw_text(x, (uint8_t)(cy - 3), buf, color);
}

#define HINK_V2_SAYING_LINE_CHARS 18U
#define HINK_V2_SAYING_LINE_COUNT 3U

static const char * const hink_v2_daily_sayings[] = {
    "CO CONG MAI SAT|CO NGAY NEN KIM",
    "UONG NUOC|NHO NGUON",
    "AN QUA|NHO KE TRONG CAY",
    "LA LANH|DUM LA RACH",
    "CHAM MA CHAC",
    "TOT GO HON|TOT NUOC SON",
    "DI MOT NGAY DANG|HOC MOT SANG KHON",
    "GAN MUC THI DEN|GAN DEN THI SANG",
    "CO CHI THI NEN",
    "THAT BAI LA ME|THANH CONG",
    "KIEN THA LAU|DAY TO",
    "TICH TIEU|THANH DAI",
    "MOT CAY LAM CHANG|NEN NON",
    "BA CAY CHUM LAI|NEN HON NUI CAO",
    "LOI NOI|GOI VANG",
    "HOC AN HOC NOI|HOC GOI HOC MO",
    "DOI KHI|IM LANG LA VANG",
    "THUONG NGUOI|NHU THUONG THAN",
    "O HIEN GAP LANH",
    "GIEO GIO|GAT BAO",
    "AN CHAC|MAC BEN",
    "NANG NHAT|TAY QUEN VIEC GIOI",
    "LUA THU VANG|GIAN NAN THU SUC",
    "TRE GIA|MANG MOC",
    "THUOC HAY|DANG MIENG",
    "HON MOT NGAY|KHON MOT CHUT",
    "KHON NGOAN|DOI DAP BEN NGOAI",
    "DAU XUOI|DUOI LOT",
    "CHON BAN MA CHOI|CHON NOI MA O",
    "MO CUA|DON NGAY MOI",
    "GIU LONG AN NHIEN|VIEC SE THANH",
    "SONG CHAM|NGHI SAU",
    "BIET DU|THAY VUI",
    "NGAY MOI|HY VONG MOI",
    "BINH AN|LA PHUC",
    "HOM NAY|LAM DIEU TOT"
};

static void hink_v2_draw_daily_saying(uint32_t local_day)
{
    const char *text;
    char line[HINK_V2_SAYING_LINE_CHARS + 1U];
    uint8_t row = 0U;
    uint8_t len;
    uint8_t x;

    text = hink_v2_daily_sayings[
        local_day % (sizeof(hink_v2_daily_sayings) /
                     sizeof(hink_v2_daily_sayings[0]))
    ];

    while ((*text != 0) && (row < HINK_V2_SAYING_LINE_COUNT))
    {
        len = 0U;
        while ((*text != 0) && (*text != '|'))
        {
            if (len < HINK_V2_SAYING_LINE_CHARS)
            {
                line[len++] = *text;
            }
            text++;
        }
        if (*text == '|')
        {
            text++;
        }

        line[len] = 0;
        x = (uint8_t)((EPD_FRAME_WIDTH - ((uint16_t)len * 6U)) / 2U);
        draw_text(x, (uint8_t)(190U + (row * 14U)), line, BLACK);
        row++;
    }
}

static void hink_v2_draw_clock_classic(uint8_t h, uint8_t m,
                                       uint32_t local_day,
                                       uint16_t sy, uint8_t sm, uint8_t sd,
                                       uint8_t sw, uint8_t lunar_valid,
                                       uint8_t lm, uint8_t ld)
{
    char date_buf[14];
    uint8_t hour;
    uint8_t minute;
    uint8_t idx;
    uint8_t long_tick;
    uint8_t inner;
    uint8_t outer;
    int cx = 61;
    int cy = 72;
    int x0;
    int y0;
    int x1;
    int y1;

    hink_weekday(date_buf, sw);
    date_buf[2] = ' ';
    hink_put_2(&date_buf[3], sd);
    date_buf[5] = '/';
    hink_put_2(&date_buf[6], (uint8_t)(sm + 1U));
    date_buf[8] = '/';
    hink_put_4(&date_buf[9], sy);
    date_buf[13] = 0;
    hink_v2_line(31, 134, 90, 134, BLACK);
    draw_text(22, 143, date_buf, BLACK);
    hink_d9a_draw_lunar(37, 163, lunar_valid, lm, ld);
    hink_v2_draw_daily_saying(local_day);

    hink_v2_circle(cx, cy, 51, BLACK);

    /* Outer hour layer: alternating long/short ticks + labels 1..12. */
    for (hour = 1U; hour <= 12U; hour++)
    {
        idx = (uint8_t)((hour * 5U) % 60U);
        long_tick = (uint8_t)((hour & 1U) == 0U);
        inner = long_tick ? 46U : 48U;
        outer = 50U;
        x0 = cx + hink_v2_scale(hink_v2_x60[idx], inner);
        y0 = cy + hink_v2_scale(hink_v2_y60[idx], inner);
        x1 = cx + hink_v2_scale(hink_v2_x60[idx], outer);
        y1 = cy + hink_v2_scale(hink_v2_y60[idx], outer);
        hink_v2_line(x0, y0, x1, y1, BLACK);
        hink_v2_small_uint_center(
            cx + hink_v2_scale(hink_v2_x60[idx], 36U),
            cy + hink_v2_scale(hink_v2_y60[idx], 36U),
            hour,
            BLACK
        );
    }

    /*
     * Inner minute ring.
     *
     * 60 marks are kept well inside the 1..12 hour numerals:
     *   hour labels : radius 36
     *   minute ring : 5-minute radius 26..30; other minutes 29..30
     *
     * This leaves a visible gap instead of letting the inner/outer
     * marks touch the hour numbers.
     */
    for (minute = 0U; minute < 60U; minute++)
    {
        idx = minute;
        if ((minute % 5U) == 0U)
        {
            inner = 26U;
            outer = 30U;
        }
        else
        {
            inner = 29U;
            outer = 30U;
        }

        hink_v2_line(
            cx + hink_v2_scale(hink_v2_x60[idx], inner),
            cy + hink_v2_scale(hink_v2_y60[idx], inner),
            cx + hink_v2_scale(hink_v2_x60[idx], outer),
            cy + hink_v2_scale(hink_v2_y60[idx], outer),
            BLACK
        );
    }

    /* Hands: hour short/thick, minute long/thin. No seconds on e-ink. */
    idx = (uint8_t)((((h % 12U) * 5U) + (m / 12U)) % 60U);
    x1 = cx + hink_v2_scale(hink_v2_x60[idx], 21U);
    y1 = cy + hink_v2_scale(hink_v2_y60[idx], 21U);
    hink_v2_line(cx, cy, x1, y1, BLACK);
    hink_v2_line(cx + 1, cy, x1 + 1, y1, BLACK);

    idx = m;
    x1 = cx + hink_v2_scale(hink_v2_x60[idx], 33U);
    y1 = cy + hink_v2_scale(hink_v2_y60[idx], 33U);
    hink_v2_line(cx, cy, x1, y1, BLACK);
    hink_d7a_box(cx - 2, cy - 2, cx + 2, cy + 2, BLACK);
}

static uint16_t hink_v2_day_of_year(uint16_t y, uint8_t m, uint8_t d)
{
    uint8_t mm;
    uint16_t doy = d;
    for (mm = 0U; mm < m; mm++)
    {
        doy = (uint16_t)(doy + hink_d3c_solar_mdays(y, mm));
    }
    return doy;
}

static uint8_t hink_v2_iso_weeks_in_year(uint16_t y)
{
    uint16_t sy;
    uint8_t sm;
    uint8_t sd;
    uint8_t sw;
    uint8_t iso_jan1;
    uint32_t jan1_day = HINK_D3C_UNIX_DAY_2024_01_01;
    uint16_t yy;

    if (y >= 2024U)
    {
        for (yy = 2024U; yy < y; yy++)
        {
            jan1_day += (uint32_t)(365U + hink_d3c_solar_leap(yy));
        }
    }
    else
    {
        for (yy = y; yy < 2024U; yy++)
        {
            jan1_day -= (uint32_t)(365U + hink_d3c_solar_leap(yy));
        }
    }
    hink_d3c_solar_from_day(jan1_day, &sy, &sm, &sd, &sw);
    iso_jan1 = (sw == 0U) ? 7U : sw;
    return (uint8_t)((iso_jan1 == 4U || (iso_jan1 == 3U && hink_d3c_solar_leap(y))) ? 53U : 52U);
}

static uint8_t hink_v2_iso_week(uint16_t y, uint8_t m, uint8_t d, uint8_t sw)
{
    int week;
    uint8_t iso_wday = (sw == 0U) ? 7U : sw;
    uint16_t doy = hink_v2_day_of_year(y, m, d);
    uint8_t weeks = hink_v2_iso_weeks_in_year(y);

    week = ((int)doy - (int)iso_wday + 10) / 7;
    if (week < 1)
    {
        return hink_v2_iso_weeks_in_year((uint16_t)(y - 1U));
    }
    if (week > weeks)
    {
        return 1U;
    }
    return (uint8_t)week;
}

static void hink_v2_week_small_day(int cx, uint8_t y, uint8_t day, uint8_t color)
{
    char buf[3];
    uint8_t len;
    uint8_t x;

    if (day >= 10U)
    {
        buf[0] = (char)('0' + (day / 10U));
        buf[1] = (char)('0' + (day % 10U));
        buf[2] = 0;
        len = 2U;
    }
    else
    {
        buf[0] = (char)('0' + day);
        buf[1] = 0;
        len = 1U;
    }
    x = (uint8_t)(cx - ((len * 6U) / 2U));
    draw_text(x, y, buf, color);
}

static void hink_v2_draw_weekly(uint32_t local_day, uint8_t h, uint8_t m,
                                uint16_t sy, uint8_t sm, uint8_t sd,
                                uint8_t sw, uint8_t lunar_valid,
                                uint8_t lm, uint8_t ld)
{
    char header[18];
    char footer[10];
    char wbuf[3];
    char timebuf[6];
    uint8_t iso_wday = (sw == 0U) ? 7U : sw;
    uint8_t week = hink_v2_iso_week(sy, sm, sd, sw);
    uint32_t monday = local_day - (uint32_t)(iso_wday - 1U);
    uint8_t col;
    uint16_t wy;
    uint8_t wm;
    uint8_t wd;
    uint8_t ww;
    uint8_t wlm;
    uint8_t wld;
    uint8_t wlv;
    uint8_t active;
    uint8_t x;
    uint8_t day_color;
    int x1;
    int x2;

    /* Vietnamese header: THĂNG mm Â· TUáº¦N ww. The compact firmware font is ASCII,
       so the accent marks and middle dot are drawn explicitly. */
    header[0] = 'T'; header[1] = 'H'; header[2] = 'A'; header[3] = 'N'; header[4] = 'G';
    header[5] = ' ';
    hink_put_2(&header[6], (uint8_t)(sm + 1U));
    header[8] = ' '; header[9] = ' ';
    header[10] = 'T'; header[11] = 'U'; header[12] = 'A'; header[13] = 'N'; header[14] = ' ';
    hink_put_2(&header[15], week);
    header[17] = 0;
    draw_text(6, 8, header, BLACK);
    /* acute over A in THĂNG */
    hink_d7a_pixel(21, 4, BLACK); hink_d7a_pixel(22, 3, BLACK);
    /* middle dot */
    hink_d7a_box(61, 10, 62, 11, BLACK);
    /* circumflex + grave over A in TUáº¦N */
    hink_d7a_pixel(79, 6, BLACK); hink_d7a_pixel(80, 5, BLACK); hink_d7a_pixel(81, 6, BLACK);
    hink_d7a_pixel(78, 3, BLACK); hink_d7a_pixel(79, 4, BLACK);

    /* Phone-style digital time in the top-right header gap. */
    hink_put_2(&timebuf[0], h);
    timebuf[2] = ':';
    hink_put_2(&timebuf[3], m);
    timebuf[5] = 0;
    draw_text(214, 8, timebuf, BLACK);

    wbuf[2] = 0;
    for (col = 0U; col < 7U; col++)
    {
        uint32_t day_key = monday + col;
        hink_d3c_solar_from_day(day_key, &wy, &wm, &wd, &ww);
        wlv = hink_d3c_lunar_from_solar(wy, wm, wd, &wlm, &wld);
        active = (uint8_t)(day_key == local_day);
        x1 = 3 + ((int)col * 35);
        x2 = x1 + 33;

        /* Keep every column white/readable. Today gets a compact black date badge only. */
        hink_v2_line(x1, 18, x2, 18, BLACK);
        hink_v2_line(x2, 18, x2, 99, BLACK);
        hink_v2_line(x2, 99, x1, 99, BLACK);
        hink_v2_line(x1, 99, x1, 18, BLACK);
        day_color = BLACK;
        if (active)
        {
            hink_d7a_box(x1 + 5, 40, x2 - 5, 62, BLACK);
            day_color = WHITE;
        }

        wbuf[0] = (col == 6U) ? 'C' : 'T';
        wbuf[1] = (col == 6U) ? 'N' : (char)('2' + col);
        draw_text((uint8_t)(x1 + 11), 23, wbuf, BLACK);

        x = (uint8_t)(x1 + ((wd >= 10U) ? 10U : 14U));
        hink_d7a_draw_day(x, 45, wd, day_color);

        if (wlv)
        {
            hink_v2_week_small_day(x1 + 17, 70, wld, BLACK);
        }
        else
        {
            draw_text((uint8_t)(x1 + 11), 70, "--", BLACK);
        }
        draw_text((uint8_t)(x1 + 11), 87, "AM", BLACK);
        hink_d7a_draw_circumflex((uint8_t)(x1 + 11), 84U);
    }

    hink_weekday(footer, sw);
    footer[2] = ' ';
    hink_put_2(&footer[3], sd);
    footer[5] = '/';
    hink_put_2(&footer[6], (uint8_t)(sm + 1U));
    footer[8] = 0;
    draw_text(6, 108, footer, BLACK);
    hink_d9a_draw_lunar(184, 108, lunar_valid, lm, ld);
}
