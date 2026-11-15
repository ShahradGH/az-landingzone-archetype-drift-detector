Set-StrictMode -Version Latest

function Confirm-BreakGlassIncidentTag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$IncidentTag
    )
    return ($IncidentTag -match '^INC-P1-\d{6}$')
}

function Get-ArgResourceChanges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,

        [Parameter()]
        [int]$LookbackHours = 4,

        [Parameter()]
        [scriptblock]$AzRestInvoker
    )

    $query = @"
ResourceChanges
| where properties.changeAttributes.timestamp > ago(${LookbackHours}h)
| where properties.targetResourceType in~ ('Microsoft.Network/networkSecurityGroups', 'Microsoft.Network/routeTables', 'Microsoft.KeyVault/vaults')
| project resourceId = properties.targetResourceId, resourceType = properties.targetResourceType, changeType = properties.changeType, clientType = properties.changeAttributes.clientType
"@
    $payload = @{
        subscriptions = @($SubscriptionId)
        query         = $query
    }
    $path = '/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01'

    if ($null -ne $AzRestInvoker) {
        return & $AzRestInvoker 'POST' $path $payload
    }
    $resp = Invoke-AzRestMethod -Method Post -Path $path -Payload ($payload | ConvertTo-Json -Depth 6)
    if ($resp.StatusCode -ge 400) {
        throw "Resource Graph query failed with HTTP $($resp.StatusCode): $($resp.Content)"
    }
    return ($resp.Content | ConvertFrom-Json)
}

function Test-DeploymentStackDrift {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$DeploymentStackName,

        [Parameter()]
        [scriptblock]$AzRestInvoker
    )

    $path = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Resources/deploymentStacks/${DeploymentStackName}?api-version=2024-03-01"
    if ($null -ne $AzRestInvoker) {
        $stack = & $AzRestInvoker 'GET' $path $null
    }
    else {
        $resp = Invoke-AzRestMethod -Method Get -Path $path
        if ($resp.StatusCode -ge 400) {
            throw "Deployment Stack GET failed with HTTP $($resp.StatusCode): $($resp.Content)"
        }
        $stack = $resp.Content | ConvertFrom-Json
    }

    return [PSCustomObject]@{
        DeploymentStackName = $DeploymentStackName
        DenySettingsMode    = $stack.properties.denySettings.mode
        ProvisioningState   = $stack.properties.provisioningState
        DenySettingsActive  = ($stack.properties.denySettings.mode -in @('denyDelete', 'denyWriteAndDelete'))
    }
}

Export-ModuleMember -Function Confirm-BreakGlassIncidentTag, Get-ArgResourceChanges, Test-DeploymentStackDrift
