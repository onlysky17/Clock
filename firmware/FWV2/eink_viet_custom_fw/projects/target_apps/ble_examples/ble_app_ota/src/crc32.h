#ifndef _CRC_32_H_
#define _CRC_32_H_
#include "stdint.h"
#include "stdbool.h"
#define DEFAULT_POLY 0x4C11DB7
/*
测试用例：
void main(void)
{
	unsigned long crc;
	crc32_init(0x4C11DB7,table);

	crc = 0xFFFFFFFF;
	crc=crc32(crc,"1234567890",10);
	crc ^= 0xFFFFFFFF;
	printf("CRC32=%08X\n",crc);
	system("pause");
}

计算结果：

CRC32=0x261DAEE5
*/



void crc32_init(unsigned long poly);
unsigned long crc32(unsigned long crc, void* input, int len);
#endif