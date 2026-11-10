# ADR-001: Landing Zone Governance: Detecting & Reconciling Out-of-Band Azure Portal Drift

## Status
Accepted

## Service Owner & Sign-Off Authority
Lead Cloud Platform Engineer & Landing Zone Architect

## Dominant Artefact
Archetype Drift Detection Watchdog & Re-baselining Pipeline

## Decision & Refusal Boundary
All production state mutations must pass deterministic pre-flight policy evaluation in `src/Test-LandingZoneWriteProvenance.ps1` and satisfy the 16-test Pester verification contract in `tests/Boundary-Verification.Tests.ps1` before execution.
