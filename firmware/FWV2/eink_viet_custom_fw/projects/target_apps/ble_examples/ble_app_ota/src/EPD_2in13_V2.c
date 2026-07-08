/*****************************************************************************
* | File      	:   EPD_2in13_V2.c
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
#include "EPD_2in13_V2.h"
#include "Debug.h"

const unsigned char EPD_2IN13_V2_lut_full_update[] = {
        0x80, 0x60, 0x40, 0x00, 0x00, 0x00, 0x00,             //LUT0: BB:     VS 0 ~7
        0x10, 0x60, 0x20, 0x00, 0x00, 0x00, 0x00,             //LUT1: BW:     VS 0 ~7
        0x80, 0x60, 0x40, 0x00, 0x00, 0x00, 0x00,             //LUT2: WB:     VS 0 ~7
        0x10, 0x60, 0x20, 0x00, 0x00, 0x00, 0x00,             //LUT3: WW:     VS 0 ~7
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,             //LUT4: VCOM:   VS 0 ~7

        0x03, 0x03, 0x00, 0x00, 0x02,                       // TP0 A~D RP0
        0x09, 0x09, 0x00, 0x00, 0x02,                       // TP1 A~D RP1
        0x03, 0x03, 0x00, 0x00, 0x02,                       // TP2 A~D RP2
        0x00, 0x00, 0x00, 0x00, 0x00,                       // TP3 A~D RP3
        0x00, 0x00, 0x00, 0x00, 0x00,                       // TP4 A~D RP4
        0x00, 0x00, 0x00, 0x00, 0x00,                       // TP5 A~D RP5
        0x00, 0x00, 0x00, 0x00, 0x00,                       // TP6 A~D RP6

        0x15, 0x41, 0xA8, 0x32, 0x30, 0x0A,
};

const unsigned char EPD_2IN13_V2_lut_partial_update[] = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,             //LUT0: BB:     VS 0 ~7
        0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,             //LUT1: BW:     VS 0 ~7
        0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,             //LUT2: WB:     VS 0 ~7
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,             //LUT3: WW:     VS 0 ~7
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,             //LUT4: VCOM:   VS 0 ~7

        0x0A, 0x00, 0x00, 0x00, 0x00,                       // TP0 A~D RP0
        0x00, 0x00, 0x00, 0x00, 0x00,                       // TP1 A~D RP1
        0x00, 0x00, 0x00, 0x00, 0x00,                       // TP2 A~D RP2
        0x00, 0x00, 0x00, 0x00, 0x00,                       // TP3 A~D RP3
        0x00, 0x00, 0x00, 0x00, 0x00,                       // TP4 A~D RP4
        0x00, 0x00, 0x00, 0x00, 0x00,                       // TP5 A~D RP5
        0x00, 0x00, 0x00, 0x00, 0x00,                       // TP6 A~D RP6

        0x15, 0x41, 0xA8, 0x32, 0x30, 0x0A,
};

const unsigned char EPD_2IN9_lut_full_update[] = {
    0x50, 0xAA, 0x55, 0xAA, 0x11, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0xFF, 0xFF, 0x1F, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

const unsigned char EPD_2IN9_lut_partial_update[] = {
    0x10, 0x18, 0x18, 0x08, 0x18, 0x18,
    0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x13, 0x14, 0x44, 0x12,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};
void EPD_GPIO_init(void){
    //EPD_VCC ENABLE
    GPIO_ConfigurePin(GPIO_PORT_2, GPIO_PIN_3, OUTPUT, PID_GPIO, true);
    // GPIO_SetActive(GPIO_PORT_2, GPIO_PIN_3);
    // DEV_Delay_ms(10);
    GPIO_ConfigurePin(GPIO_PORT_2, GPIO_PIN_0, INPUT, PID_GPIO, false);
    GPIO_ConfigurePin(GPIO_PORT_2, GPIO_PIN_1, OUTPUT, PID_GPIO, true);
    GPIO_ConfigurePin(GPIO_PORT_0, GPIO_PIN_7, OUTPUT, PID_GPIO, true);
    GPIO_ConfigurePin(GPIO_PORT_0, GPIO_PIN_5, OUTPUT, PID_GPIO, false);
    // GPIO_ConfigurePin(GPIO_PORT_0, GPIO_PIN_3, OUTPUT, PID_GPIO, true);
    // GPIO_ConfigurePin(GPIO_PORT_2, GPIO_PIN_0, OUTPUT, PID_GPIO, false);
  
}

void DEV_SPI_WriteByte(uint8_t sdbyte)
{
    // uint8_t i;
    // for (i = 0; i < 8; i++)
    // {
    //     EPD_SCLK_L;
    //     if (sdbyte & 0x80)
    //     {
    //         EPD_SDI_H;
    //     }
    //     else
    //     {
    //         EPD_SDI_L;
    //     }
    //     sdbyte <<= 1;
    //     EPD_SCLK_H;
    // }
    // EPD_SCLK_L;
    spi_access(sdbyte);
}

/******************************************************************************
function :	Software reset
parameter:
******************************************************************************/
static void EPD_2IN13_V2_Reset(void)
{
    EPD_RST_L;
    DEV_Delay_ms(2);
    EPD_RST_H;
    DEV_Delay_ms(5);
}

