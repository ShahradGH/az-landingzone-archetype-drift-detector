<#
.SYNOPSIS
    Fetches Microsoft Teams P1 incident bridge channel messages via Microsoft Graph v1.0.
.DESCRIPTION
    Queries /v1.0/teams/{teamId}/channels/{channelId}/messages using Invoke-MgGraphRequest
    and concatenates recent incident bridge context for AI drift-intent corroboration.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TeamId,

    [Parameter(Mandatory)]
    [string]$ChannelId,

    [Parameter()]
    [int]$Top = 25,

    [Parameter()]
    [scriptblock]$GraphInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$uri = "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$ChannelId/messages?`$top=$Top"
$resp = if ($null -ne $GraphInvoker) {
    & $GraphInvoker 'GET' $uri $null
}
else {
    Invoke-MgGraphRequest -Method Get -Uri $uri
}

$messages = @($resp.value)
$transcriptLines = foreach ($m in $messages) {
    $ts = $m.createdDateTime
    $sender = $m.from.user.displayName
    $text = ($m.body.content -replace '<[^>]+>', '').Trim()
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        "$ts [$sender]: $text"
    }
}

return [PSCustomObject]@{
    TeamId           = $TeamId
    ChannelId        = $ChannelId
    MessageCount     = $messages.Count
    BridgeTranscript = ($transcriptLines -join "`n")
    FetchedAtUtc     = (Get-Date).ToUniversalTime().ToString('o')
}
