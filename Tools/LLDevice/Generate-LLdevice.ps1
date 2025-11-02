<#
.SYNOPSIS
Converts an STM32 peripheral C struct (e.g., USART_TypeDef) into a C++20 Low-Layer register map header.

.DESCRIPTION
Reads an STM32 header file specified by SourceFile, searches for a specified peripheral struct, 
and generates a C++ header with register access classes (LL namespace).

.PARAMETER DeviceName
The name of the peripheral (e.g., 'USART', 'SPI', 'TIM').

.PARAMETER SourceFile
The path to the STM32 header file (e.g., 'stm32f10x.h') containing the peripheral definitions.

.OUTPUTS
A C++ header file (string) written to standard output.
#>
param(
    # [Parameter(Mandatory = $true)]
    # [string]$DeviceName,

    # [Parameter(Mandatory = $true)]
    # [string]$SourceFile

    $DeviceName = [string]"SPI",
    # $SourceFile = "./Tools/stm32f10x.h"
    $SourceFile = "./Tools/stm32h730xx.h"
)
function Get-OneBitCount {
    param (
        [UInt32]$Number
    )

    # Convert the number to binary and count the number of '1's
    $binary = [Convert]::ToString($Number, 2)
    return ($binary.ToCharArray() | Where-Object { $_ -eq '1' }).Count
}

function Get-UintSize {
    param (
        [string]$Type
    )

    # Normalize and extract the numeric part
    if ($Type -match '^uint(\d+)(_t)?$') {
        return [int]$matches[1]
    }
    else {
        throw "Invalid type format. Expected 'uintX' or 'uintX_t' where X is 8, 16, 32, or 64."
    }
}

function Get-LeastSignificantBitPosition {
    param (
        [int]$Number
    )

    if ($Number -eq 0) {
        return -1  # No bits are set
    }

    $position = 0
    while (($Number -band 1) -eq 0) {
        $Number = $Number -shr 1
        $position++
    }

    return $position
}

# --- Script Logic (Sequential Execution) ---
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"
# Read File 
try {
    $FileContent = Get-Content -Path $SourceFile -Raw
}
catch {
    Write-Error "Could not read file '$SourceFile'. Error: $($_.Exception.Message)"
    exit 1
}

$StructName = "${DeviceName}_TypeDef"
$DoxygenFileName = [System.IO.Path]::GetFileName($SourceFile)
if ($FileContent -match "@file\s+(\S+)") {
    $DoxygenFileName = $Matches[1]
}

# Struct
$Registers = . "$PSScriptRoot/Parse-Struct.ps1" -DeviceName $DeviceName -FileContent $FileContent

# Get relevant lines only, nakes process faster
$RelevantLines = $FileLines | Select-String -Pattern "$($DeviceName)"
# Collect fields
foreach ($Register in $Registers) {
    $FullRegisterName = "$($DeviceName)_$($Register.Name)"
    $BitTable = @(. "$PSScriptRoot/Parse-NewStyle.ps1" -FullRegisterName $FullRegisterName -FileContent $RelevantLines)
    if ($BitTable.Count -eq 0) {
        # No definition, try old style
        $BitTable = @(. "$PSScriptRoot/Parse-OldStyle.ps1" -FullRegisterName $FullRegisterName -FileContent $RelevantLines)
    }
    $Register.BitTable = $BitTable
}

# Code generator
$CurrentYear = (Get-Date).Year
$OutputContent = @()

$OutputContent += "/**"
$OutputContent += " ******************************************************************************"
$OutputContent += " * @author  Gyorgy Varga"
$OutputContent += " * @brief   STM32 Low-Layer register definitions for ${DeviceName} peripheral."
$OutputContent += " *"
$OutputContent += " * @copyright Gyorgy Varga - All Rights Reserved."
$OutputContent += " *            Unauthorised copying of this file, via any medium is strictly prohibited."
$OutputContent += " *            Proprietary and confidential."
$OutputContent += " * @date    $(Get-Date -Format 'MMMM dd, yyyy')"
$OutputContent += " *"
$OutputContent += " * @par Generated"
$OutputContent += " *        This file was automatically generated from ${DoxygenFileName}."
$OutputContent += " *"
$OutputContent += " ******************************************************************************"
$OutputContent += " */"
$OutputContent += "#pragma once"
$OutputContent += ""
$OutputContent += '#include <cstddef>'
$OutputContent += '#include <cstdint>'
$OutputContent += '#include <stddef.h>'
$OutputContent += '#include "RegisterAccess.hpp"'
$OutputContent += "`#include `"$DoxygenFileName`""
$OutputContent += ""

$OutputContent += "// --------------------------------------------------------------------------"
$OutputContent += ""
$OutputContent += "namespace LL"
$OutputContent += "{"
$OutputContent += "    /**"
$OutputContent += "     * @brief LL register definition of ${DeviceName}"
$OutputContent += "     * "
$OutputContent += "     * Base template is parameterized by the peripheral's base memory address."
$OutputContent += "     * "
$OutputContent += "     * @tparam baseAddress The memory address of the ${DeviceName} peripheral instance."
$OutputContent += "     */"
$OutputContent += "    template <uintptr_t baseAddress>"
$OutputContent += "    class ${DeviceName}_Registers"
$OutputContent += "    {"
$OutputContent += "    public:"

# Generate C++ Register Classes and Bit Fields
foreach ($Register in $Registers) {
    # 4a. Start the Register Class Definition
    $OutputContent += "        /** @brief $($Register.Name) register */"

    $handled = $false
    if ($Register.BitTable.Count -eq 1) {
        # Only one field, maybe whole size
        if (Get-UintSize -Type $Register.Type -eq $Register.$BitTable.FieldSize) {
            # Same size
            $OutputContent += "        using $($Register.Name) = ReadWriteRegister<$($Register.Type), baseAddress + offsetof(${StructName}, $($Register.Name))>;"
            $handled = $true
        }
    }

    if (-not $handled) {
        $OutputContent += "        struct $($Register.Name) : public ReadWriteRegister<$($Register.Type)), baseAddress + offsetof(${StructName}, $($Register.Name))>"
        $OutputContent += "        { "

        # Process Bit Definitions for the Current Register
        foreach ($Bit in $Register.BitTable) {
            if ($Bit.FieldSize -eq 1) {
                $OutputContent += "            using $($Bit.Name) = typename $($Register.Name)::Bit<$($Bit.Pos.ToString())>; ".PadRight(70) + " // $($Bit.Comment)"
                $handled = $true
            }
            elseif ($Bit.FieldSize -gt 1) {
                $OutputContent += "            using $($Bit.Name) = typename $($Register.Name)::BitField<$($Bit.Pos.ToString()), $($Bit.FieldSize.ToString())>; ".PadRight(70) + " // $($Bit.Comment)"
                $handled = $true
            }
        }
        $OutputContent += "        }; "
    }
    $OutputContent += ""
}

# --- 5. Close C++ Scopes ---

$OutputContent += "    
}; // class ${DeviceName}_Registers"
$OutputContent += "
} // namespace LL"

# --- 6. Output Result ---
$OutputContent | Out-String
