#!/bin/bash

# Usage:
#   ./ScanAllRegisters --input-file header.h < input.json

set -euo pipefail

# Parse arguments using getopt
PARSED=$(getopt --options="" --longoptions="input-file:" --name "$0" -- "$@")
eval set -- "$PARSED"

INPUT_FILE=""

while true; do
    case "$1" in
        --input-file)
            INPUT_FILE="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unexpected option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$INPUT_FILE" ]]; then
    echo "Error: --input-file is required." >&2
    exit 1
fi

INPUT_JSON=$(cat)

# Extract device name from input JSON
DEVICE_NAME=$(echo "$INPUT_JSON" | jq -r '.Device')

# Process each register
REGISTER_OUTPUT=$(echo "$INPUT_JSON" | jq -c '.Registers[]' | while read -r ITEM; do
    NAME=$(echo "$ITEM" | jq -r '.Name')
    NAME_WITH_SUFFIX="${DEVICE_NAME}_${NAME}"

    # Try ParseOldStyle.sh first
    BITTABLE=$(grep "$NAME_WITH_SUFFIX" "$INPUT_FILE" | ./ParseOldStyle.sh "$NAME_WITH_SUFFIX")

    # If result is empty, fall back to ParseNewStyle.sh
    if [[ -z "$BITTABLE" || "$BITTABLE" == "[]" ]]; then
        # echo Old style
        BITTABLE=$(grep "$NAME_WITH_SUFFIX" "$INPUT_FILE" | ./ParseNewStyle.sh "$NAME_WITH_SUFFIX")
    fi

    # Merge original item with BitTable array
    echo "$ITEM" | jq --argjson table "$BITTABLE" '. + {BitTable: $table}'
done | jq -s '.')

# Combine final output
jq -n --arg device "$DEVICE_NAME" --argjson registers "$REGISTER_OUTPUT" \
    '{Device: $device, Registers: $registers}'
