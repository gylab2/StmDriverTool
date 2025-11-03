#!/bin/bash

# Usage: cat header.h | ./parse_mask_fields.sh FULL_REGISTER_NAME

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 FULL_REGISTER_NAME" >&2
    exit 1
fi

FULL_REGISTER_NAME="$1"
mapfile -t FILE_LINES

# Function to count set bits
count_bits() {
    local n=$1 count=0
    while (( n )); do
        (( count += n & 1 ))
        (( n >>= 1 ))
    done
    echo "$count"
}

# Function to find least significant bit position
lsb_position() {
    local n=$1 pos=0
    while (( (n & 1) == 0 && n != 0 )); do
        (( n >>= 1 ))
        (( pos++ ))
    done
    echo "$pos"
}

# Regex to match lines like:
# #define SPI_CR2_RXDMAEN ((uint8_t)0x01) /*!< Rx Buffer DMA Enable */
REGEX='^#define[[:space:]]+('"$FULL_REGISTER_NAME"'_([A-Z0-9_]+))[[:space:]]+\(\(uint(8|16|32)_t\)\s*0x([0-9A-Fa-f]+)\)[[:space:]]*/\*!<(.*)\*/'

for LINE in "${FILE_LINES[@]}"; do
    if [[ "$LINE" =~ $REGEX ]]; then
        FIELD_NAME="${BASH_REMATCH[2]}"
        MASK_HEX="${BASH_REMATCH[4]}"
        COMMENT="${BASH_REMATCH[5]}"

        MASK_DEC=$((16#$MASK_HEX))
        POS=$(lsb_position "$MASK_DEC")
        SIZE=$(count_bits "$MASK_DEC")

        jq -n \
            --arg name "$FIELD_NAME" \
            --argjson pos "$POS" \
            --argjson size "$SIZE" \
            --arg comment "$COMMENT" \
            '{Name: $name, Pos: $pos, FieldSize: $size, Comment: $comment}'
    fi
done | jq -s '.'
