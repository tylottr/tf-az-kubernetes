output "aks_cluster" {
  description = "Provides details of the AKS Cluster"
  value = {
    resource_id         = azurerm_kubernetes_cluster.main.id
    name                = azurerm_kubernetes_cluster.main.name
    resource_group      = azurerm_kubernetes_cluster.main.resource_group_name
    node_resource_group = azurerm_kubernetes_cluster.main.node_resource_group

    service_principal_application_id = azuread_service_principal.main_aks.application_id
    service_principal_object_id      = azuread_service_principal.main_aks.object_id

    managed_identity_id = azurerm_kubernetes_cluster.main.identity[0].principal_id
  }
}

output "aks_cluster_groups" {
  description = "Provides details of the AAD groups used for accessing and managing the AKS Cluster"
  value = {
    for group, role in local.aad_kubernetes_groups :
    azuread_group.main[group].name => {
      object_id       = azuread_group.main[group].object_id
      kubernetes_role = role
    }
  }
}

output "container_registry" {
  description = "Provides details of the Container Registry"
  value = var.enable_acr ? {
    name        = azurerm_container_registry.main[0].name
    resource_id = azurerm_container_registry.main[0].id
  } : null
}
