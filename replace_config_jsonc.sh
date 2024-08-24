#!/bin/bash

# Define the target file path
CONFIG_FILE="$HOME/.config/fastfetch/config.jsonc"

# Define the new JSON content
NEW_CONFIG_CONTENT='{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "builtin",
        "color": {
            "1": "white",
            "2": "cyan"
        }
    },
    "display": {
        "separator": "   ",
        "color": "cyan"
    },
    "modules": [
        {
            "type": "custom",
            "format": "┌─────────── \u001b[1mHardware Information\u001b[0m ───────────┐"
        },
        {
            "type": "host",
            "key": "  󰌢"
        },
        {
            "type": "cpu",
            "key": "  "
        },
        {
            "type": "gpu",
            "detectionMethod": "pci",
            "key": "  "
        },
        {
            "type": "display",
            "key": "  󱄄"
        },
        {
            "type": "memory",
            "key": "  "
        },
        {
            "type": "disk",
            "key": "  "
        },
        {
            "type": "battery",
            "key": "  "
        },
        {
            "type": "custom",
            "format": "├─────────── \u001b[1mSoftware Information\u001b[0m ───────────┤"
        },
        {
            "type": "os",
            "key": "  "
        },
        {
            "type": "kernel",
            "key": "  ",
            "format": "{1} {2}"
        },
        // {
        //     "type": "wm",
        //     "key": "  "
        // },
        {
            "type": "shell",
            "key": "  "
        },
        {
            "type": "processes",
            "key": "  󰧑"
        },
        {
            "type": "packages",
            "key": "  "
        },
        {
            "type": "custom",
            "format": "|──────────────\u001b[1mMiscellaneous\u001b[0m──────────────────|"
        },
        {
            "type": "datetime",
            "key": "  "
        },
        {
            "type": "localip",
            "showIpv6": false,
            "showMac": false,
            "key": "  󰩠"
        },
        {
            "type": "weather",
            "timeout": 1000,
            "key": "  "
        },
        {
            "type": "custom",
            "format": "|──────────────\u001b[1mUptime / Age\u001b[0m──────────────────|"
        },
        {
            "type": "command",
            "key": "  OS Age ",
            "keyColor": "magenta",
            "text": "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days"
        },
        {
            "type": "uptime",
            "key": "  Uptime ",
            "keyColor": "magenta"
        },
        {
            "type": "custom",
            "format": "└────────────────────────────────────────────┘"
        },
        {
            "type": "colors",
            "paddingLeft": 2,
            "symbol": "circle"
        }
    ]
}'

# Create the directory if it doesn't exist
mkdir -p "$(dirname "$CONFIG_FILE")"

# Replace the contents of the config.jsonc file with the new content
echo "$NEW_CONFIG_CONTENT" > "$CONFIG_FILE"

echo "Configuration file updated successfully at $CONFIG_FILE"
