rbac:
  create: true
replicaCount: 1
azureTenantID: ${azureTenantID}
azureSubscriptionID: ${azureSubscriptionID}
azureResourceGroup: ${azureResourceGroup}
azureClusterName: ${azureClusterName}
azureNodeResourceGroup: ${azureNodeResourceGroup}
azureVMType: AKS
cloudProvider: azure
azureClientID: ${azureClientID}
azureClientSecret: '${azureClientSecret}'
autoscalingGroups:
- maxSize: ${nodeGroupMaxSize}
  minSize: ${nodeGroupMinSize}
  name: ${nodeGroupName}
resources:
  limits:
    cpu: 50m
    memory: 128Mi
  requests:
    cpu: 10m
    memory: 64Mi
