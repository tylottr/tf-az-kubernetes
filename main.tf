# Data
data "azurerm_client_config" "current" {}

resource "random_integer" "entropy" {
  min = 0
  max = 99
}

resource "tls_private_key" "main" {
  algorithm = "RSA"
}

resource "local_file" "main_ssh_public" {
  filename          = ".terraform/.kube/clusters/${azurerm_kubernetes_cluster.main.name}.id_rsa.pub"
  sensitive_content = tls_private_key.main.public_key_openssh
}

resource "local_file" "main_ssh_private" {
  filename          = ".terraform/.kube/clusters/${azurerm_kubernetes_cluster.main.name}.id_rsa"
  sensitive_content = tls_private_key.main.private_key_pem
  file_permission   = "0600"
}

# Resources
## Azure RBAC
locals {
  // Using a map to split the actual inbuilt role name from the intended name
  aad_basic_groups = {
    Readers      = "Reader"
    Contributors = "Contributor"
    Owners       = "Owner"
  }

  aad_aks_groups = {
    "Cluster Admins" = "Azure Kubernetes Service Cluster Admin Role"
    "Cluster Users"  = "Azure Kubernetes Service Cluster User Role"
  }

  aad_groups = merge(
    local.aad_basic_groups,
    local.aad_aks_groups
  )
}

resource "azuread_group" "main_aad_rbac" {
  for_each = local.aad_groups

  name = "${var.resource_prefix}-aks ${each.key}"
}

## Azure Kubernetes
### Azure AD Service Principal for Kubernetes
resource "azuread_application" "main_aks" {
  name                       = "${var.resource_prefix}-aks"
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = false
  homepage                   = "https://${var.resource_prefix}-aks"
}

resource "random_password" "main_aks_secret" {
  length = 40
}

resource "azuread_application_password" "main_aks" {
  application_object_id = azuread_application.main_aks.id
  value                 = random_password.main_aks_secret.result
  end_date_relative     = "43800h" # 5 years
}

resource "azuread_service_principal" "main_aks" {
  application_id = azuread_application.main_aks.application_id

  provisioner "local-exec" {
    /* This will fail on Windows, due to the lack of sleep command.
     * It may cause the template to fail due to the provider - in
     * which case, re-run the Apply command.
     **
    */
    on_failure = continue
    command    = "sleep 45"
  }
}

## Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.resource_prefix}-aks-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_role_assignment" "main_aad_rbac_basic" {
  for_each = local.aad_basic_groups

  scope                = azurerm_resource_group.main.id
  role_definition_name = each.value
  principal_id         = azuread_group.main_aad_rbac[each.key].id
}

## Storage
resource "azurerm_container_registry" "main" {
  count = var.enable_acr ? 1 : 0

  name                = lower(replace("${var.resource_prefix}${random_integer.entropy.result}acr", "/[-_]/", ""))
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  sku           = var.acr_sku
  admin_enabled = false
}

resource "azurerm_role_assignment" "main_acr_pull" {
  count = var.enable_acr ? 1 : 0

  principal_id         = azuread_service_principal.main_aks.id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.main[count.index].id
}

## Monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.resource_prefix}-aks-oms"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  sku = "PerGB2018"
}

## Kubernetes Compute (Azure-level)
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.resource_prefix}-aks"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  service_principal {
    client_id     = azuread_service_principal.main_aks.application_id
    client_secret = azuread_application_password.main_aks.value
  }

  kubernetes_version = var.aks_cluster_kubernetes_version

  dns_prefix          = "${var.resource_prefix}-aks"
  node_resource_group = "${var.resource_prefix}-aks-node-rg"

  api_server_authorized_ip_ranges = ["0.0.0.0/0"]

  role_based_access_control {
    enabled = true

    dynamic azure_active_directory {
      /*
       * Check for prereqs. If not satisfied, pass an empty set, forcing
       * this dynamic block to not be set.
       **
      */
      for_each = local.aad_rbac_prerequisites_satisfied ? [true] : []

      content {
        tenant_id         = data.azurerm_client_config.current.tenant_id
        client_app_id     = var.cluster_aad_client_app_id
        server_app_id     = var.cluster_aad_server_app_id
        server_app_secret = var.cluster_aad_server_app_secret
      }
    }
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "Standard"

    pod_cidr = "10.244.0.0/16"

    network_policy     = null
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = "10.0.0.0/16"
    dns_service_ip     = "10.0.0.10"
  }

  linux_profile {
    admin_username = "vmadmin"
    ssh_key {
      key_data = tls_private_key.main.public_key_openssh
    }
  }

  default_node_pool {
    name                  = "default"
    type                  = "VirtualMachineScaleSets"
    enable_auto_scaling   = true
    enable_node_public_ip = false

    vm_size         = var.aks_cluster_worker_size
    os_disk_size_gb = var.aks_cluster_worker_disk_size
    node_count      = var.aks_cluster_worker_min_count
    min_count       = var.aks_cluster_worker_min_count
    max_count       = var.aks_cluster_worker_max_count

    vnet_subnet_id = null
  }

  addon_profile {
    kube_dashboard {
      enabled = true
    }

    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
    }
  }

  lifecycle {
    ignore_changes = [
      default_node_pool,
      kubernetes_version
    ]
  }
}

