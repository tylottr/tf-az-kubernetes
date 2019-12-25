# Config
terraform {
  required_version = ">= 0.12"
}

# Providers
provider "azurerm" {
  version = "~> 1.39"

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

provider "azuread" {
  version = "~> 0.7"

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

locals {
  kubeconfig = {
    host = "${
      local.aks_cluster_aad_rbac_prerequisites_satisfied
      ? azurerm_kubernetes_cluster.main.kube_admin_config[0].host
      : azurerm_kubernetes_cluster.main.kube_config[0].host
    }"

    cluster_ca_certificate = "${
      local.aks_cluster_aad_rbac_prerequisites_satisfied
      ? base64decode(azurerm_kubernetes_cluster.main.kube_admin_config[0].cluster_ca_certificate)
      : base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
    }"

    client_certificate = "${
      local.aks_cluster_aad_rbac_prerequisites_satisfied
      ? base64decode(azurerm_kubernetes_cluster.main.kube_admin_config[0].client_certificate)
      : base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
    }"

    client_key = "${
      local.aks_cluster_aad_rbac_prerequisites_satisfied
      ? base64decode(azurerm_kubernetes_cluster.main.kube_admin_config[0].client_key)
      : base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
    }"
  }
}

provider "kubernetes" {
  version = "~> 1.10"

  host                   = local.kubeconfig.host
  cluster_ca_certificate = local.kubeconfig.cluster_ca_certificate

  client_certificate = local.kubeconfig.client_certificate
  client_key         = local.kubeconfig.client_key
}

provider "helm" {
  version = "~> 0.10"

  service_account = kubernetes_service_account.main_helm_tiller.metadata[0].name
  kubernetes {
    host                   = local.kubeconfig.host
    cluster_ca_certificate = local.kubeconfig.cluster_ca_certificate

    client_certificate = local.kubeconfig.client_certificate
    client_key         = local.kubeconfig.client_key
  }
}

provider "random" {
  version = "~> 2.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.4"
}

provider "tls" {
  version = "~> 2.1"
}