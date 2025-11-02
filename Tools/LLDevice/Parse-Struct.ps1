param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceName,

    [Parameter(Mandatory = $true)]
    $FileContent
)

# Find start and end of the desired struct block

$FileLines = $FileContent.Split([Environment]::NewLine)
Remove-Variable $FileContent
for ($i = 0; $i -lt $FileLines.Count; $i++) {
    if ($FileLines[$i] -match "typedef struct") {
        $startLine = $i
    }
    if ($FileLines[$i] -match "}\s*$StructName") {
        break
    }
}
$StructDeclaration = $FileLines[($startLine + 1)..($i - 1)]

# Extract Register members from the body (excluding RESERVED)
$Registers = @()
$RegisterPattern = "^\s*((?:__IO|__I|__O|volatile|\w+\s+)*\s*(uint(?:16|32)_t|u(?:16|32)))\s+([a-zA-Z0-9_]+)\s*;\s*(/\*.*?$|/\*.*?\*/)?\s*$"

$StructDeclaration -split "`n" | ForEach-Object {
    $Line = $_.Trim()

    if ($Line -match $RegisterPattern) {
        $RegName = $Matches[3].Trim()

        if ($RegName -notmatch '^RESERVED\d+') {
            $RegType = $Matches[2].Trim()
            $Registers += @{ Name = $RegName; Type = $RegType }
        }
    }
}

$Registers