/******************************************************************************
function :	send command
parameter:
     Reg : Command register
******************************************************************************/
static void EPD_2IN13_V2_SendCommand(UBYTE Reg)
{
    EPD_DC_L;
    EPD_CS_L;
    DEV_SPI_WriteByte(Reg);
    EPD_CS_H;
}

/******************************************************************************
function :	send data
parameter:
    Data : Write data
******************************************************************************/
static void EPD_2IN13_V2_SendData(UBYTE Data)
{
    EPD_DC_H;
    EPD_CS_L;
    DEV_SPI_WriteByte(Data);
    EPD_CS_H;
}

/******************************************************************************
function :	Wait until the busy_pin goes LOW
parameter:
******************************************************************************/
void EPD_2IN13_V2_ReadBusy(void)
{
    Debug("e-Paper busy\r\n");
    while (EPD_BUSY !=0)
    { //LOW: idle, HIGH: busy
      
    }
    Debug("e-Paper busy release\r\n");
}

/******************************************************************************
function :	Turn On Display
parameter:
******************************************************************************/
 void EPD_2IN13_V2_TurnOnDisplay(void)
{
    EPD_2IN13_V2_SendCommand(0x22);
    EPD_2IN13_V2_SendData(0xC4);
    EPD_2IN13_V2_SendCommand(0x20);
    // EPD_2IN13_V2_ReadBusy();
}

 void EPD_2IN13_V2_TurnOnDisplay_RED(void)
{
    EPD_2IN13_V2_SendCommand(0x22);
    EPD_2IN13_V2_SendData(0xF7);
    EPD_2IN13_V2_SendCommand(0x20);
    EPD_2IN13_V2_ReadBusy();
}
/******************************************************************************
function :	Turn On Display
parameter:
******************************************************************************/
 void EPD_2IN13_V2_TurnOnDisplayPart(void)
{
    EPD_2IN13_V2_SendCommand(0x22);
    EPD_2IN13_V2_SendData(0x04);
    EPD_2IN13_V2_SendCommand(0x20);
    // EPD_2IN13_V2_ReadBusy();
}


void EPD_2IN13_V2_Init_RED(void) {

    /* EPD hardware init start */
        EPD_2IN13_V2_Reset();
    
        EPD_2IN13_V2_ReadBusy();
        EPD_2IN13_V2_SendCommand(0x12); // soft reset
        EPD_2IN13_V2_ReadBusy();

        EPD_2IN13_V2_SendCommand(0x74); //set analog block control
        EPD_2IN13_V2_SendData(0x54);
        EPD_2IN13_V2_SendCommand(0x7E); //set digital block control
        EPD_2IN13_V2_SendData(0x3B);

        EPD_2IN13_V2_SendCommand(0x01); //Driver output control
        EPD_2IN13_V2_SendData(0xD3);
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0x00);

        EPD_2IN13_V2_SendCommand(0x11); //data entry mode
        EPD_2IN13_V2_SendData(0x03);

        EPD_2IN13_V2_SendCommand(0x44); //set Ram-X address start/end position
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0x0C);    //0x0C-->(15+1)*8=128

        EPD_2IN13_V2_SendCommand(0x45); //set Ram-Y address start/end position
        EPD_2IN13_V2_SendData(0x00);   //0xF9-->(249+1)=250
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0xD3);
        EPD_2IN13_V2_SendData(0x00);

        EPD_2IN13_V2_SendCommand(0x3C); //BorderWavefrom
        EPD_2IN13_V2_SendData(0x05);

        EPD_2IN13_V2_SendCommand(0x18); // set built in temperature sensor
        EPD_2IN13_V2_SendData(0x80); //	
        EPD_2IN13_V2_SendCommand(0x4E);   // set RAM x address count to 0;
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendCommand(0x4F);   // set RAM y address count to 0X127;
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0x00);
    
}

