# Operational Runbook: Landing Zone Governance: Detecting & Reconciling Out-of-Band Azure Portal Drift (L2 / L3 Triage)

## 1. Scope & Ownership
- **Accountable Owner**: Lead Cloud Platform Engineer & Landing Zone Architect
- **Primary Evaluator**: `src/Test-LandingZoneWriteProvenance.ps1`
- **Telemetry Source**: `diagnostics/Telemetry-Queries.kql`

## 2. Triage Procedure When Veto Gate Trips
1. Inspect the structured refusal object emitted by `src/Test-LandingZoneWriteProvenance.ps1` and correlate the timestamp in Azure Monitor Log Analytics.
2. Do not bypass or disable the pre-flight policy gate without cryptographic dual-signature approval from the Lead Cloud Platform Engineer & Landing Zone Architect.
3. Verify remediation locally by running `Invoke-Pester -Path ./tests/Boundary-Verification.Tests.ps1 -Output Detailed`.
