#!/bin/bash

# Usage: cat header.h | ./ParseStruct.sh DEVICE_NAME

DEVICE_NAME="$1"
STRUCT_NAME="${DEVICE_NAME}_TypeDef"

# Read piped input into an array
mapfile -t FILE_LINES

# Find start and end of struct
START_LINE=-1
END_LINE=-1

for i in "${!FILE_LINES[@]}"; do
    if [[ "${FILE_LINES[$i]}" =~ typedef[[:space:]]+struct ]]; then
        START_LINE=$i
    fi
    if [[ $START_LINE -ge 0 && "${FILE_LINES[$i]}" =~ }\ *${STRUCT_NAME}[[:space:]]*\; ]]; then
        END_LINE=$i
        break
    fi
done

if [[ $START_LINE -lt 0 || $END_LINE -lt 0 ]]; then
    echo "Error: Struct '$STRUCT_NAME' not found." >&2
    exit 1
fi

# Extract struct body
STRUCT_BODY=("${FILE_LINES[@]:$((START_LINE + 1)):$((END_LINE - START_LINE - 1))}")

# Regex to match register lines
REGEX='^[[:space:]]*((__IO|__I|__O|volatile|[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+)*)(uint(16|32)_t|u(16|32))[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*;'

# Collect register entries into a temporary array
REGISTERS=()
for LINE in "${STRUCT_BODY[@]}"; do
    if [[ "$LINE" =~ $REGEX ]]; then
        REG_NAME="${BASH_REMATCH[6]}"
        REG_TYPE="${BASH_REMATCH[3]}"
        if [[ ! "$REG_NAME" =~ ^RESERVED[0-9]*$ ]]; then
            REGISTERS+=("$(jq -n --arg name "$REG_NAME" --arg type "$REG_TYPE" '{Name: $name, Type: $type}')")
        fi
    fi
done

# Combine into final JSON structure
jq -n --arg device "$DEVICE_NAME" --argjson registers "$(printf '%s\n' "${REGISTERS[@]}" | jq -s .)" \
    '{Device: $device, Registers: $registers}'