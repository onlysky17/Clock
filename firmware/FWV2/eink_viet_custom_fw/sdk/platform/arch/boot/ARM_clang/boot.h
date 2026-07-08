/**
 ****************************************************************************************
 *
 * @file ARM_clang/boot.h
 *
 * @brief Declarations of the linker-defined symbols for ARM v6 C compiler (armclang).
 *
 * Copyright (C) 2022 Dialog Semiconductor.
 * This computer program includes Confidential, Proprietary Information
 * of Dialog Semiconductor. All Rights Reserved.
 *
 ****************************************************************************************
 */

#ifndef _BOOT_H_
#define _BOOT_H_

#include <stdint.h>

extern int Image$$ER_IROM3$$Base;
#define CODE_AREA_BASE      (uintptr_t)&Image$$ER_IROM3$$Base

extern int Image$$ER_IROM3$$Length;
#define CODE_AREA_LENGTH    (uintptr_t)&Image$$ER_IROM3$$Length

extern int Image$$RET_DATA_UNINIT$$Base;
#define RET_MEM_BASE        (uintptr_t)&Image$$RET_DATA_UNINIT$$Base

extern int Image$$ER_NZI$$Base;
#define NON_RET_HEAP_BASE   (uintptr_t)&Image$$ER_NZI$$Base

extern int Image$$ER_NZI$$Length;
#define NON_RET_HEAP_LENGTH (uintptr_t)&Image$$ER_NZI$$Length

extern int Image$$RET_HEAP_DB$$Base;
#define DB_HEAP_BASE   (uintptr_t)&Image$$RET_HEAP_DB$$Base

extern int Image$$RET_HEAP_DB$$Length;
#define DB_HEAP_LENGTH (uintptr_t)&Image$$RET_HEAP_DB$$Length


#endif // _BOOT_H_
