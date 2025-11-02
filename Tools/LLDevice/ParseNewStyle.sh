#!/bin/bash

# Usage: cat header.h | ./parse_bitfields.sh FULL_REGISTER_NAME

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 FULL_REGISTER_NAME" >&2
    exit 1
fi

FULL_REGISTER_NAME="$1"
mapfile -t FILE_LINES

# Function to count number of set bits in a number
count_bits() {
    local n=$1
    local count=0
    while (( n )); do
        (( count += n & 1 ))
        (( n >>= 1 ))
    done
    echo "$count"
}

# Regex patterns
MASK_PATTERN="^#define[[:space:]]*$FULL_REGISTER_NAME"_'([A-Z][A-Z0-9]*)_Msk[[:space:]]'
POS_PATTERN_TEMPLATE='^#define[[:space:]]*%s_Pos[[:space:]]*\(([0-9]+)U\)'
MASK_VALUE_PATTERN='\(0x([0-9A-Fa-f]+)UL'

# Collect bitfield records
for LINE in "${FILE_LINES[@]}"; do
    if [[ "$LINE" =~ $MASK_PATTERN ]]; then
        FIELD_NAME="${BASH_REMATCH[1]}"
        FULL_FIELD_NAME="${FULL_REGISTER_NAME}_${FIELD_NAME}"

        # Find position line
        POS_PATTERN=$(printf "$POS_PATTERN_TEMPLATE" "$FULL_FIELD_NAME")
        POS_LINE=$(printf "%s\n" "${FILE_LINES[@]}" | grep -E "$POS_PATTERN" || true)
        if [[ $(echo "$POS_LINE" | wc -l) -ne 1 ]]; then continue; fi
        if [[ "$POS_LINE" =~ \(([0-9]+)U\) ]]; then
            POS="${BASH_REMATCH[1]}"
        else
            continue
        fi

        # Extract mask value
        if [[ "$LINE" =~ $MASK_VALUE_PATTERN ]]; then
            MASK_HEX="${BASH_REMATCH[1]}"
            if [[ "$MASK_HEX" =~ ^[0-9A-Fa-f]+$ ]]; then
                MASK_DEC=$((16#$MASK_HEX))
                FIELD_SIZE=$(count_bits "$MASK_DEC")
            else
                continue
            fi
        else
            continue
        fi

        # Extract comment
        COMMENT=""
        FULL_FIELD_DEFINE_LINE=$(printf "%s\n" "${FILE_LINES[@]}" | grep -E "^#define[[:space:]]*$FULL_FIELD_NAME[[:space:]]" || true)

        # Try /*!< comment
        COMMENT=$(echo "$FULL_FIELD_DEFINE_LINE" | grep -Po '/\*!<\K[^*]+(?=\*/)' | sed 's/[[:space:]]*$//' || true)

        # If not found, try /* comment
        if [[ -z "$COMMENT" ]]; then
            COMMENT=$(echo "$FULL_FIELD_DEFINE_LINE" | grep -Po '/\*\K[^*]+(?=\*/)' | sed 's/[[:space:]]*$//' || true)
        fi

        # Output JSON object
        jq -n \
            --arg name "$FIELD_NAME" \
            --argjson pos "$POS" \
            --argjson size "$FIELD_SIZE" \
            --arg comment "$COMMENT" \
            '{Name: $name, Pos: $pos, FieldSize: $size, Comment: $comment}'
    fi
done | jq -s '.'
