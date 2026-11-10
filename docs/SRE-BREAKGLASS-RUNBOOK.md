# SRE Break-Glass Portal Change Procedure

When executing an emergency change in the Azure Portal during a P1 outage, apply tag `BreakGlassIncident=INC-P1-XXXXXX` so the drift reconciler generates a backport PR instead of reverting the hotfix.