/******************************************************************************
function :	Initialize the e-Paper register
parameter:
******************************************************************************/
void EPD_2IN13_V2_Init(UBYTE Mode)
{
     UBYTE count;
    EPD_2IN13_V2_Reset();

    if (Mode == EPD_2IN13_V2_FULL)
    {
        EPD_2IN13_V2_ReadBusy();
        EPD_2IN13_V2_SendCommand(0x12); // soft reset
        EPD_2IN13_V2_ReadBusy();

        EPD_2IN13_V2_SendCommand(0x74); //set analog block control
        EPD_2IN13_V2_SendData(0x54);
        EPD_2IN13_V2_SendCommand(0x7E); //set digital block control
        EPD_2IN13_V2_SendData(0x3B);

        EPD_2IN13_V2_SendCommand(0x01); //Driver output control
        EPD_2IN13_V2_SendData((EPD_2IN13_V2_HEIGHT-1)&0xFF);    //0xF9-->(249+1)=250
        EPD_2IN13_V2_SendData(((EPD_2IN13_V2_HEIGHT-1)&0xFF00)>>8);
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0x00);


        EPD_2IN13_V2_SendCommand(0x11); //data entry mode
        EPD_2IN13_V2_SendData(0x01);

        EPD_2IN13_V2_SendCommand(0x44); //set Ram-X address start/end position
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(EPD_2IN13_V2_WIDTH/8-1); //0x0C-->(15+1)*8=128

        EPD_2IN13_V2_SendCommand(0x45); //set Ram-Y address start/end position
        EPD_2IN13_V2_SendData((EPD_2IN13_V2_HEIGHT-1)&0xFF);    //0xF9-->(249+1)=250
        EPD_2IN13_V2_SendData(((EPD_2IN13_V2_HEIGHT-1)&0xFF00)>>8);
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0x00);

  

        EPD_2IN13_V2_SendCommand(0x3C); //BorderWavefrom
        EPD_2IN13_V2_SendData(0x01);

        EPD_2IN13_V2_SendCommand(0x2C); //VCOM Voltage
        EPD_2IN13_V2_SendData(0x50);    //

        EPD_2IN13_V2_SendCommand(0x03);
        EPD_2IN13_V2_SendData(EPD_2IN13_V2_lut_full_update[70]);

        EPD_2IN13_V2_SendCommand(0x04); //
        EPD_2IN13_V2_SendData(EPD_2IN13_V2_lut_full_update[71]);
        EPD_2IN13_V2_SendData(EPD_2IN13_V2_lut_full_update[72]);
        EPD_2IN13_V2_SendData(EPD_2IN13_V2_lut_full_update[73]);

        EPD_2IN13_V2_SendCommand(0x3A); //Dummy Line
        EPD_2IN13_V2_SendData(EPD_2IN13_V2_lut_full_update[74]);
        EPD_2IN13_V2_SendCommand(0x3B); //Gate time
        EPD_2IN13_V2_SendData(EPD_2IN13_V2_lut_full_update[75]);
        EPD_2IN13_V2_SendCommand(0x32);
        for (count = 0; count < 70; count++)
        {
            EPD_2IN13_V2_SendData(EPD_2IN13_V2_lut_full_update[count]);
        }

        EPD_2IN13_V2_ReadBusy();
        EPD_2IN13_V2_SendCommand(0x4E); // set RAM x address count to 0;
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendCommand(0x4F); // set RAM y address count to 0X127;
        EPD_2IN13_V2_SendData((EPD_2IN13_V2_HEIGHT-1)&0xFF);    //0xF9-->(249+1)=250
        EPD_2IN13_V2_SendData(((EPD_2IN13_V2_HEIGHT-1)&0xFF00)>>8);
        EPD_2IN13_V2_SendData(EPD_2IN13_V2_HEIGHT-1);
        EPD_2IN13_V2_SendData(0x00);
       
    }
    else if (Mode == EPD_2IN13_V2_PART)
    {
        EPD_2IN13_V2_SendCommand(0x2C); //VCOM Voltage
        EPD_2IN13_V2_SendData(0x28);

        EPD_2IN13_V2_ReadBusy();

        EPD_2IN13_V2_SendCommand(0x32);
        for (count = 0; count < 70; count++)
        {
            EPD_2IN13_V2_SendData(EPD_2IN13_V2_lut_partial_update[count]);
        }

        EPD_2IN13_V2_SendCommand(0x37);
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0x40);
        EPD_2IN13_V2_SendData(0x00);
        EPD_2IN13_V2_SendData(0x00);

        EPD_2IN13_V2_SendCommand(0x22);
        EPD_2IN13_V2_SendData(0xC0);

        EPD_2IN13_V2_SendCommand(0x20);
        EPD_2IN13_V2_ReadBusy();

        // EPD_2IN13_V2_SendCommand(0x3C); //BorderWavefrom
        // EPD_2IN13_V2_SendData(0x01);
    }
    else
    {
        Debug("error, the Mode is EPD_2IN13_FULL or EPD_2IN13_PART");
    }
}

