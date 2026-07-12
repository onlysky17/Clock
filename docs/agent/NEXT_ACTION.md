# NEXT_ACTION

Next task:
Port old Clock BLE/web protocol onto the working SDK 6.0.22 display base.

Start from:
firmware/active/HINK213_CLOCK_22_BASE

Do not modify EPD driver first. Display path is already proven working.

First future step:
1. Map old Clock BLE services/write handlers from SDK 6.0.18.
2. Map current HINK213_CLOCK_22_BASE BLE service layout.
3. Decide smallest protocol bridge.
4. Build verify before any flash burn.
