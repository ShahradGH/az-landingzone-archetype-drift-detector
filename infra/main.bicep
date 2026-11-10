param location string = resourceGroup().location
module hub './modules/hub-network.bicep' = {
  name: 'deploy-hub-network'
  params: { location: location }
}
