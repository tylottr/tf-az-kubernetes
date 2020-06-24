######################
# AKS Cluster Details
######################
output "aks_id" {
  description = "Resource ID of the AKS Cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_name" {
  description = "Name of the AKS Cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_resource_group_name" {
  description = "Name of the AKS Cluster Resource Group"
  value       = azurerm_kubernetes_cluster.main.resource_group_name
}

output "aks_node_resource_group_name" {
  description = "Name of the AKS Cluster Resource Group"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "aks_principal_id" {
  description = "Principal ID of the AKS Cluster identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

output "aks_kubeconfig" {
  description = "Kubeconfig for the AKS Cluster"
  value       = local.kubeconfig.aks_config
  sensitive   = true
}

########################
# AKS Cluster AD Groups
########################
output "aks_ad_groups" {
  description = "Provides details of the AAD groups used for accessing and managing the AKS Cluster"
  value = length(local.aad_kubernetes_groups) > 0 ? {
    for group, role in local.aad_kubernetes_groups :
    role => {
      name            = azuread_group.main[group].name
      object_id       = azuread_group.main[group].object_id
      kubernetes_role = role
    }
  } : null
}

#####################
# Container Registry
#####################
output "container_registry_id" {
  description = "Resource ID of the container registry"
  value       = var.enable_acr ? azurerm_container_registry.main[0].id : null
}

output "container_registry_name" {
  description = "Name of the container registry"
  value       = var.enable_acr ? azurerm_container_registry.main[0].name : null
}

output "container_registry_admin_user" {
  description = "Admin user for the container registry"
  value       = var.enable_acr_admin ? azurerm_container_registry.main[0].admin_username : null
  sensitive   = true
}

output "conainer_registry_admin_password" {
  description = "Admin password for the container registry"
  value       = var.enable_acr_admin ? azurerm_container_registry.main[0].admin_password : null
  sensitive   = true
}
