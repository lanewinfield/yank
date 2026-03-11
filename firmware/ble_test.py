#!/usr/bin/env python3
"""
Yank! BLE Integration Test Script

Connects to the Yank! device, subscribes to pull notifications,
reads battery level, and triggers test pulls via the test trigger
characteristic.
"""

import asyncio
import sys
from bleak import BleakClient, BleakScanner

DEVICE_ADDRESS = None  # Set to your device's BLE MAC address, or leave None to scan by name
DEVICE_NAME = "Yank!"

# UUIDs
YANK_SERVICE_UUID = "b26f59c7-68f1-48c8-a4d1-676648080123"
PULL_EVENT_UUID = "b26f59c7-68f1-48c8-a4d1-676648080124"
TEST_TRIGGER_UUID = "b26f59c7-68f1-48c8-a4d1-676648080125"
BATTERY_LEVEL_UUID = "00002a19-0000-1000-8000-00805f9b34fb"

pull_events_received = []


def notification_handler(sender, data: bytearray):
    pull_count = data[0]
    elapsed_ds = data[1] if len(data) > 1 else 0
    pull_events_received.append((pull_count, elapsed_ds))
    print(f"  [PULL EVENT] count={pull_count}, elapsed={elapsed_ds} deciseconds ({elapsed_ds * 100}ms)")


async def run_test():
    print(f"=== Yank! BLE Integration Test ===\n")

    # Step 1: Scan for the device
    print("[1] Scanning for Yank! device...")
    device = await BleakScanner.find_device_by_address(DEVICE_ADDRESS, timeout=10.0)
    if not device:
        # Try by name
        device = await BleakScanner.find_device_by_name(DEVICE_NAME, timeout=10.0)
    if not device:
        print("  FAIL: Device not found")
        return False

    print(f"  OK: Found {device.name} at {device.address} (RSSI: {device.rssi})")

    # Step 2: Connect
    print("\n[2] Connecting...")
    async with BleakClient(device, timeout=15.0) as client:
        print(f"  OK: Connected (MTU: {client.mtu_size})")

        # Step 3: Discover services
        print("\n[3] Discovering services...")
        yank_service_found = False
        pull_char_found = False
        test_trigger_found = False
        battery_char_found = False

        for service in client.services:
            if service.uuid == YANK_SERVICE_UUID:
                yank_service_found = True
                print(f"  OK: Yank! service found ({service.uuid})")
                for char in service.characteristics:
                    print(f"    Characteristic: {char.uuid} [{', '.join(char.properties)}]")
                    if char.uuid == PULL_EVENT_UUID:
                        pull_char_found = True
                    if char.uuid == TEST_TRIGGER_UUID:
                        test_trigger_found = True
            if BATTERY_LEVEL_UUID in [c.uuid for c in service.characteristics]:
                battery_char_found = True

        if not yank_service_found:
            print("  FAIL: Yank! service not found")
            return False

        # Step 4: Read battery level
        print("\n[4] Reading battery level...")
        if battery_char_found:
            battery_data = await client.read_gatt_char(BATTERY_LEVEL_UUID)
            battery_level = battery_data[0]
            print(f"  OK: Battery level = {battery_level}%")
        else:
            print("  SKIP: Battery characteristic not found")

        # Step 5: Subscribe to pull notifications
        print("\n[5] Subscribing to pull event notifications...")
        if not pull_char_found:
            print("  FAIL: Pull event characteristic not found")
            return False

        await client.start_notify(PULL_EVENT_UUID, notification_handler)
        print("  OK: Subscribed to pull notifications")

        # Step 6: Trigger test pulls
        print("\n[6] Triggering test pulls via test characteristic...")
        if not test_trigger_found:
            print("  WARN: Test trigger characteristic not found")
            print("  Waiting 30s for manual pulls instead...")
            await asyncio.sleep(30)
        else:
            num_test_pulls = 3
            for i in range(num_test_pulls):
                print(f"  Sending test pull {i + 1}/{num_test_pulls}...")
                await client.write_gatt_char(TEST_TRIGGER_UUID, b"\x01", response=False)
                await asyncio.sleep(1.0)

            # Wait for notifications to arrive
            await asyncio.sleep(1.0)

        # Step 7: Verify results
        print(f"\n[7] Results:")
        print(f"  Pull events received: {len(pull_events_received)}")
        for i, (count, elapsed) in enumerate(pull_events_received):
            print(f"    Event {i + 1}: pull_count={count}, elapsed_ds={elapsed}")

        # Stop notifications
        await client.stop_notify(PULL_EVENT_UUID)

        # Summary
        print(f"\n=== Test Summary ===")
        results = {
            "Device found": True,
            "BLE connection": True,
            "Yank! service": yank_service_found,
            "Pull event char": pull_char_found,
            "Test trigger char": test_trigger_found,
            "Battery level": battery_char_found,
            "Pull notifications": len(pull_events_received) > 0,
        }

        all_pass = True
        for test, passed in results.items():
            status = "PASS" if passed else "FAIL"
            if not passed:
                all_pass = False
            print(f"  [{status}] {test}")

        if test_trigger_found and len(pull_events_received) > 0:
            expected = num_test_pulls
            actual = len(pull_events_received)
            match = "PASS" if actual == expected else "FAIL"
            if actual != expected:
                all_pass = False
            print(f"  [{match}] Expected {expected} pulls, got {actual}")

        print(f"\n{'ALL TESTS PASSED' if all_pass else 'SOME TESTS FAILED'}")
        return all_pass


if __name__ == "__main__":
    success = asyncio.run(run_test())
    sys.exit(0 if success else 1)
