#ifndef _LUNAR_H_
#define _LUNAR_H_

#include "DEV_Config.h"

struct Lunar_Date
{
    uint8_t IsLeap;
    uint8_t Date;
    uint8_t Month;
    uint16_t Year;
};

extern const char Lunar_MonthString[13][7];

extern const char Lunar_MonthLeapString[2][4];

extern const char Lunar_DateString[31][7];

extern const char Lunar_ZodiacString[12][4];

extern const char Lunar_StemStrig[10][4];

extern const char Lunar_BranchStrig[12][4];

extern const char JieQiStr[24][7];
extern const char WEEKCN[8][4];

void LUNAR_SolarToLunar(struct Lunar_Date *lunar, uint16_t solar_year, uint8_t solar_month, uint8_t solar_date);
uint8_t LUNAR_GetZodiac(const struct Lunar_Date *lunar);
uint8_t LUNAR_GetStem(const struct Lunar_Date *lunar);
uint8_t LUNAR_GetBranch(const struct Lunar_Date *lunar);
uint8_t GetJieQiStr(uint16_t myear, uint8_t mmonth, uint8_t mday, uint8_t *day);
uint8_t GetJieQi(uint16_t myear, uint8_t mmonth, uint8_t mday, uint8_t *JQdate);
#endif
