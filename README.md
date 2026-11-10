# Landing Zone Governance: Detecting & Reconciling Out-of-Band Azure Portal Drift

[![Pester Verification](https://img.shields.io/badge/pester-16%2F16%20passing-brightgreen)](tests/LandingZoneDrift.Tests.ps1)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Architecture Deep-Dive](https://img.shields.io/badge/blog-alerasoul.net-0a1128)](https://alerasoul.net/landing-zone-archetype-drift-reconciliation/)

> **Primary Governance Artefact:** Archetype Drift Detection Watchdog & Re-baselining Pipeline  
> **Accountable Service Owner:** Lead Cloud Platform Engineer & Landing Zone Architect  
> **Full Architectural Deep-Dive:** [https://alerasoul.net/landing-zone-archetype-drift-reconciliation/](https://alerasoul.net/landing-zone-archetype-drift-reconciliation/)

---

## Repository Layout (15 Files)

```text
├── .github/workflows/drift-watch.yml
├── LICENSE
├── README.md
├── docs/DRIFT-RECONCILIATION-ADR.md
├── docs/SRE-BREAKGLASS-RUNBOOK.md
├── fixtures/arg-change-payload.json
├── infra/main.bicep
├── infra/modules/hub-network.bicep
├── infra/modules/nsg-baseline.bicep
├── queries/NSG-SecurityDrift.kql
├── queries/ResourceGraph-OutOfBandChanges.kql
├── src/LandingZoneDrift.psd1
├── src/LandingZoneDrift.psm1
├── src/Test-LandingZoneWriteProvenance.ps1
└── tests/LandingZoneDrift.Tests.ps1
```

## Quickstart & Offline Verification

```powershell
# 1. Execute the primary PowerShell 7 evaluator
pwsh -NoProfile -File ./src/Test-LandingZoneWriteProvenance.ps1

# 2. Run the 16-test Pester verification contract
Invoke-Pester -Path ./tests/LandingZoneDrift.Tests.ps1 -Output Detailed
```

## License

Released under the [MIT License](LICENSE). Authored by **Shahrad Alerasoul** ([alerasoul.net](https://alerasoul.net)).
