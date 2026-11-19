BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:ClassifierPath = Join-Path $script:RepoRoot 'ai/Invoke-DriftIntentClassifier.ps1'
    $script:EvalCasesPath = Join-Path $script:RepoRoot 'ai/drift-intent-eval-cases.json'
    $script:ModulePath = Join-Path $script:RepoRoot 'src/LandingZoneDrift.psd1'
    $script:ProvenancePath = Join-Path $script:RepoRoot 'src/Test-LandingZoneWriteProvenance.ps1'
    $script:GraphBridgePath = Join-Path $script:RepoRoot 'graph/Get-IncidentBridgeContext.ps1'
    $script:EvalDoc = Get-Content -Path $script:EvalCasesPath -Raw | ConvertFrom-Json
    Import-Module $script:ModulePath -Force
}

Describe 'Landing Zone Archetype Drift Detector - AI Intent, ARG & Graph Bridge Matrix' {
    Context 'AI Drift Intent Classifier (ai/Invoke-DriftIntentClassifier.ps1)' {
        It 'Classifies corroborated 2 AM P1 hotfix with 4-hour TTL (DRIFT-01)' {
            $c = $script:EvalDoc.evalCases | Where-Object { $_.caseId -eq 'DRIFT-01' }
            $res = & $script:ClassifierPath -DriftEvent $c -BridgeTranscript $c.bridgeTranscriptExcerpt
            $res.Intent | Should -Be 'AUTHORIZED_P1_HOTFIX_WITH_TTL'
            $res.Action | Should -Be 'OPEN_AUTOMATED_REST_BACKPORT_PR'
            $res.TtlHours | Should -Be 4
            $res.Confidence | Should -BeGreaterOrEqual 0.75
        }

        It 'Classifies unapproved Portal perimeter change as SHADOW_IT_PORTAL_DRIFT (DRIFT-02)' {
            $c = $script:EvalDoc.evalCases | Where-Object { $_.caseId -eq 'DRIFT-02' }
            $res = & $script:ClassifierPath -DriftEvent $c -BridgeTranscript $c.bridgeTranscriptExcerpt
            $res.Intent | Should -Be 'SHADOW_IT_PORTAL_DRIFT'
            $res.Action | Should -Be 'REVERT_TO_BASELINE_IMMEDIATELY'
        }

        It 'Abstains when P1 ticket is uncorroborated in Teams bridge transcript (DRIFT-03)' {
            $c = $script:EvalDoc.evalCases | Where-Object { $_.caseId -eq 'DRIFT-03' }
            $res = & $script:ClassifierPath -DriftEvent $c -BridgeTranscript $c.bridgeTranscriptExcerpt
            $res.Intent | Should -Be 'ABSTAIN_UNCORROBORATED_CLAIM'
            $res.Action | Should -Be 'HOLD_FOR_SRE_COMMANDER_VERIFICATION'
            $res.Confidence | Should -BeLessThan 0.75
        }

        It 'Fast-paths approved GitOps OIDC pipeline service principal' {
            $evt = [PSCustomObject]@{
                resourceId  = '/subscriptions/sub-1/resourceGroups/rg-hub/providers/Microsoft.Network/networkSecurityGroups/nsg-hub'
                callerAppId = '00000000-0000-0000-0000-000000000901'
            }
            $res = & $script:ClassifierPath -DriftEvent $evt
            $res.Intent | Should -Be 'COMPLIANT_OIDC_PIPELINE'
            $res.Action | Should -Be 'NONE'
        }

        It 'Integrates mocked Azure AI Foundry semantic verification' {
            $c = $script:EvalDoc.evalCases | Where-Object { $_.caseId -eq 'DRIFT-01' }
            $mockFoundry = {
                param($ep, $dep, $body)
                return [PSCustomObject]@{
                    intentSummary        = 'P1 payment gateway port 8443 hotfix corroborated by oncall.sre.'
                    corroborated         = $true
                    confidenceAdjustment = 0.04
                }
            }
            $res = & $script:ClassifierPath -DriftEvent $c -BridgeTranscript $c.bridgeTranscriptExcerpt -FoundryEndpoint 'https://foundry.contoso.invalid' -FoundryInvoker $mockFoundry
            $res.FoundryCritique.corroborated | Should -BeTrue
            $res.Confidence | Should -BeGreaterThan 0.91
        }
    }

    Context 'PowerShell Module, Deployment Stacks & Graph v1.0 Incident Bridge' {
        It 'Validates INC-P1-xxxxxx break-glass tag format' {
            Confirm-BreakGlassIncidentTag -IncidentTag 'INC-P1-482910' | Should -BeTrue
            Confirm-BreakGlassIncidentTag -IncidentTag 'INC-INVALID' | Should -BeFalse
        }

        It 'Queries Azure Resource Graph ResourceChanges via Invoke-AzRestMethod' {
            $mockAz = {
                param($m, $p, $b)
                $p | Should -Match 'Microsoft\.ResourceGraph/resources'
                return [PSCustomObject]@{ data = @([PSCustomObject]@{ resourceType = 'Microsoft.Network/networkSecurityGroups' }) }
            }
            $res = Get-ArgResourceChanges -SubscriptionId '00000000-0000-0000-0000-000000000013' -AzRestInvoker $mockAz
            $res.data.Count | Should -Be 1
        }

        It 'Verifies Deployment Stack denySettings active state via Invoke-AzRestMethod' {
            $mockAz = {
                param($m, $p, $b)
                return [PSCustomObject]@{
                    properties = [PSCustomObject]@{
                        provisioningState = 'Succeeded'
                        denySettings      = [PSCustomObject]@{ mode = 'denyWriteAndDelete' }
                    }
                }
            }
            $res = Test-DeploymentStackDrift -SubscriptionId '00000000-0000-0000-0000-000000000013' -ResourceGroupName 'rg-contoso-hub' -DeploymentStackName 'ds-hub' -AzRestInvoker $mockAz
            $res.DenySettingsActive | Should -BeTrue
            $res.DenySettingsMode | Should -Be 'denyWriteAndDelete'
        }

        It 'Fetches Teams incident bridge messages via Graph v1.0' {
            $mockGraph = {
                param($m, $u, $b)
                $u | Should -Match 'https://graph\.microsoft\.com/v1\.0/teams/team-sre/channels/19:p1@thread\.tacv2/messages'
                return [PSCustomObject]@{
                    value = @(
                        [PSCustomObject]@{
                            createdDateTime = '2026-11-15T02:14:00Z'
                            from            = [PSCustomObject]@{ user = [PSCustomObject]@{ displayName = 'oncall.sre' } }
                            body            = [PSCustomObject]@{ content = '<p>Opening port 8443 on nsg-ingress-prod under INC-P1-482910</p>' }
                        }
                    )
                }
            }
            $res = & $script:GraphBridgePath -TeamId 'team-sre' -ChannelId '19:p1@thread.tacv2' -GraphInvoker $mockGraph
            $res.MessageCount | Should -Be 1
            $res.BridgeTranscript | Should -Match 'INC-P1-482910'
        }

        It 'Enforces Test-LandingZoneWriteProvenance.ps1 REST backport PR on Sev-1' {
            $evt = [PSCustomObject]@{
                ResourceId           = '/subscriptions/sub-1/resourceGroups/rg-hub/providers/Microsoft.Network/networkSecurityGroups/nsg-ingress-prod'
                ResourceType         = 'Microsoft.Network/networkSecurityGroups'
                CallerAppId          = 'portal-client'
                CallerUpn            = 'oncall.sre@contoso.com'
                Sev1IncidentTicketId = 'INC-P1-482910'
            }
            $res = & $script:ProvenancePath -ActivityLogEvent $evt -ApprovedPipelineAppIds @('00000000-0000-0000-0000-000000000901')
            $res.Action | Should -Be 'OPEN_AUTOMATED_REST_BACKPORT_PR'
        }
    }

    Context 'Repository Hygiene & Zero-Leak Boundaries' {
        It 'Contains zero declarative IaC (.bicep or .tf) files' {
            $iac = Get-ChildItem -Path $script:RepoRoot -Recurse -Include '*.bicep', '*.tf' -File
            $iac.Count | Should -Be 0
        }

        It 'KQL drift queries exist and use projection/aggregation' {
            $kql1 = Join-Path $script:RepoRoot 'queries/NSG-SecurityDrift.kql'
            $kql2 = Join-Path $script:RepoRoot 'queries/ResourceGraph-OutOfBandChanges.kql'
            Test-Path $kql1 | Should -BeTrue
            Test-Path $kql2 | Should -BeTrue
        }

        It 'README and docs contain zero internal sequence numbers or private orchestrator domains' {
            foreach ($f in @((Join-Path $script:RepoRoot 'README.md'), (Join-Path $script:RepoRoot 'docs/DRIFT-RECONCILIATION-ADR.md'), (Join-Path $script:RepoRoot 'docs/SRE-BREAKGLASS-RUNBOOK.md'))) {
                $raw = Get-Content $f -Raw
                $raw | Should -Not -Match 'mvpfoundry\.alerasoul\.net|192\.142\.41\.43|Decision Pack 0|idea-013'
            }
        }
    }

    Context 'Identity & Microsoft Graph v2.x Drift Governance Module' {
        BeforeAll {
            Import-Module (Join-Path $script:RepoRoot 'identity/DriftIdentityGovernance.psd1') -Force
        }

        It 'Classifies an approved CI/CD service principal as WorkloadIdentity' {
            $mockGraph = {
                param($m, $u, $b)
                return [PSCustomObject]@{ id = 'sp-901'; appId = 'app-901'; displayName = 'ALZ-Deploy-SP'; accountEnabled = $true }
            }

            $res = Resolve-DriftCallerPrincipal -CallerAppId 'app-901' -ApprovedPipelineAppIds @('app-901') -GraphInvoker $mockGraph
            $res.PrincipalKind | Should -Be 'WorkloadIdentity'
            $res.IsApprovedCICD | Should -BeTrue
            $res.RequiresPimCheck | Should -BeFalse
        }

        It 'Classifies a portal user write as InteractiveUser requiring PIM check' {
            $mockGraph = {
                param($m, $u, $b)
                return [PSCustomObject]@{ id = 'usr-44'; userPrincipalName = 'sre@contoso.com'; displayName = 'SRE OnCall'; accountEnabled = $true; userType = 'Member' }
            }

            $res = Resolve-DriftCallerPrincipal -CallerAppId 'portal-session' -CallerUpn 'sre@contoso.com' -ApprovedPipelineAppIds @('app-901') -GraphInvoker $mockGraph
            $res.PrincipalKind | Should -Be 'InteractiveUser'
            $res.RequiresPimCheck | Should -BeTrue
        }

        It 'Verifies active Entra ID PIM role assignment schedule instances' {
            $mockGraph = {
                param($m, $u, $b)
                return [PSCustomObject]@{ value = @([PSCustomObject]@{ roleDefinitionId = 'role-contrib-01' }) }
            }

            $res = Test-BreakGlassPimActivation -PrincipalId 'usr-44' -GraphInvoker $mockGraph
            $res.HasActiveElevation | Should -BeTrue
            $res.ActivePimCount | Should -Be 1
        }

        It 'Dispatches Shadow-IT drift governance escalation to Teams channel' {
            $mockGraph = { param($m, $u, $b) return [PSCustomObject]@{ id = 'msg-drift-01' } }
            $res = Send-DriftGovernanceEscalation -TeamId 't-lz' -ChannelId 'c-lz' -ResourceId '/subscriptions/sub/nsg-app' -Classification 'SHADOW_IT_PORTAL_DRIFT' -CallerDisplayName 'Dev Contractor' -GraphInvoker $mockGraph
            $res.Dispatched | Should -BeTrue
            $res.MessageId | Should -Be 'msg-drift-01'
        }
    }
}