/**
 * @brief  设置EPD显示窗口位置和大小。
 * @param  x 显示窗口起始X位置。
 * @param  y_x8 显示窗口起始Y位置，设置1等于8像素。
 * @param  x_size 显示窗口X方向大小。
 * @param  y_size_x8 显示窗口Y方向大小，设置1等于8像素。
 * @note   指针已被自动设置至窗口的左上角。
 */
void EPD_SetWindow(uint16_t x, uint8_t y_x8, uint16_t x_size, uint8_t y_size_x8) {
   
    x = EPD_2IN13_V2_HEIGHT - 1 - x;
    x_size = x - x_size + 1;          /* x_size已变为x结束地址 */
    y_size_x8 = y_size_x8 + y_x8 - 1; /* y_size已变为y结束地址 */

    EPD_2IN13_V2_SendCommand(0x44); /* 设置X（短边）起始地址和结束地址，根据扫描方式不同，地址设置也不同 */
    EPD_2IN13_V2_SendData(y_x8);
    EPD_2IN13_V2_SendData(y_size_x8 & 0xFF);
    EPD_2IN13_V2_SendCommand(0x45); /* 设置Y（长边）起始地址和结束地址，根据扫描方式不同，地址设置也不同 */
    EPD_2IN13_V2_SendData(x & 0xFF);
    EPD_2IN13_V2_SendData(0);
    EPD_2IN13_V2_SendData(x_size & 0xFF);
    EPD_2IN13_V2_SendData(0);

    EPD_2IN13_V2_SendCommand(0x4E); /* 设置X（短边）地址计数器 */
    EPD_2IN13_V2_SendData(y_x8);
    EPD_2IN13_V2_SendCommand(0x4F); /* 设置Y（长边）地址计数器 */
    EPD_2IN13_V2_SendData(x & 0xFF);
    EPD_2IN13_V2_SendData(0);
}
/**
 * @brief  向EPD控制器发送指定大小的显示数据。
 * @param  data 要发送数据的指针。
 * @param  data_size 要发送数据的大小。
 */
void EPD_SendRAM(const uint8_t *data, uint16_t data_size)
{
    uint16_t i;
    EPD_2IN13_V2_SendCommand(0x24);
    for(i=0;i<data_size;i++){
        EPD_2IN13_V2_SendData(*(data+i));
    }
}

void EPD_SendOLDRAM(const uint8_t *data, uint16_t data_size)
{
    uint16_t i;
    EPD_2IN13_V2_SendCommand(0x26);
    for(i=0;i<data_size;i++){
        EPD_2IN13_V2_SendData(*(data+i));
    }
}
/**
 * @brief  清除EPD控制器指定区域显示RAM。
 * @note   执行完成后窗口会恢复至全屏幕。
 */
void EPD_ClearArea(uint16_t x, uint8_t y_x8, uint16_t x_size, uint8_t y_size_x8, uint8_t color)
{
    uint16_t i, data_size;

    data_size = x_size * (y_size_x8>>3);
    EPD_SetWindow(x, y_x8, x_size, y_size_x8>>3);
    EPD_2IN13_V2_SendCommand(0x24);
    for (i = 0; i < data_size; i++)
    {
        EPD_2IN13_V2_SendData(color);
    }
    EPD_SetWindow(0, 0, EPD_2IN13_V2_HEIGHT, EPD_2IN13_V2_WIDTH>>3);
}


