/**
 ****************************************************************************************
 *
 * @file IAR/boot.h
 *
 * @brief Declarations of the linker-defined symbols for IAR C compiler (iccarm).
 *
 * Copyright (C) 2019-2022 Dialog Semiconductor.
 * This computer program includes Confidential, Proprietary Information
 * of Dialog Semiconductor. All Rights Reserved.
 *
 ****************************************************************************************
 */

#ifndef _BOOT_H_
#define _BOOT_H_

#include <stdint.h>

extern const uint32_t __ER_IROM3_BASE__[];
#define CODE_AREA_BASE      ((uint32_t)__ER_IROM3_BASE__)

extern const uint32_t __ER_IROM3_LENGTH__[];
#define CODE_AREA_LENGTH    ((uint32_t)__ER_IROM3_LENGTH__)

#pragma section = ".retention_mem_area_uninit"
#define RET_MEM_BASE        (*(uint32_t*)(__section_begin(".retention_mem_area_uninit")))

#pragma section = ".heap_mem_area_not_ret"
#define NON_RET_HEAP_BASE   (*(uint32_t*)(__section_begin(".heap_mem_area_not_ret")))

#define NON_RET_HEAP_END    (*(uint32_t*)(__section_end(".heap_mem_area_not_ret")))

#define NON_RET_HEAP_LENGTH (NON_RET_HEAP_END - NON_RET_HEAP_BASE)

#pragma section = ".heap_db_area"
#define DB_HEAP_BASE        (*(uint32_t*)(__section_begin(".heap_db_area")))

#define DB_HEAP_END         (*(uint32_t*)(__section_end(".heap_db_area")))

#define DB_HEAP_LENGTH (DB_HEAP_END - DB_HEAP_BASE)

#endif // _BOOT_H_
