/**
 ****************************************************************************************
 *
 * @file fpga.h
 *
 * @brief FPGA header file.
 *
 * Copyright (C) 2022 Dialog Semiconductor.
 * This computer program includes Confidential, Proprietary Information
 * of Dialog Semiconductor. All Rights Reserved.
 *
 ****************************************************************************************
 */

#ifndef _FPGA_H_
#define _FPGA_H_

/*
 * INCLUDE FILES
 ****************************************************************************************
 */

#include <stdint.h>

/*
 * TYPE DEFINITIONS
 ****************************************************************************************
 */

typedef enum
{
    FPGA_GPIO_MAP_1 = 0UL,
    FPGA_GPIO_MAP_2 = 1UL,
    FPGA_GPIO_MAP_3 = 2UL,
    FPGA_GPIO_MAP_4 = 3UL,
    FPGA_GPIO_MAP_ERROR,
} FPGA_GPIO_MAP_t;

/*
 * FUNCTION DECLARATIONS
 ****************************************************************************************
 */

void fpga_helper(FPGA_GPIO_MAP_t map, uint8_t debug);

#endif // _FPGA_H_
