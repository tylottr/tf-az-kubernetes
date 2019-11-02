rbac:
  create: true
replicaCount: 1
azureTenantID: ${azure_tenant_id}
azureSubscriptionID: ${azure_subscription_id}
azureResourceGroup: ${azure_resource_group}
azureClusterName: ${azure_cluster_name}
azureNodeResourceGroup: ${azure_node_resource_group}
azureVMType: AKS
cloudProvider: azure
azureClientID: ${azure_client_id}
azureClientSecret: '${azure_client_secret}'
autoscalingGroups:
- minSize: ${node_group_min_size}
  maxSize: ${node_group_max_size}
  name: ${node_group_name}
resources:
  limits:
    cpu: 50m
    memory: 128Mi
  requests:
    cpu: 10m
    memory: 64Mi
