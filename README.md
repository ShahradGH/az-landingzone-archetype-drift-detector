# Landing Zone Governance: Detecting & Reconciling Out-of-Band Azure Portal Drift

[![Pester Verification](https://img.shields.io/badge/pester-16%2F16%20passing-brightgreen)](tests/Boundary-Verification.Tests.ps1)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Author](https://img.shields.io/badge/author-Shahrad%20Alerasoul-0a1128)](https://alerasoul.net)

> **Dominant Artefact:** Archetype Drift Detection Watchdog & Re-baselining Pipeline  
> **Service Owner / Gate Authority:** Lead Cloud Platform Engineer & Landing Zone Architect

---

## Repository Structure

```
├── .github/workflows/ci.yml           # Automated Pester 5/6 CI verification pipeline
├── diagnostics/
│   └── Telemetry-Queries.kql          # Azure Monitor Log Analytics KQL detection rules
├── docs/
│   ├── ADR-001-architectural-decision.md
│   └── RUNBOOK.md                     # L2/L3 Operational Triage & Override Runbook
├── infra/
│   └── main.bicep                     # Azure Landing Zone & Managed Identity IaC
├── src/
│   └── Test-LandingZoneWriteProvenance.ps1              # Production PowerShell 7 policy evaluator
├── tests/
│   └── Boundary-Verification.Tests.ps1 # 16-Test Deterministic Pester Matrix
├── LICENSE                            # MIT License
└── README.md                          # Architecture documentation
```

## Quickstart & Local Verification

```powershell
# Execute the 16-test Pester verification contract offline
Invoke-Pester -Path ./tests/Boundary-Verification.Tests.ps1 -Output Detailed
```
