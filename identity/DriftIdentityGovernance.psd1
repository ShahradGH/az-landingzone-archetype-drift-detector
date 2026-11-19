@{
    RootModule        = 'DriftIdentityGovernance.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '11111111-2222-3333-4444-555555550003'
    Author            = 'ShahradGH'
    CompanyName       = 'Independent Architecture'
    Copyright         = '(c) ShahradGH. MIT License.'
    Description       = 'Microsoft Graph v2.x Entra ID caller resolution, PIM activation verification, and Landing Zone drift governance escalations.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Resolve-DriftCallerPrincipal',
        'Test-BreakGlassPimActivation',
        'Send-DriftGovernanceEscalation'
    )
}