void EPD_DrawImage( const uint8_t *image, uint16_t x, uint16_t y, uint16_t w, uint16_t h ,bool part)
{
    uint16_t i = 0;
    uint16_t size = w * h / 8;
    EPD_SetWindow(x, y, w, h / 8);
    EPD_2IN13_V2_SendCommand(0x24);
    for (i = 0; i < size; i++)
    {
        EPD_2IN13_V2_SendData(image[i]);
    }
    if (part)
    {
        EPD_2IN13_V2_SendCommand(0x26);
        for (i = 0; i < size; i++)
        {
            EPD_2IN13_V2_SendData(image[i]);
        }
    }
}


/******************************************************************************
function :	Clear screen
parameter:
******************************************************************************/
void EPD_2IN13_V2_Clear(void)
{
    UWORD Width, Height;
    Width = (EPD_2IN13_V2_WIDTH % 8 == 0) ? (EPD_2IN13_V2_WIDTH / 8) : (EPD_2IN13_V2_WIDTH / 8 + 1);
    Height = EPD_2IN13_V2_HEIGHT;

    EPD_2IN13_V2_SendCommand(0x24);
    for (UWORD j = 0; j < Height; j++)
    {
        for (UWORD i = 0; i < Width; i++)
        {
            EPD_2IN13_V2_SendData(0xff);
        }
    }
     EPD_2IN13_V2_SendCommand(0x26);
    for (UWORD j = 0; j < Height; j++)
    {
        for (UWORD i = 0; i < Width; i++)
        {
            EPD_2IN13_V2_SendData(0xff);
        }
    }

    EPD_2IN13_V2_TurnOnDisplay();
}

void EPD_2IN13_V2_Clear_RED(void)
{
    UWORD Width, Height;
    Width = (EPD_2IN13_V2_WIDTH % 8 == 0) ? (EPD_2IN13_V2_WIDTH / 8) : (EPD_2IN13_V2_WIDTH / 8 + 1);
    Height = EPD_2IN13_V2_HEIGHT;

    EPD_2IN13_V2_SendCommand(0x24);
    for (UWORD j = 0; j < Height; j++)
    {
        for (UWORD i = 0; i < Width; i++)
        {
            EPD_2IN13_V2_SendData(0xff);
        }
    }
     EPD_2IN13_V2_SendCommand(0x26);
    for (UWORD j = 0; j < Height; j++)
    {
        for (UWORD i = 0; i < Width; i++)
        {
            EPD_2IN13_V2_SendData(0x00);
        }
    }

    
}

/******************************************************************************
function :	Sends the image buffer in RAM to e-Paper and displays
parameter:
******************************************************************************/
void EPD_2IN13_V2_Display(UBYTE *Image)
{
    UWORD Width, Height;
    Width = (EPD_2IN13_V2_WIDTH % 8 == 0) ? (EPD_2IN13_V2_WIDTH / 8) : (EPD_2IN13_V2_WIDTH / 8 + 1);
    Height = EPD_2IN13_V2_HEIGHT;

    EPD_2IN13_V2_SendCommand(0x24);
    for (UWORD j = 0; j < Height; j++)
    {
        for (UWORD i = 0; i < Width; i++)
        {
            EPD_2IN13_V2_SendData(Image[i + j * Width]);
        }
    }
    EPD_2IN13_V2_TurnOnDisplay();
}

/******************************************************************************
function :	 The image of the previous frame must be uploaded, otherwise the
		         first few seconds will display an exception.
parameter:
******************************************************************************/
void EPD_2IN13_V2_DisplayPartBaseImage(UBYTE *Image)
{
    UWORD Width, Height;
    Width = (EPD_2IN13_V2_WIDTH % 8 == 0) ? (EPD_2IN13_V2_WIDTH / 8) : (EPD_2IN13_V2_WIDTH / 8 + 1);
    Height = EPD_2IN13_V2_HEIGHT;

    UDOUBLE Addr = 0;
    EPD_2IN13_V2_SendCommand(0x24);
    for (UWORD j = 0; j < Height; j++)
    {
        for (UWORD i = 0; i < Width; i++)
        {
            Addr = i + j * Width;
            EPD_2IN13_V2_SendData(Image[Addr]);
        }
    }
    EPD_2IN13_V2_SendCommand(0x26);
    for (UWORD j = 0; j < Height; j++)
    {
        for (UWORD i = 0; i < Width; i++)
        {
            Addr = i + j * Width;
            EPD_2IN13_V2_SendData(Image[Addr]);
        }
    }
    //   EPD_2IN13_V2_TurnOnDisplayPart();
    // EPD_2IN13_V2_TurnOnDisplay();
}

