output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "kubernetes_rg_name" {
  value = azurerm_resource_group.main.name
}

output "kubernetes_node_rg_name" {
  value = azurerm_kubernetes_cluster.main.node_resource_group
}

output "kubeconfig" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}

output "acr_name" {
  value = azurerm_container_registry.main[0].name
}
