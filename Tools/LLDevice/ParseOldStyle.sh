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

# Regex patterns
MASK_PATTERN="^#define[[:space:]]*$FULL_REGISTER_NAME"_'([A-Z][A-Z0-9]*)[[:space:]]'
MASK_LINE_PATTERN='\(uint(16|32)_t\)0x([0-9A-F]+)\)[[:space:]]*/\*!<(.*)\*/'

# Collect bitfield records
for LINE in "${FILE_LINES[@]}"; do
    if [[ "$LINE" =~ $MASK_PATTERN ]]; then
        FIELD_NAME="${BASH_REMATCH[1]}"
        FULL_FIELD_NAME="${FULL_REGISTER_NAME}_${FIELD_NAME}"

        # Find full mask line
        MATCH_LINE=$(printf "%s\n" "${FILE_LINES[@]}" | grep -E "^#define[[:space:]]*$FULL_FIELD_NAME[[:space:]].*\(uint(16|32)_t\)0x[0-9A-F]+\)[[:space:]]*/\*!<.*\*/" || true)
        if [[ "$MATCH_LINE" =~ $MASK_LINE_PATTERN ]]; then
            MASK_HEX="${BASH_REMATCH[2]}"
            COMMENT="${BASH_REMATCH[3]}"

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
    fi
done | jq -s '.'
