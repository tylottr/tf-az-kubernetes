output "aks_cluster" {
  description = "Provides details of the AKS Cluster"
  value = {
    name                = azurerm_kubernetes_cluster.main.name
    resource_group      = azurerm_kubernetes_cluster.main.resource_group_name
    node_resource_group = azurerm_kubernetes_cluster.main.node_resource_group

    service_principal_application_id = data.azuread_service_principal.main_aks.application_id
    service_principal_object_id      = data.azuread_service_principal.main_aks.object_id
  }
}

output "container_registry" {
  description = "Provides details of the Container Registry"
  value = var.enable_acr ? {
    name        = azurerm_container_registry.main[0].name
    resource_id = azurerm_container_registry.main[0].id
  } : null
}