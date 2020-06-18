#########
# Config
#########
terraform {
  required_version = ">= 0.12.24"

  required_providers {
    azurerm    = "~> 2.13"
    azuread    = "~> 0.10"
    kubernetes = "~> 1.11"
    helm       = "~> 1.2"
  }
}

############
# Providers
############
provider "azurerm" {
  features {}

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  client_id     = var.client_id
  client_secret = var.client_secret
}

provider "azuread" {
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
  load_config_file = false

  host                   = local.kubeconfig.host
  cluster_ca_certificate = local.kubeconfig.cluster_ca_certificate

  client_certificate = local.kubeconfig.client_certificate
  client_key         = local.kubeconfig.client_key
}

provider "helm" {
  kubernetes {
    load_config_file = false

    host                   = local.kubeconfig.host
    cluster_ca_certificate = local.kubeconfig.cluster_ca_certificate

    client_certificate = local.kubeconfig.client_certificate
    client_key         = local.kubeconfig.client_key
  }
}
