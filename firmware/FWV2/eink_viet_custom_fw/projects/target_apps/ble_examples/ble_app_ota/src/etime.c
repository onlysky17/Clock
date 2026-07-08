#include "etime.h"

uint32_t SEC_PER_YR[2] = {31536000, 31622400}; // 闰年和非闰年的秒数
uint32_t SEC_PER_MT[2][12] = {
    {2678400, 2419200, 2678400, 2592000, 2678400, 2592000,
     2678400, 2678400, 2592000, 2678400, 2592000, 2678400},
    {2678400, 2505600, 2678400, 2592000, 2678400, 2592000,
     2678400, 2678400, 2592000, 2678400, 2592000, 2678400},
};

/**
 * @Name       : static int is_leap(int yr)
 * @Description: 判断是否为闰年
 * 				"非整百年份：能被4整除的是闰年。"
 * 				"整百年份：能被400整除的是闰年。"
 * @In         : 待机算的年份
 * @Out        : 1：是闰年   0：非闰年
 * @Author     : Denis
 */
int is_leap(int yr)
{
    if (NULL == (yr % 100))
        return (yr % 400 == 0) ? 1 : 0;
    else
        return (yr % 4 == 0) ? 1 : 0;
}

/**
 * @Name       : static unsigned char day_of_week_get(unsigned char month, unsigned char day,
                                     unsigned short year)
 * @Description: 根据输入的年月日计算当天为星期几
 * @In         : 年、月、日
 * @Out        : 星期几
 * @Author     : Denis
 */
unsigned char day_of_week_get(unsigned char month, unsigned char day,
                              unsigned short year)
{
    /* Month should be a number 0 to 11, Day should be a number 1 to 31 */

    static int t[] = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};
    year -= (uint8_t)(month < 3);
    return (year + year / 4 - year / 100 + year / 400 + t[month - 1] + day) % 7;
}
void transformTime(uint32_t unix_time, struct devtm *result)
{
    int leapyr = 0;
    /*默认将Unix时间戳转换为东八区时间信息，8×60×60=28800*/
    uint32_t ltime = unix_time;

    memset(result, 0, sizeof(struct devtm));
    result->tm_year = EPOCH_YR;

    while (1)
    {
        if (ltime < SEC_PER_YR[is_leap(result->tm_year)])
        {
            break;
        }
        ltime -= SEC_PER_YR[is_leap(result->tm_year)];
        ++(result->tm_year);
    }

    leapyr = is_leap(result->tm_year);

    while (1)
    {
        if (ltime < SEC_PER_MT[leapyr][result->tm_mon])
            break;
        ltime -= SEC_PER_MT[leapyr][result->tm_mon];
        ++(result->tm_mon);
    }

    result->tm_mday = ltime / SEC_PER_DY;
    ++(result->tm_mday);
    ltime = ltime % SEC_PER_DY;

    result->tm_hour = ltime / SEC_PER_HR;
    ltime = ltime % SEC_PER_HR;

    result->tm_min = ltime / 60;
    result->tm_sec = ltime % 60;

    result->tm_wday =
        day_of_week_get(result->tm_mon + 1, result->tm_mday,
                        result->tm_year);

    /*
     * The number of years since YEAR0"
     */
    result->tm_year -= YEAR0;
}