void EPD_2IN13_V2_DisplayPart(UBYTE *Image)
{
    UWORD Width, Height;
    Width = (EPD_2IN13_V2_WIDTH % 8 == 0) ? (EPD_2IN13_V2_WIDTH / 8) : (EPD_2IN13_V2_WIDTH / 8 + 1);
    Height = EPD_2IN13_V2_HEIGHT;
    UDOUBLE Addr = 0;
     EPD_2IN13_V2_SendCommand(0x24);
    for (UWORD j = 0; j < Height; j++)
    {
        for (UWORD i = 0; i < Width; i++)
        {
            Addr = i + j * Width;
            EPD_2IN13_V2_SendData(Image[Addr]);
        }
    }
    EPD_2IN13_V2_SendCommand(0x26);
    for (UWORD j = 0; j < Height; j++)
    {
        for (UWORD i = 0; i < Width; i++)
        {
            Addr = i + j * Width;
            EPD_2IN13_V2_SendData(~Image[Addr]);
        }
    }

    // EPD_2IN13_V2_SendCommand(0x26);
  
}

/******************************************************************************
function :	Enter sleep mode
parameter:
******************************************************************************/
void EPD_2IN13_V2_Sleep(void)
{
    // EPD_2IN13_V2_SendCommand(0x22); //POWER OFF
    // EPD_2IN13_V2_SendData(0xC3);
    // EPD_2IN13_V2_SendCommand(0x20);

    EPD_2IN13_V2_SendCommand(0x10); //enter deep sleep
    EPD_2IN13_V2_SendData(0x01);
    // DEV_Delay_ms(100);
}

#define EPD_4IN2BC_WIDTH       400
#define EPD_4IN2BC_HEIGHT      300

static void EPD_4IN2BC_Reset(void)
{
    EPD_RST_L;
    DEV_Delay_ms(20);
    EPD_RST_H;
    DEV_Delay_ms(20);
}

/******************************************************************************
function :	send command
parameter:
     Reg : Command register
******************************************************************************/
static void EPD_4IN2BC_SendCommand(UBYTE Reg)
{
     EPD_DC_L;
    EPD_CS_L;
    DEV_SPI_WriteByte(Reg);
    EPD_CS_H;
}

/******************************************************************************
function :	send data
parameter:
    Data : Write data
******************************************************************************/
static void EPD_4IN2BC_SendData(UBYTE Data)
{
    EPD_DC_H;
    EPD_CS_L;
    DEV_SPI_WriteByte(Data);
    EPD_CS_H;
}

/******************************************************************************
function :	Wait until the busy_pin goes LOW
parameter:
******************************************************************************/
void EPD_4IN2BC_ReadBusy(void)
{
    Debug("e-Paper busy\r\n");
    while(EPD_BUSY == 0) {      //0: busy, 1: idle
        DEV_Delay_ms(100);
    }
    Debug("e-Paper busy release\r\n");
}

/******************************************************************************
function :	Turn On Display
parameter:
******************************************************************************/
void EPD_4IN2BC_TurnOnDisplay(void)
{
    EPD_4IN2BC_SendCommand(0x12); // DISPLAY_REFRESH
    // DEV_Delay_ms(100);
    // EPD_4IN2BC_ReadBusy();
}

/******************************************************************************
function :	Initialize the e-Paper register
parameter:
******************************************************************************/
void EPD_4IN2BC_Init(void)
{
    EPD_4IN2BC_Reset();

    EPD_4IN2BC_SendCommand(0x06); // BOOSTER_SOFT_START
    EPD_4IN2BC_SendData(0x17);
    EPD_4IN2BC_SendData(0x17);
    EPD_4IN2BC_SendData(0x17); // 07 0f 17 1f 27 2F 37 2f
    EPD_4IN2BC_SendCommand(0x04); // POWER_ON
    EPD_4IN2BC_ReadBusy();
    EPD_4IN2BC_SendCommand(0x00); // PANEL_SETTING
    EPD_4IN2BC_SendData(0x0F); // LUT from OTP 0x0f
    EPD_4IN2BC_SendCommand(0X50);
	EPD_4IN2BC_SendData(0x97);
}

