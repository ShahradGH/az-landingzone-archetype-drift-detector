# Test-LandingZoneWriteProvenance.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [PSCustomObject]$ActivityLogEvent,
    [Parameter(Mandatory)] [string[]]$ApprovedPipelineAppIds
)

$ErrorActionPreference = 'Stop'

# 1. Permitted GitOps Pipeline OIDC Principal
if ($ApprovedPipelineAppIds -contains $ActivityLogEvent.CallerAppId) {
    return [PSCustomObject]@{
        ResourceId   = $ActivityLogEvent.ResourceId
        Classification = 'COMPLIANT_GITOPS_PIPELINE'
        Action       = 'NONE'
    }
}

# 2. Immediate Hard Revert on High-Risk Perimeter Drift without Sev-1 Ticket
$isPerimeterResource = $ActivityLogEvent.ResourceType -match '(?i)(networkSecurityGroups|publicIPAddresses|routeTables|vaults)'
if ($isPerimeterResource -and [string]::IsNullOrWhiteSpace($ActivityLogEvent.Sev1IncidentTicketId)) {
    return [PSCustomObject]@{
        ResourceId     = $ActivityLogEvent.ResourceId
        CallerUpn      = $ActivityLogEvent.CallerUpn
        Classification = 'UNAUTHORIZED_PERIMETER_CLICKOPS'
        Action         = 'REVERT_TO_GIT_BASELINE_IMMEDIATELY'
    }
}

# 3. Sev-1 Break-Glass Hotfix: Open Automated Backport Bicep PR (4h TTL)
return [PSCustomObject]@{
    ResourceId     = $ActivityLogEvent.ResourceId
    CallerUpn      = $ActivityLogEvent.CallerUpn
    IncidentTicket = $ActivityLogEvent.Sev1IncidentTicketId
    Classification = 'SEV1_BREAK_GLASS_DRIFT'
    Action         = 'OPEN_AUTOMATED_BICEP_BACKPORT_PR'
}