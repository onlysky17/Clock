/**
 ****************************************************************************************
 *
 * @file boot.h
 *
 * @brief Declarations of the linker-defined symbols for various ARM C compilers.
 *
 * Copyright (C) 2018-2022 Dialog Semiconductor.
 * This computer program includes Confidential, Proprietary Information
 * of Dialog Semiconductor. All Rights Reserved.
 *
 ****************************************************************************************
 */

/*
 * Arm Compiler 4/5
 */
#if   defined ( __CC_ARM )
    #include "ARM/boot.h"

/*
 * Arm Compiler above 6.10.1 (armclang)
 */
#elif defined (__ARMCC_VERSION) && (__ARMCC_VERSION >= 6100100)
    #include "ARM_clang/boot.h"

/*
 * GNU Compiler
 */
#elif defined ( __GNUC__ )
    #include "GCC/boot.h"

/*
 * IAR Compiler
 */
#elif defined ( __ICCARM__)
    #include "IAR/boot.h"
#endif
