# SRE Break-Glass & Landing Zone Drift Runbook

## 1. Purpose and Scope

This runbook defines Level-2 and Level-3 operational procedures for investigating Azure Landing Zone drift events detected by `ResourceChanges` (`Microsoft.Resources/changes`), Deployment Stacks (`denySettings`), and the AI Drift Intent Classifier (`ai/Invoke-DriftIntentClassifier.ps1`).

## 2. Routine Verification Procedures

### 2.1 Querying Out-of-Band Changes via Azure Resource Graph
Run `Get-ArgResourceChanges` from `src/LandingZoneDrift.psm1` (powered by `Invoke-AzRestMethod` against `/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01`) or execute `queries/ResourceGraph-OutOfBandChanges.kql` and `queries/NSG-SecurityDrift.kql` in Log Analytics.

### 2.2 Verifying Deployment Stack Deny Settings
Confirm that hub networking and NSG baseline Deployment Stacks retain `denyWriteAndDelete` or `denyDelete` mode:
```powershell
Import-Module ./src/LandingZoneDrift.psm1 -Force
Test-DeploymentStackDrift -SubscriptionId '<sub-id>' -ResourceGroupName 'rg-contoso-hub' -DeploymentStackName 'ds-hub-network'
```

## 3. Incident Response Playbooks

### 3.1 Playbook A: `SHADOW_IT_PORTAL_DRIFT` (Unauthorized Perimeter Mutation)
1. Confirm no active `INC-P1-xxxxxx` bridge exists in Microsoft Teams.
2. Execute `REVERT_TO_BASELINE_IMMEDIATELY` by re-syncing the Deployment Stack or restoring the last GitOps baseline state via REST.
3. Review Entra ID `AuditLogs` for the `CallerUpn` and revoke standing Contributor/Network Contributor RBAC if PIM JIT was bypassed.

### 3.2 Playbook B: `AUTHORIZED_P1_HOTFIX_WITH_TTL` (4-Hour Break-Glass Window)
1. Verify the Teams bridge transcript retrieved by `graph/Get-IncidentBridgeContext.ps1` corroborates both the `INC-P1-xxxxxx` ticket and the resource name.
2. Track the 4-hour TTL (`TtlHours = 4`). Before the 4-hour window expires, either merge the automated backport PR (`OPEN_AUTOMATED_REST_BACKPORT_PR`) into `main` or revert the temporary NSG/Route Table rule once the P1 incident is resolved.

### 3.3 Playbook C: `ABSTAIN_UNCORROBORATED_CLAIM`
1. The operator supplied a valid `INC-P1-xxxxxx` format, yet the Teams bridge transcript did not mention the mutated resource.
2. Page the Incident Commander to confirm whether the change was intentional; if unconfirmed, treat as `SHADOW_IT_PORTAL_DRIFT` and revert immediately.
