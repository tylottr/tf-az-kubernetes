# Config
terraform {
  required_version = ">= 0.12.0"
}

# Providers
provider "azurerm" {
  version = "~> 1.32.0"
}

provider "azuread" {
  version = "~> 0.5.0"
}

provider "kubernetes" {
  version = "~> 1.8.0"
  host    = azurerm_kubernetes_cluster.main.kube_config[0].host
  client_certificate = base64decode(
    azurerm_kubernetes_cluster.main.kube_config[0].client_certificate,
  )
  client_key = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(
    azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate,
  )
}

provider "helm" {
  version = "~> 0.10.0"

  service_account = kubernetes_service_account.main_helm_tiller.metadata[0].name
  kubernetes {
    host = azurerm_kubernetes_cluster.main.kube_config[0].host
    client_certificate = base64decode(
      azurerm_kubernetes_cluster.main.kube_config[0].client_certificate,
    )
    client_key = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(
      azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate,
    )
  }
}

provider "random" {
  version = "~> 2.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.3"
}