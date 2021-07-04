#!/bin/bash

cleanup() {
    echo "cleanup ..."
    rm "$KEYFILE"
}

# Directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Defaults: Serial port to access the ESP32
PORT=/dev/cu.SLAB_USBtoUART

# Defaults: Fast baud rate
BAUDRATE=115200

# Parameter parsing
while [[ $# -gt 0 ]]; do
    KEY="$1"
    case "$KEY" in
        -p|--port)
            PORT="$2"
            shift
            shift
        ;;
        -s|--slow)
            BAUDRATE=115200
            shift
        ;;
        -h|--help)
            echo "flash_esp32.sh - Flash the OpenHaystack firmware onto an ESP32 module"
            echo ""
            echo "  This script will create a virtual environment for the required tools."
            echo ""
            echo "Call: flash_esp32.sh [-p <port>] [-v <dir>] [-s] PUBKEY"
            echo ""
            echo "Required Arguments:"
            echo "  PUBKEY"
            echo "      The base64-encoded public key"
            echo ""
            echo "Optional Arguments:"
            echo "  -h, --help"
            echo "      Show this message and exit."
            echo "  -p, --port <port>"
            echo "      Specify the serial interface to which the device is connected."
            echo "  -s, --slow"
            echo "      Use 115200 instead of 921600 baud when flashing."
            echo "      Might be required for long/bad USB cables or slow USB-to-Serial converters."
            echo "  -v, --venvdir <dir>"
            echo "      Select Python virtual environment with esptool installed."
            echo "      If the directory does not exist, it will be created."
            exit 1
        ;;
        *)
            if [[ -z "$PUBKEY" ]]; then
                PUBKEY="$1"
                shift
            else
                echo "Got unexpected parameter $1"
                exit 1
            fi
        ;;
    esac
done

# Sanity check: Pubkey exists
if [[ -z "$PUBKEY" ]]; then
    echo "Missing public key, call with --help for usage"
    exit 1
fi

# Sanity check: Port
if [[ ! -e "$PORT" ]]; then
    echo "$PORT does not exist, please specify a valid serial interface with the -p argument"
    exit 1
fi

# Prepare the key
KEYFILE="$SCRIPT_DIR/tmp.key"
if [[ -f "$KEYFILE" ]]; then
    echo "$KEYFILE already exists, stopping here not to override files..."
    exit 1
fi
echo "$PUBKEY" | python -m base64 -d - > "$KEYFILE"
if [[ $? != 0 ]]; then
    echo "Could not parse the public key. Please provide valid base64 input"
    exit 1
fi

# Call esptool.py. Errors from here on are critical
set -e
trap cleanup INT TERM EXIT

# Clear NVM
esptool.py --after no_reset --port "$PORT" \
    erase_region 0x9000 0x5000
esptool.py --before no_reset --baud $BAUDRATE --port "$PORT" \
    write_flash 0x1000  "$SCRIPT_DIR/build/bootloader/bootloader.bin" \
                0x8000  "$SCRIPT_DIR/build/partition_table/partition-table.bin" \
                0xe000  "$KEYFILE" \
                0x10000 "$SCRIPT_DIR/build/openhaystack.bin"
