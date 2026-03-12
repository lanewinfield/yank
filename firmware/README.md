# ***Yank!*** Firmware

BLE firmware for the ***Yank!*** pull switch device, built on the Seeed XIAO nRF54L15 using the nRF Connect SDK (Zephyr RTOS).

## Hardware

| Component | Detail |
|-----------|--------|
| Board | Seeed XIAO nRF54L15 |
| MCU | Nordic nRF54L15, ARM Cortex-M33 |
| Pull Switch | Momentary, wired to **D3** (gpio1 pin 7) |
| Power | LiPo battery via XIAO battery connector |
| LED | On-board LED0 (gpio2 pin 0) used for status |

### Pin Assignments

| Pin | Function | GPIO | Config |
|-----|----------|------|--------|
| D3 | Pull switch input | gpio1.7 | Internal pull-up, active low |
| LED0 | Status indicator | gpio2.0 | Active low |

## BLE Protocol

### Device Name
The device advertises as **"Yank!"**

### Service: ***Yank!*** Pull Service

| Field | Value |
|-------|-------|
| Service UUID | `b26f59c7-68f1-48c8-a4d1-676648080123` |

### Characteristic: Pull Event

| Field | Value |
|-------|-------|
| UUID | `b26f59c7-68f1-48c8-a4d1-676648080124` |
| Properties | Notify only |
| Data format | 2 bytes: `[pull_count, elapsed_ds]` |

**Data format details:**

| Byte | Name | Description |
|------|------|-------------|
| 0 | `pull_count` | Monotonically increasing counter (1–255, wraps around, never 0). Use to detect missed events. |
| 1 | `elapsed_ds` | Deciseconds (tenths of a second) since the previous pull. 0 on first pull. Capped at 255 (25.5s). |

### Service: Battery (Standard BLE)

| Field | Value |
|-------|-------|
| Service UUID | `0x180F` (standard Battery Service) |
| Characteristic UUID | `0x2A19` (Battery Level) |
| Data format | 1 byte: 0–100 (percent) |

Battery level is measured every 5 minutes via the SAADC and reported through the standard BLE Battery Service.

### Advertising Data

The device advertises with:
- **Flags:** General Discoverable + BR/EDR Not Supported
- **Complete Local Name:** "Yank!"
- **Scan Response:** 128-bit Service UUID list containing `b26f59c7-68f1-48c8-a4d1-676648080123`

### Connection Parameters

| Parameter | Value |
|-----------|-------|
| Min interval | 7.5 ms (6 × 1.25 ms) |
| Max interval | 30 ms (24 × 1.25 ms) |
| Latency | 4 |
| Supervision timeout | 4000 ms |

These values balance responsiveness with power efficiency. The Mac app should accept these parameters.

## Reset Procedures

Since the device is fully enclosed with no access to the reset button, firmware resets are triggered via rapid successive pulls:

| Gesture | Action |
|---------|--------|
| **5 pulls within 2 seconds** | **Soft reset** — restarts the firmware (warm reboot) |
| **8 pulls within 3 seconds** | **Factory reset** — clears all bonding/pairing data, then cold reboots |

The LED provides visual feedback:
- **Soft reset:** 5 slow blinks (100ms on/off) before reboot
- **Factory reset:** 10 rapid blinks (50ms on/off) before reboot

## LED Indications

| Pattern | Meaning |
|---------|---------|
| 2 short blinks on startup | Firmware ready |
| 1 short blink | BLE connection established |
| 3 rapid blinks | BLE disconnected |
| 5 slow blinks | Soft reset in progress |
| 10 rapid blinks | Factory reset in progress |

## Building

### Prerequisites

- [nRF Connect SDK v2.9.0](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/nrf/installation.html) installed at `~/ncs`
- `west` meta-tool
- Zephyr SDK toolchain (arm-zephyr-eabi)

### Build Commands

```bash
cd firmware

# Set Zephyr base (if not already in environment)
export ZEPHYR_BASE=~/ncs/zephyr

# Build
west build -b xiao_nrf54l15/nrf54l15/cpuapp --build-dir build

# Clean rebuild
rm -rf build && west build -b xiao_nrf54l15/nrf54l15/cpuapp --build-dir build
```