/******************************************************************************
function :	Clear screen
parameter:
******************************************************************************/
void EPD_4IN2BC_Clear(void)
{
    UWORD Width, Height;
    Width = (EPD_4IN2BC_WIDTH % 8 == 0)? (EPD_4IN2BC_WIDTH / 8 ): (EPD_4IN2BC_WIDTH / 8 + 1);
    Height = EPD_4IN2BC_HEIGHT;

    EPD_4IN2BC_SendCommand(0x10);
    for (UWORD j = 0; j < Height; j++) {
        for (UWORD i = 0; i < Width; i++) {
            EPD_4IN2BC_SendData(0xFF);
        }
    }

    EPD_4IN2BC_SendCommand(0x13);
    for (UWORD j = 0; j < Height; j++) {
        for (UWORD i = 0; i < Width; i++) {
            EPD_4IN2BC_SendData(0x00);
        }
    }

    EPD_4IN2BC_TurnOnDisplay();
}


/******************************************************************************
function :	Sends the image buffer in RAM to e-Paper and displays
parameter:
******************************************************************************/
void EPD_4IN2BC_Display(const uint8_t *blackimage, const uint8_t *ryimage)
{
    UWORD Width, Height;
    Width = (EPD_4IN2BC_WIDTH % 8 == 0) ? (EPD_4IN2BC_WIDTH / 8) : (EPD_4IN2BC_WIDTH / 8 + 1);
    Height = EPD_4IN2BC_HEIGHT;
    if (blackimage != 0)
    {
        EPD_4IN2BC_SendCommand(0x10);
        for (UWORD j = 0; j < Height; j++)
        {
            for (UWORD i = 0; i < Width; i++)
            {
                EPD_4IN2BC_SendData(blackimage[i + j * Width]);
                //  EPD_4IN2BC_SendData(0xff);
            }
        }
    }
    if (ryimage != 0)
    {
        EPD_4IN2BC_SendCommand(0x13);
        for (UWORD j = 0; j < Height; j++)
        {
            for (UWORD i = 0; i < Width; i++)
            {
                EPD_4IN2BC_SendData(ryimage[i + j * Width]);
                //  EPD_4IN2BC_SendData(0);
            }
        }

        // EPD_4IN2BC_TurnOnDisplay();
    }
}
/******************************************************************************
function :	Enter sleep mode
parameter:
******************************************************************************/
void EPD_4IN2BC_Sleep(void)
{
    EPD_4IN2BC_SendCommand(0x02); // POWER_OFF
    EPD_4IN2BC_ReadBusy();
    EPD_4IN2BC_SendCommand(0x07); // DEEP_SLEEP
    EPD_4IN2BC_SendData(0XA5);
}



static void EPD_2IN9_SetCursor(UWORD Xstart, UWORD Ystart)
{
    EPD_2IN13_V2_SendCommand(0x4E); // SET_RAM_X_ADDRESS_COUNTER
    EPD_2IN13_V2_SendData((Xstart >> 3) & 0xFF);

    EPD_2IN13_V2_SendCommand(0x4F); // SET_RAM_Y_ADDRESS_COUNTER
    EPD_2IN13_V2_SendData(Ystart & 0xFF);
    EPD_2IN13_V2_SendData((Ystart >> 8) & 0xFF);
}
static void EPD_2IN9_SetWindows(UWORD Xstart, UWORD Ystart, UWORD Xend, UWORD Yend)
{
    EPD_2IN13_V2_SendCommand(0x44); // SET_RAM_X_ADDRESS_START_END_POSITION
    EPD_2IN13_V2_SendData((Xstart >> 3) & 0xFF);
    EPD_2IN13_V2_SendData((Xend >> 3) & 0xFF);

    EPD_2IN13_V2_SendCommand(0x45); // SET_RAM_Y_ADDRESS_START_END_POSITION
    EPD_2IN13_V2_SendData(Ystart & 0xFF);
    EPD_2IN13_V2_SendData((Ystart >> 8) & 0xFF);
    EPD_2IN13_V2_SendData(Yend & 0xFF);
    EPD_2IN13_V2_SendData((Yend >> 8) & 0xFF);
}
/******************************************************************************
function :	Setting the display window
parameter:
******************************************************************************/

