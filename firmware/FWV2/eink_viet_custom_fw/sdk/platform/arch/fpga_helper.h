/**
 ****************************************************************************************
 *
 * @file fpga_helper.h
 *
 * @brief FPGA helper functions header file.
 *
 * Copyright (C) 2022 Dialog Semiconductor.
 * This computer program includes Confidential, Proprietary Information
 * of Dialog Semiconductor. All Rights Reserved.
 *
 ****************************************************************************************
 */

#ifndef _FPGA_HELPER_H_
#define _FPGA_HELPER_H_

/*
 * INCLUDE FILES
 ****************************************************************************************
 */

#include "fpga.h"

/*
 * MACROS
 ****************************************************************************************
 */

#ifdef __FPGA__
#define FPGA_HELPER(map, debug)     fpga_helper(map, debug)
#else
#define FPGA_HELPER(map, debug)
#endif // __FPGA__

#endif // _FPGA_HELPER_H_
