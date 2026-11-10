param location string
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-spoke-baseline'
  location: location
  properties: { securityRules: [] }
}
