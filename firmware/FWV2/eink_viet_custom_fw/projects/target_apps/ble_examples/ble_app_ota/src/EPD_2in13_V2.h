/*****************************************************************************
* | File      	:   EPD_2in13_V2.h
* | Author      :   Waveshare team
* | Function    :   2.13inch e-paper V2
* | Info        :
*----------------
* |	This version:   V3.0
* | Date        :   2019-06-13
* | Info        :
* -----------------------------------------------------------------------------
* V3.0(2019-06-13):
* 1.Change name:
*    EPD_Reset() => EPD_2IN13_V2_Reset()
*    EPD_SendCommand() => EPD_2IN13_V2_SendCommand()
*    EPD_SendData() => EPD_2IN13_V2_SendData()
*    EPD_WaitUntilIdle() => EPD_2IN13_V2_ReadBusy()
*    EPD_Init() => EPD_2IN13_V2_Init()
*    EPD_Clear() => EPD_2IN13_V2_Clear()
*    EPD_Display() => EPD_2IN13_V2_Display()
*    EPD_Sleep() => EPD_2IN13_V2_Sleep()
* 2.add:
*    EPD_2IN13_V2_DisplayPartBaseImage()
* -----------------------------------------------------------------------------
* V2.0(2018-11-14):
* 1.Remove:ImageBuff[EPD_HEIGHT * EPD_WIDTH / 8]
* 2.Change:EPD_2IN13_V2_Display(UBYTE *Image)
*   Need to pass parameters: pointer to cached data
* 3.Change:
*   EPD_RST -> EPD_RST_PIN
*   EPD_DC -> EPD_DC_PIN
*   EPD_CS -> EPD_CS_PIN
*   EPD_BUSY -> EPD_BUSY_PIN
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documnetation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to  whom the Software is
# furished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS OR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
******************************************************************************/
#ifndef _EPD_2IN13_V2_H_
#define _EPD_2IN13_V2_H_
#include "stdint.h"
#include "stdbool.h"
#include "gpio.h"
#include "systick.h"
#include "spi.h"
#include "user_periph_setup.h"
#define UBYTE   uint8_t
#define UWORD   uint16_t
#define UDOUBLE uint32_t

// Display resolution
#define EPD_2IN13_V2_WIDTH       104
#define EPD_2IN13_V2_HEIGHT      212
// #define EPD_2IN13_V2_WIDTH       400
// #define EPD_2IN13_V2_HEIGHT      300

#define EPD_2IN13_V2_FULL			0
#define EPD_2IN13_V2_PART			1

/*
EPD_POWER  P23 H
    
BUSY              P20
RST                 P07
DC                  p05
CS                   P21
SCLK               P00
SDI                  P06

*/

// #define EPD_SCLK_H   GPIO_SetActive(GPIO_PORT_0, GPIO_PIN_1)
// #define EPD_SCLK_L   GPIO_SetInactive(GPIO_PORT_0, GPIO_PIN_1)
// #define EPD_SDI_H    GPIO_SetActive(GPIO_PORT_2, GPIO_PIN_0)
// #define EPD_SDI_L    GPIO_SetInactive(GPIO_PORT_2, GPIO_PIN_0)


#define EPD_SCLK_H   GPIO_SetActive(GPIO_PORT_0, GPIO_PIN_0)
#define EPD_SCLK_L   GPIO_SetInactive(GPIO_PORT_0, GPIO_PIN_0)
#define EPD_SDI_H    GPIO_SetActive(GPIO_PORT_0, GPIO_PIN_6)
#define EPD_SDI_L    GPIO_SetInactive(GPIO_PORT_0, GPIO_PIN_6)
#define EPD_DC_H     GPIO_SetActive(GPIO_PORT_0, GPIO_PIN_5)
#define EPD_DC_L     GPIO_SetInactive(GPIO_PORT_0, GPIO_PIN_5)
#define EPD_CS_H     GPIO_SetActive(GPIO_PORT_2, GPIO_PIN_1)      
#define EPD_CS_L     GPIO_SetInactive(GPIO_PORT_2, GPIO_PIN_1)    
#define EPD_RST_H    GPIO_SetActive(GPIO_PORT_0, GPIO_PIN_7) 
#define EPD_RST_L    GPIO_SetInactive(GPIO_PORT_0, GPIO_PIN_7)
#define EPD_BUSY     GPIO_GetPinStatus(GPIO_PORT_2,GPIO_PIN_0)

#define DEV_Delay_ms(ms)   systick_wait(ms*1000)
// Display resolution
#define EPD_2IN9_WIDTH       128
#define EPD_2IN9_HEIGHT      296

#define EPD_2IN9_FULL			0
#define EPD_2IN9_PART			1
void EPD_GPIO_init(void);
void EPD_2IN13_V2_Init_RED(void);
void EPD_2IN13_V2_TurnOnDisplay_RED(void);
void EPD_2IN13_V2_Clear_RED(void);
void DEV_SPI_WriteByte(uint8_t sdbyte);
void EPD_2IN13_V2_Init(UBYTE Mode);
void EPD_2IN13_V2_Clear(void);
void EPD_2IN13_V2_Display(UBYTE *Image);
void EPD_2IN13_V2_DisplayPart(UBYTE *Image);
void EPD_2IN13_V2_DisplayPartBaseImage(UBYTE *Image);
void EPD_2IN13_V2_Sleep(void);
void EPD_2IN13_V2_TurnOnDisplayPart(void);
void EPD_2IN13_V2_TurnOnDisplay(void);
void EPD_4IN2BC_Init(void);
void EPD_4IN2BC_Clear(void);
void EPD_4IN2BC_Sleep(void);
void EPD_4IN2BC_Display(const uint8_t *blackimage, const uint8_t *ryimage);
void EPD_DrawImage( const uint8_t *image, uint16_t x, uint16_t y, uint16_t w, uint16_t h,bool part );
void EPD_SetWindow(uint16_t x, uint8_t y_x8, uint16_t x_size, uint8_t y_size_x8);
void EPD_4IN2BC_TurnOnDisplay(void);
void EPD_2IN9_Init(UBYTE Mode);
void EPD_2IN9_Clear(void);
void EPD_2IN9_Display(UBYTE *Image);
void EPD_2IN9_Sleep(void);
#endif




