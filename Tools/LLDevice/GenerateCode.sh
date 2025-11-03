#!/bin/bash

# Usage:
#   ./GenerateCode.sh < extended.json

set -euo pipefail

# Read input JSON
INPUT_JSON=$(cat)

# Extract device name from JSON
DEVICE_NAME=$(echo "$INPUT_JSON" | jq -r '.Device')

if [[ -z "$DEVICE_NAME" || "$DEVICE_NAME" == "null" ]]; then
    echo "Error: Device name not found in input JSON." >&2
    exit 1
fi

CURRENT_DATE=$(date +"%B %d, %Y")
STRUCT_NAME="${DEVICE_NAME}_Type"

# Header
cat <<EOF
/**
 ******************************************************************************
 * @author  Gyorgy Varga
 * @brief   STM32 Low-Layer register definitions for ${DEVICE_NAME} peripheral.
 *
 * @copyright Gyorgy Varga - All Rights Reserved.
 *            Unauthorised copying of this file, via any medium is strictly prohibited.
 *            Proprietary and confidential.
 * @date    ${CURRENT_DATE}
 *
 * @par Generated
 *        This file was automatically generated.
 *
 ******************************************************************************
 */
#pragma once

#include <cstddef>
#include <cstdint>
#include <stddef.h>
#include "RegisterAccess.hpp"

// --------------------------------------------------------------------------

namespace LL
{
    /**
     * @brief LL register definition of ${DEVICE_NAME}
     *
     * Base template is parameterized by the peripheral's base memory address.
     *
     * @tparam baseAddress The memory address of the ${DEVICE_NAME} peripheral instance.
     */
    template <uintptr_t baseAddress>
    class ${DEVICE_NAME}_Registers
    {
    public:
EOF

# Generate register classes
echo "$INPUT_JSON" | jq -c '.Registers[]' | while read -r REGISTER; do
    REG_NAME=$(echo "$REGISTER" | jq -r '.Name')
    REG_TYPE=$(echo "$REGISTER" | jq -r '.Type')
    BITTABLE=$(echo "$REGISTER" | jq -c '.BitTable')

    echo "        /** @brief ${REG_NAME} register */"

    FIELD_COUNT=$(echo "$BITTABLE" | jq 'length')
    HANDLED=false

    if [[ "$FIELD_COUNT" -eq 1 ]]; then
        FIELD_SIZE=$(echo "$BITTABLE" | jq -r '.[0].FieldSize')
        TYPE_SIZE=16  # Replace with dynamic size detection if needed

        if [[ "$FIELD_SIZE" -eq "$TYPE_SIZE" ]]; then
            echo "        using ${REG_NAME} = ReadWriteRegister<${REG_TYPE}, baseAddress + offsetof(${STRUCT_NAME}, ${REG_NAME})>;"
            HANDLED=true
        fi
    fi

    if [[ "$HANDLED" != "true" ]]; then
        echo "        struct ${REG_NAME} : public ReadWriteRegister<${REG_TYPE}, baseAddress + offsetof(${STRUCT_NAME}, ${REG_NAME})>"
        echo "        {"

        # First pass: collect lines and measure max code length
        MAXLEN=0
        CODE_LINES=()
        while IFS= read -r BIT; do
            BIT_NAME=$(echo "$BIT" | jq -r '.Name')
            BIT_POS=$(echo "$BIT" | jq -r '.Pos')
            BIT_SIZE=$(echo "$BIT" | jq -r '.FieldSize')
            BIT_COMMENT=$(echo "$BIT" | jq -r '.Comment')

            if [[ "$BIT_SIZE" -eq 1 ]]; then
                CODE="using ${BIT_NAME} = typename ${REG_NAME}::Bit<${BIT_POS}>;"
            else
                CODE="using ${BIT_NAME} = typename ${REG_NAME}::BitField<${BIT_POS}, ${BIT_SIZE}>;"
            fi

            CODE_LINES+=("$CODE|$BIT_COMMENT")

            LEN=${#CODE}
            if (( LEN > MAXLEN )); then
                MAXLEN=$LEN
            fi
        done < <(echo "$BITTABLE" | jq -c '.[]')

        # Second pass: print aligned lines
        for ENTRY in "${CODE_LINES[@]}"; do
            CODE="${ENTRY%%|*}"
            COMMENT="${ENTRY#*|}"
            printf "            %-*s // %s\n" "$MAXLEN" "$CODE" "$COMMENT"
        done

        echo "        };"
    fi

    echo ""
done

# Footer
cat <<EOF
    }; // class ${DEVICE_NAME}_Registers

} // namespace LL
EOF
