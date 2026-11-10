# ADR-001: Differentiating Security Drift vs Operational Capacity Hotfixes

- **High-Risk Perimeter Drift**: Auto-reverted within 90s unless tagged with an active P1 Incident Bridge ID.
- **Capacity/SKU Drift**: Decompiled to Bicep and submitted as an automated GitOps Pull Request.