resource "local_file" "main_aks_config" {
  filename        = ".terraform/.kube/clusters/${azurerm_kubernetes_cluster.main.name}"
  file_permission = "0600"

  sensitive_content = "${
    local.aad_rbac_prerequisites_satisfied
    ? azurerm_kubernetes_cluster.main.kube_admin_config_raw
    : azurerm_kubernetes_cluster.main.kube_config_raw
  }"
}

resource "azurerm_role_assignment" "main_aad_rbac_aks" {
  for_each = local.aad_aks_groups

  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = each.value
  principal_id         = azuread_group.main_aad_rbac[each.key].id
}

## Kubernetes Compute Environment (Kubernetes-level) - Helm
### Helm setup
resource "kubernetes_service_account" "main_helm_tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "main_helm_tiller" {
  metadata {
    name = "tiller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.main_helm_tiller.metadata[0].name
    namespace = kubernetes_service_account.main_helm_tiller.metadata[0].namespace
  }
}

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

### Cluster Utilities
resource "helm_release" "main_ingress" {
  name = "nginx-ingress"

  repository = data.helm_repository.stable.metadata[0].name
  chart      = "nginx-ingress"
  version    = var.aks_cluster_nginx_ingress_chart_version
  namespace  = "kube-system"

  values = [
    templatefile("${path.module}/templates/kubernetes/helm/values/nginx-ingress.yaml.tpl", {})
  ]

  timeout = 600

  depends_on = [kubernetes_cluster_role_binding.main_helm_tiller]
}

resource "helm_release" "main_cert_manager" {
  name = "cert-manager"

  repository = data.helm_repository.jetstack.metadata[0].name
  chart      = "cert-manager"
  version    = var.aks_cluster_cert_manager_chart_version
  namespace  = "kube-system"

  values = [
    templatefile("${path.module}/templates/kubernetes/helm/values/cert-manager.yaml.tpl", {})
  ]

  provisioner "local-exec" {
    command = <<EOF
kubectl apply --kubeconfig ${local_file.main_aks_config.filename} -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.11/deploy/manifests/00-crds.yaml --validate=false
EOF
  }

  timeout = 600

  depends_on = [kubernetes_cluster_role_binding.main_helm_tiller]
}

## Kubernetes Compute Environment (Kubernetes-level) - Storage
resource "kubernetes_storage_class" "main_azure_disk" {
  // Default storage classes do not expand. Create these in the cluster as part of the deployment.
  for_each = {
    "azure-disk-standard" = "Standard_LRS"
    "azure-disk-premium"  = "Premium_LRS"
  }

  metadata {
    name = each.key

    labels = {
      "kubernetes.io/cluster-service" = "true"
    }
  }

  storage_provisioner    = "kubernetes.io/azure-disk"
  reclaim_policy         = "Delete"
  allow_volume_expansion = "true"

  parameters = {
    kind               = "managed"
    storageaccounttype = each.value
  }
}

resource "kubernetes_storage_class" "main_azure_file" {
  // Default storage classes do not expand. Create these in the cluster as part of the deployment.
  for_each = {
    "azure-file-standard-lrs"   = "Standard_LRS"
    "azure-file-standard-grs"   = "Standard_GRS"
    "azure-file-standard-ragrs" = "Standard_RAGRS"
    "azure-file-premium-lrs"    = "Premium_LRS"
  }

  metadata {
    name = each.key

    labels = {
      "kubernetes.io/cluster-service" = "true"
    }
  }

  storage_provisioner    = "kubernetes.io/azure-file"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = "true"

  parameters = {
    skuname = each.value
  }
}

## Kubernetes RBAC
### Dashboard
resource "kubernetes_cluster_role_binding" "main_dashboard_view" {
  metadata {
    name = "kubernetes-dashboard"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "kubernetes-dashboard"
    namespace = "kube-system"
  }
}