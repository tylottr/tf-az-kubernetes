# Config
terraform {
  required_version = ">= 0.12.24"
}

# Providers
provider "azurerm" {
  version = "~> 2.9.0"

  features {}

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  client_id     = var.client_id
  client_secret = var.client_secret
}

provider "azuread" {
  version = "~> 0.8.0"

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  client_id     = var.client_id
  client_secret = var.client_secret
}

locals {
  kubeconfig = {
    aks_config = var.enable_aks_aad_rbac ? azurerm_kubernetes_cluster.main.kube_admin_config_raw : azurerm_kubernetes_cluster.main.kube_config_raw

    host = "${
      var.enable_aks_aad_rbac
      ? azurerm_kubernetes_cluster.main.kube_admin_config[0].host
      : azurerm_kubernetes_cluster.main.kube_config[0].host
    }"

    cluster_ca_certificate = "${
      var.enable_aks_aad_rbac
      ? base64decode(azurerm_kubernetes_cluster.main.kube_admin_config[0].cluster_ca_certificate)
      : base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
    }"

    client_certificate = "${
      var.enable_aks_aad_rbac
      ? base64decode(azurerm_kubernetes_cluster.main.kube_admin_config[0].client_certificate)
      : base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
    }"

    client_key = "${
      var.enable_aks_aad_rbac
      ? base64decode(azurerm_kubernetes_cluster.main.kube_admin_config[0].client_key)
      : base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
    }"
  }
}

provider "kubernetes" {
  version = "~> 1.11.2"

  load_config_file = false

  host                   = local.kubeconfig.host
  cluster_ca_certificate = local.kubeconfig.cluster_ca_certificate

  client_certificate = local.kubeconfig.client_certificate
  client_key         = local.kubeconfig.client_key
}

provider "helm" {
  version = "~> 1.1.1"

  kubernetes {
    load_config_file = false

    host                   = local.kubeconfig.host
    cluster_ca_certificate = local.kubeconfig.cluster_ca_certificate

    client_certificate = local.kubeconfig.client_certificate
    client_key         = local.kubeconfig.client_key
  }
}
