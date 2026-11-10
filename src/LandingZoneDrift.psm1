function Confirm-BreakGlassIncidentTag {
    [CmdletBinding()]
    param([string]$IncidentTag)
    return ($IncidentTag -match '^INC-P1-\d{6}$')
}
Export-ModuleMember -Function Confirm-BreakGlassIncidentTag
