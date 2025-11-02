#!/bin/bash

# Usage:
#   ./extend_with_ParseNewStyle.sh --input-file header.h --device-name SPI1 < input.json

set -euo pipefail

# Parse arguments using getopt
PARSED=$(getopt --options="" --longoptions="input-file:,device-name:" --name "$0" -- "$@")
eval set -- "$PARSED"

INPUT_FILE=""
DEVICE_NAME=""

while true; do
    case "$1" in
        --input-file)
            INPUT_FILE="$2"
            shift 2
            ;;
        --device-name)
            DEVICE_NAME="$2"
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

# Process each element and extend with ParseNewStyle.sh output
echo "$INPUT_JSON" | jq -c '.[]' | while read -r ITEM; do
    NAME=$(echo "$ITEM" | jq -r '.Name')
    NAME_WITH_SUFFIX="${DEVICE_NAME}_${NAME}"

    # Try ParseOldStyle.sh first
    BITTABLE=$(cat "$INPUT_FILE" | grep $NAME_WITH_SUFFIX | ./ParseOldStyle.sh "$NAME_WITH_SUFFIX")

    # If result is empty, fall back to ParseNewStyle.sh
    if [[ -z "$BITTABLE" || "$BITTABLE" == "[]" ]]; then
        BITTABLE=$(cat "$INPUT_FILE" | grep $NAME_WITH_SUFFIX | ./ParseNewStyle.sh "$NAME_WITH_SUFFIX")
    fi
    # Merge original item with BitTable array
    echo "$ITEM" | jq --argjson table "$BITTABLE" '. + {BitTable: $table}'
done | jq -s '.'
