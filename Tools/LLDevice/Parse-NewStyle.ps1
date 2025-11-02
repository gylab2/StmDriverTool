param(
    [Parameter(Mandatory = $true)]
    [string]$FullRegisterName,

    [Parameter(Mandatory = $true)]
    $FileContent
)

# Get all mask definitions
$MaskPattern = "#define\s*$($FullRegisterName)_([A-Z][A-Z0-9]*)_Msk\s.*"
$FieldMaskDefinitions = $FileContent | Select-String -Pattern $MaskPattern

# Scan all fields
$BitTable = @()
foreach ($MaskLine in $FieldMaskDefinitions) {
    # Get field name
    $dummy = $MaskLine -match $MaskPattern;
    $FieldName = $Matches[1].Trim()
    $FullFieldName = "$($FullRegisterName)_$($FieldName)"

    # Get position
    $PatternForPosition = "(#define\s*$($FullFieldName)_Pos\s.*\()([0-9]*)U\)"
    $FoundPosLine = $FileContent | Select-String -Pattern $PatternForPosition -AllMatches

    if ($FoundPosLine.Count -ne 1) {
        exit 1
    }

    if ($FoundPosLine -match $PatternForPosition) {
        $PosValueString = $Matches[2].Trim();

        # Get mask
        $PatternForMaskValueWithoutPosition = ".*\(0x([0-9A-F]*)UL";
        $dummy = $MaskLine -match $PatternForMaskValueWithoutPosition
        $MaskValueWithoutPositionString = $Matches[1].Trim()

        # Get comment line (without suffix)
        $PatternForComment = "(#define\s*$($FullFieldName)\s.*)/\*!<(.*)\*/"
        $CommentLine = $FileContent | Select-String -Pattern $PatternForComment
        if ($CommentLine -match $PatternForComment) {
            $CommentString = $Matches[2].Trim()
        }
        else {
            # Comment not found, try pattern without !<, some registers has no this pattern
            $PatternForComment = "(#define\s*$($FullFieldName)\s.*)/\*(.*)\*/"
            $CommentLine = $FileContent | Select-String -Pattern $PatternForComment
            if ($CommentLine -match $PatternForComment) {
                $CommentString = $Matches[2].Trim()
            }
        }

        # Convert to integer
        $MaskInt = [System.Convert]::ToUInt32($MaskValueWithoutPositionString, 16) 
        $PosInt = [System.Convert]::ToUInt32($PosValueString, 10) 
        $FieldSize = Get-OneBitCount -Number $MaskInt

        # Build record
        $BitRecord = @{Name = $FieldName; Pos = $PosInt; FieldSize = $FieldSize; Line = $FoundPosLine; Comment = $CommentString };
        $BitTable += $BitRecord;
    }
    else {
        # No field definition, nothing to add
    }

}
# Always return with array
@($BitTable)