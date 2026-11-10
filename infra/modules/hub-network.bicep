param location string
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-connectivity-hub'
  location: location
  properties: { addressSpace: { addressPrefixes: ['172.16.0.0/16'] } }
}
