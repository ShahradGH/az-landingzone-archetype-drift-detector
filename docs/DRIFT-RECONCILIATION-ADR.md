# ADR-002: Landing Zone Drift Reconciliation & Corroborated Break-Glass Hotfix Boundary

- **Status:** Accepted
- **Date:** 2026-11-15
- **Owners:** Cloud Platform Architecture & Site Reliability Engineering

## 1. Context and Problem Statement

In enterprise Azure Landing Zones, Platform Engineers enforce Network Security Groups (NSGs), Route Tables, and Key Vault access policies through GitOps OIDC pipelines and Azure Deployment Stacks (`denyWriteAndDelete`). However, at 02:00 UTC during a Priority-1 (P1) production outage, an on-call SRE may legitimately need to apply an emergency Portal or Azure CLI hotfix to restore service.

Naive drift detectors treat all out-of-band mutations identically: either they auto-revert every Portal change immediately (breaking the P1 recovery mid-incident), or they alert passively without distinguishing an authorised P1 hotfix from shadow IT ClickOps.

## 2. Decision

We implement a **Corroborated Intent Classification Architecture** using PowerShell 7.4+, Azure Resource Graph (`Microsoft.Resources/changes`), Azure Deployment Stacks (`Invoke-AzRestMethod`), Microsoft Graph v2.x Teams bridge transcripts, and an AI Drift Intent Classifier (`ai/Invoke-DriftIntentClassifier.ps1`):

1. **OIDC Pipeline Fast-Path**: Changes authored by an approved GitOps OIDC Service Principal (`ApprovedPipelineAppIds`) are classified `COMPLIANT_GITOPS_PIPELINE` with zero friction.
2. **Perimeter Hard-Revert**: High-risk perimeter mutations (`networkSecurityGroups`, `publicIPAddresses`, `routeTables`, `vaults`) with no valid `INC-P1-xxxxxx` ticket are classified `SHADOW_IT_PORTAL_DRIFT` and immediately reverted (`REVERT_TO_BASELINE_IMMEDIATELY`).
3. **Teams Bridge Corroboration & Abstention Gate**: When an `INC-P1-xxxxxx` ticket is present, `graph/Get-IncidentBridgeContext.ps1` fetches the active P1 Teams incident bridge transcript via `/v1.0/teams/{teamId}/channels/{channelId}/messages`. `ai/Invoke-DriftIntentClassifier.ps1` verifies that both the incident ticket and the mutated resource name are corroborated in the bridge transcript:
   - **Corroborated (`Confidence >= 0.75`)**: Emits `AUTHORIZED_P1_HOTFIX_WITH_TTL` and opens a 4-hour TTL backport Pull Request (`OPEN_AUTOMATED_REST_BACKPORT_PR`).
   - **Uncorroborated (`Confidence < 0.75`)**: Emits `ABSTAIN_UNCORROBORATED_CLAIM` and holds for SRE Commander verification—preventing attackers or careless operators from spoofing a random `INC-P1-` ticket string.

## 3. Consequences

- **Positive**: Preserves 2 AM incident recovery velocity whilst eliminating uncorroborated ClickOps and shadow IT perimeter drift.
- **Negative / Trade-offs**: Requires on-call SREs to state the `INC-P1-xxxxxx` ticket and target resource name in the P1 Teams bridge channel before or during emergency mutations.
