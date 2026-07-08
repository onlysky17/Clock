#ifndef _ETIME_H_
#define _ETIME_H_

#include "stdint.h"
#include "string.h"

#define YEAR0 (1900)	   /* The first year */
#define EPOCH_YR (1970)	   /* EPOCH = Jan 1 1970 00:00:00 */
#define SEC_PER_DY (86400) //一天的秒数
#define SEC_PER_HR (3600)  //一小时的秒数

typedef struct devtm
{
    uint16_t tm_year;
    uint8_t tm_mon;
    uint8_t tm_mday;
    uint8_t tm_hour;
    uint8_t tm_min;
    uint8_t tm_sec;
    uint8_t tm_wday;
}tm_t;

void transformTime(uint32_t unix_time,struct devtm *result);


#endif