The build output is at `build/firmware/zephyr/zephyr.hex` (merged output at `build/merged.hex`).

## Flashing

### Via USB (UF2 bootloader)

1. Connect XIAO nRF54L15 via USB
2. Double-press the reset button to enter UF2 bootloader mode
3. A USB drive named "XIAO-SENSE" will appear
4. Copy the UF2 file to the drive:

```bash
# Convert hex to UF2 if needed
python3 ~/ncs/zephyr/scripts/build/uf2conv.py build/firmware/zephyr/zephyr.hex -c -f 0x00000000 -o yank.uf2
cp yank.uf2 /Volumes/XIAO-SENSE/
```

### Via J-Link / SWD

```bash
west flash --build-dir build
```

### Via nrfjprog

```bash
nrfjprog --program build/merged.hex --sectorerase --verify --reset
```

## Full Device Reset (Mass Erase)

If the device gets into a bad state (e.g. `bt_enable()` hangs and BLE never starts), a mass erase via the CTRL-AP will wipe all flash and RRAM and fully reset the SoC — the closest thing to a power cycle without removing the battery.

```bash
openocd \
  -f ~/ncs/zephyr/boards/seeed/xiao_nrf54l15/support/openocd.cfg \
  -c "init; nrf54l_mass_erase; shutdown"
```

After the erase, reflash the firmware:

```bash
west flash -d /path/to/firmware/build/firmware
```

## Debugging (RTT Console)

The XIAO nRF54L15's USB port is a CMSIS-DAP debug probe only — UART is not routed through USB. To view console output, use Segger RTT (Real-Time Transfer) which reads directly through the debug probe.

### 1. Enable RTT in `prj.conf`

Change the serial/console section to:

```
CONFIG_SERIAL=n
CONFIG_CONSOLE=y
CONFIG_UART_CONSOLE=n
CONFIG_USE_SEGGER_RTT=y
CONFIG_RTT_CONSOLE=y
```

### 2. Rebuild and flash

```bash
cd ~/ncs
west build -b xiao_nrf54l15/nrf54l15/cpuapp /path/to/firmware --build-dir /path/to/firmware/build --pristine
west flash -d /path/to/firmware/build/firmware
```

Note: `west flash` needs the `build/firmware` subdirectory (not just `build`) due to the sysbuild structure.

### 3. Read RTT output via OpenOCD

```bash
# Start OpenOCD with RTT server
openocd \
  -f /path/to/ncs/zephyr/boards/seeed/xiao_nrf54l15/support/openocd.cfg \
  -c "init; rtt setup 0x20000000 0x10000 \"SEGGER RTT\"; rtt start; rtt server start 9090 0"

# In another terminal, connect to the RTT stream
nc localhost 9090
```

To reset the device while reading RTT, connect to the OpenOCD telnet interface and issue a reset:

```bash
# In a third terminal
nc localhost 4444
> reset run
```

### 4. Revert to production mode

Change `prj.conf` back to disable serial/RTT for battery savings (~1-2mA):

```
CONFIG_SERIAL=n
CONFIG_CONSOLE=n
CONFIG_UART_CONSOLE=n
```

Rebuild and flash again.

## Behavior

### Normal Operation
1. On power-up, firmware initializes BLE and begins advertising as "Yank!"
2. The Mac companion app discovers and connects to the device
3. Each pull of the switch sends a BLE notification to the connected app
4. When idle, the MCU enters low-power sleep automatically (Zephyr PM)

### Disconnected Behavior
- When the BLE connection drops, the device automatically restarts advertising
- A single pull while disconnected also triggers advertising for reconnection
- The device remembers bonded devices and will reconnect automatically

### Power Management
- Zephyr's built-in power management puts the CPU to sleep between events
- GPIO interrupt wakes the CPU instantly on pull switch activation
- BLE connection is maintained during sleep via the SoftDevice controller
- Battery level is measured every 5 minutes
