param(
    [Parameter(Mandatory = $true)]
    [string]$FullRegisterName,

    [Parameter(Mandatory = $true)]
    $FileContent
)

# Get all mask definitions
$MaskPattern = "#define\s*$($FullRegisterName)_([A-Z][A-Z0-9]*)\s.*"
$FieldMaskDefinitions = $FileContent | Select-String -Pattern $MaskPattern

# Scan all fields
$BitTable = @()
foreach ($MaskLine in $FieldMaskDefinitions) {
    # Get field name
    $dummy = $MaskLine -match $MaskPattern;
    $FieldName = $Matches[1].Trim()
    $FullFieldName = "$($FullRegisterName)_$($FieldName)"

    # Get Mask
    $PatternForMask = "(#define\s.*$($FullFieldName)\s.*\()uint(\d+)_t\)0x([0-9A-F]+)\)\s+/\*!<(.*)\*/"
    $FoundMaskLine = $FileContent | Select-String -Pattern $PatternForMask -AllMatches
    if ($FoundMaskLine -match $PatternForMask) {
        $MaskValue = $Matches[3]
        $CommentString = $Matches[4]
        
        $MaskInt = [System.Convert]::ToUInt32($MaskValue, 16) 
        $PosInt = Get-LeastSignificantBitPosition -Number $MaskInt
        $FieldSize = Get-OneBitCount -Number $MaskInt

        # Build record
        $BitRecord = @{Name = $FieldName; Pos = $PosInt; FieldSize = $FieldSize; Line = $FoundMaskLine; Comment = $CommentString };
        $BitTable += $BitRecord;
    }
}
# Always return with array
@($BitTable)