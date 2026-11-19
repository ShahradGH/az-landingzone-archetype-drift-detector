<#
.SYNOPSIS
    Microsoft Graph v2.x identity and PIM governance module for Landing Zone Drift Detection.
.DESCRIPTION
    Resolves Entra ID caller principals (workload service principals vs interactive portal users),
    verifies active Privileged Identity Management (PIM) activations for P1 hotfixes, and dispatches
    Teams governance escalations via Microsoft Graph v1.0.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-DriftGraphRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [scriptblock]$GraphInvoker
    )

    if ($null -ne $GraphInvoker) {
        return & $GraphInvoker $Method $Uri $Body
    }

    $params = @{
        Method = $Method
        Uri    = $Uri
    }
    if ($null -ne $Body) {
        $params['Body'] = ($Body | ConvertTo-Json -Depth 10)
        $params['ContentType'] = 'application/json'
    }

    return Invoke-MgGraphRequest @params
}

function Resolve-DriftCallerPrincipal {
    <#
    .SYNOPSIS
        Resolves an Azure Activity Log caller (AppId or UPN) via Microsoft Graph v1.0 to classify workload vs interactive writes.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$CallerAppId,

        [Parameter()]
        [string]$CallerUpn,

        [Parameter()]
        [string[]]$ApprovedPipelineAppIds = @(),

        [Parameter()]
        [scriptblock]$GraphInvoker
    )

    if (-not [string]::IsNullOrWhiteSpace($CallerAppId) -and ($ApprovedPipelineAppIds -contains $CallerAppId)) {
        $spUri = "https://graph.microsoft.com/v1.0/servicePrincipals(appId='$CallerAppId')?`$select=id,appId,displayName,accountEnabled"
        $sp = Invoke-DriftGraphRequest -Method 'GET' -Uri $spUri -GraphInvoker $GraphInvoker
        return [PSCustomObject]@{
            PrincipalKind    = 'WorkloadIdentity'
            PrincipalId      = $sp.id
            DisplayName      = $sp.displayName
            IsApprovedCICD   = [bool]($sp.accountEnabled -eq $true)
            RequiresPimCheck = $false
        }
    }

    $encoded = [System.Uri]::EscapeDataString($CallerUpn)
    $userUri = "https://graph.microsoft.com/v1.0/users/$encoded`?`$select=id,userPrincipalName,displayName,accountEnabled,userType"
    $user = Invoke-DriftGraphRequest -Method 'GET' -Uri $userUri -GraphInvoker $GraphInvoker

    return [PSCustomObject]@{
        PrincipalKind    = 'InteractiveUser'
        PrincipalId      = $user.id
        DisplayName      = $user.displayName
        IsApprovedCICD   = $false
        RequiresPimCheck = $true
    }
}

function Test-BreakGlassPimActivation {
    <#
    .SYNOPSIS
        Verifies whether an interactive caller holds an active Entra ID PIM role assignment schedule instance.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PrincipalId,

        [Parameter()]
        [string]$TicketPrefix = 'INC-P1-',

        [Parameter()]
        [scriptblock]$GraphInvoker
    )

    $filter = [System.Uri]::EscapeDataString("principalId eq '$PrincipalId' and assignmentType eq 'Activated'")
    $uri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances?`$filter=$filter"
    $resp = Invoke-DriftGraphRequest -Method 'GET' -Uri $uri -GraphInvoker $GraphInvoker
    $instances = @($resp.value)

    $activeCount = $instances.Count
    return [PSCustomObject]@{
        PrincipalId         = $PrincipalId
        ActivePimCount      = $activeCount
        HasActiveElevation  = ($activeCount -gt 0)
        RoleDefinitionIds   = @($instances | ForEach-Object { $_.roleDefinitionId })
        CheckedAtUtc        = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Send-DriftGovernanceEscalation {
    <#
    .SYNOPSIS
        Dispatches a Shadow-IT drift or uncorroborated P1 escalation card to a Teams channel via Microsoft Graph.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$TeamId,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$ResourceId,

        [Parameter(Mandatory)]
        [string]$Classification,

        [Parameter(Mandatory)]
        [string]$CallerDisplayName,

        [Parameter()]
        [scriptblock]$GraphInvoker
    )

    $uri = "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$ChannelId/messages"
    $payload = @{
        body = @{
            contentType = 'html'
            content     = "<b>Landing Zone Drift Alert [$Classification]</b> | Caller: $CallerDisplayName | Resource: <code>$ResourceId</code>"
        }
    }

    if (-not $PSCmdlet.ShouldProcess("$TeamId/$ChannelId", "Send drift governance escalation for $ResourceId")) {
        return [PSCustomObject]@{
            Classification = $Classification
            Dispatched     = $false
            MessageId      = 'WHATIF-DRYRUN'
        }
    }

    $resp = Invoke-DriftGraphRequest -Method 'POST' -Uri $uri -Body $payload -GraphInvoker $GraphInvoker
    return [PSCustomObject]@{
        Classification = $Classification
        Dispatched     = $true
        MessageId      = $resp.id
    }
}

Export-ModuleMember -Function @(
    'Resolve-DriftCallerPrincipal',
    'Test-BreakGlassPimActivation',
    'Send-DriftGovernanceEscalation'
)
