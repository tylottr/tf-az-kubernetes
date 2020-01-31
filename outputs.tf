output "kubernetes_service_principal" {
  value = data.azuread_service_principal.main_aks.application_id
}

output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "kubernetes_rg_name" {
  value = azurerm_resource_group.main.name
}

output "kubernetes_node_rg_name" {
  value = azurerm_kubernetes_cluster.main.node_resource_group
}

output "acr_name" {
  value = var.enable_acr ? azurerm_container_registry.main[0].name : null
}

output "acr_id" {
  value = var.enable_acr ? azurerm_container_registry.main[0].id : null
}