void EPD_2IN9_Init(UBYTE Mode)
{
    EPD_2IN13_V2_Reset();

    EPD_2IN13_V2_SendCommand(0x01); // DRIVER_OUTPUT_CONTROL
    EPD_2IN13_V2_SendData((EPD_2IN9_HEIGHT - 1) & 0xFF);
    EPD_2IN13_V2_SendData(((EPD_2IN9_HEIGHT - 1) >> 8) & 0xFF);
    EPD_2IN13_V2_SendData(0x00); // GD = 0; SM = 0; TB = 0;
	
    EPD_2IN13_V2_SendCommand(0x0C); // BOOSTER_SOFT_START_CONTROL
    EPD_2IN13_V2_SendData(0xD7);
    EPD_2IN13_V2_SendData(0xD6);
    EPD_2IN13_V2_SendData(0x9D);
	
    EPD_2IN13_V2_SendCommand(0x2C); // WRITE_VCOM_REGISTER
    EPD_2IN13_V2_SendData(0xA8); // VCOM 7C
	
    EPD_2IN13_V2_SendCommand(0x3A); // SET_DUMMY_LINE_PERIOD
    EPD_2IN13_V2_SendData(0x1A); // 4 dummy lines per gate
	
    EPD_2IN13_V2_SendCommand(0x3B); // SET_GATE_TIME
    EPD_2IN13_V2_SendData(0x08); // 2us per line
	
    EPD_2IN13_V2_SendCommand(0x3C); // BORDER_WAVEFORM_CONTROL
    EPD_2IN13_V2_SendData(0x03);                     
    EPD_2IN13_V2_SendCommand(0x11); // DATA_ENTRY_MODE_SETTING
    EPD_2IN13_V2_SendData(0x03);

    //set the look-up table register
    EPD_2IN13_V2_SendCommand(0x32); // WRITE_LUT_REGISTER
    if(Mode == EPD_2IN9_FULL){
        for (UWORD i = 0; i < 30; i++) {
                EPD_2IN13_V2_SendData(EPD_2IN9_lut_full_update[i]);
        }
    }else if(Mode == EPD_2IN9_PART){
        for (UWORD i = 0; i < 30; i++) {
                EPD_2IN13_V2_SendData(EPD_2IN9_lut_partial_update[i]);
        }
    }
}



static void EPD_2IN9_TurnOnDisplay(void)
{
    EPD_2IN13_V2_SendCommand(0x22); // DISPLAY_UPDATE_CONTROL_2
    EPD_2IN13_V2_SendData(0xC4);
    EPD_2IN13_V2_SendCommand(0x20); // MASTER_ACTIVATION
    EPD_2IN13_V2_SendCommand(0xFF); // TERMINATE_FRAME_READ_WRITE

    // EPD_2IN13_V2_ReadBusy();
}


/******************************************************************************
function :	Clear screen
parameter:
******************************************************************************/
void EPD_2IN9_Clear(void)
{
    UWORD Width, Height;
    Width = (EPD_2IN9_WIDTH % 8 == 0)? (EPD_2IN9_WIDTH / 8 ): (EPD_2IN9_WIDTH / 8 + 1);
    Height = EPD_2IN9_HEIGHT;
    EPD_2IN9_SetWindows(0, 0, EPD_2IN9_WIDTH, EPD_2IN9_HEIGHT);
    for (UWORD j = 0; j < Height; j++) {
        EPD_2IN9_SetCursor(0, j);
        EPD_2IN13_V2_SendCommand(0x24);
        for (UWORD i = 0; i < Width; i++) {
            EPD_2IN13_V2_SendData(0XFF);
        }
    }
    EPD_2IN9_TurnOnDisplay();
}

/******************************************************************************
function :	Sends the image buffer in RAM to e-Paper and displays
parameter:
******************************************************************************/
void EPD_2IN9_Display(UBYTE *Image)
{
    UWORD Width, Height;
    Width = (EPD_2IN9_WIDTH % 8 == 0)? (EPD_2IN9_WIDTH / 8 ): (EPD_2IN9_WIDTH / 8 + 1);
    Height = EPD_2IN9_HEIGHT;

    UDOUBLE Addr = 0;
    // UDOUBLE Offset = ImageName;
    EPD_2IN9_SetWindows(0, 0, EPD_2IN9_WIDTH, EPD_2IN9_HEIGHT);
    for (UWORD j = 0; j < Height; j++) {
        EPD_2IN9_SetCursor(0, j);
        EPD_2IN13_V2_SendCommand(0x24);
        for (UWORD i = 0; i < Width; i++) {
            Addr = i + j * Width;
            EPD_2IN13_V2_SendData(Image[Addr]);
        }
    }
    EPD_2IN9_TurnOnDisplay();
}

/******************************************************************************
function :	Enter sleep mode
parameter:
******************************************************************************/
void EPD_2IN9_Sleep(void)
{
    EPD_2IN13_V2_SendCommand(0x10);
    EPD_2IN13_V2_SendData(0x01);
    // EPD_2IN9_ReadBusy();
}