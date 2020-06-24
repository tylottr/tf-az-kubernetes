#######
# RBAC
#######
locals {
  aad_kubernetes_groups = var.enable_aks_aad_rbac ? {
    // Pair is { <group name> = <cluster role> }
    "Kubernetes Cluster Admins"  = "cluster-admin"
    "Kubernetes Cluster Viewers" = "view"
  } : {}

  aad_groups = merge(
    local.aad_kubernetes_groups
  )
}

resource "azuread_group" "main" {
  for_each = local.aad_groups

  name = "${local.resource_prefix} ${each.key}"
}

#################
# Resource Group
#################
resource "azurerm_resource_group" "main" {
  count = var.resource_group_name == "" ? 1 : 0

  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name == "" ? azurerm_resource_group.main[0].name : var.resource_group_name
}

#####################
# Container Registry
#####################
resource "azurerm_container_registry" "main" {
  count = var.enable_acr ? 1 : 0

  name                = lower(replace("${local.resource_prefix}acr", "/[-_]/", ""))
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = var.tags

  sku                      = var.acr_sku
  georeplication_locations = length(var.acr_georeplication_locations) < 1 ? null : var.acr_georeplication_locations

  admin_enabled = var.enable_acr_admin
}

resource "azurerm_role_assignment" "main_acr_pull" {
  count = var.enable_acr ? 1 : 0

  scope                = azurerm_container_registry.main[count.index].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

#############
# Monitoring
#############
resource "azurerm_log_analytics_workspace" "main" {
  count = var.enable_aks_oms_monitoring ? 1 : 0

  name                = "${local.resource_prefix}-oms"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = var.tags

  sku               = "PerGB2018"
  retention_in_days = 30
}

resource "azurerm_role_assignment" "main_oms_readers" {
  for_each = var.enable_aks_oms_monitoring ? local.aad_kubernetes_groups : {}

  scope                = azurerm_log_analytics_workspace.main[0].id
  role_definition_name = "Reader"
  principal_id         = azuread_group.main[each.key].id
}

###################################
# Kubernetes Cluster - Azure Level
###################################
data "azurerm_subnet" "main" {
  count = var.enable_aks_advanced_networking ? 1 : 0

  name                 = var.aks_subnet_name
  virtual_network_name = var.aks_subnet_vnet_name
  resource_group_name  = var.aks_subnet_vnet_resource_group_name
}

resource "azurerm_role_assignment" "main_aks_network_contributor" {
  count = var.enable_aks_advanced_networking ? 1 : 0

  scope                = data.azurerm_subnet.main[0].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = local.resource_prefix
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = var.tags

  kubernetes_version = var.aks_kubernetes_version

  dns_prefix = local.resource_prefix

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control {
    enabled = true

    dynamic azure_active_directory {
      /*
       * If enabling RBAC and app settings are not set,
       * an error will be returned. This is by design
       * to avoid accidentally creating a cluster without
       * AAD integration.
       **
      */
      for_each = var.enable_aks_aad_rbac ? [true] : []

      content {
        tenant_id         = var.aks_aad_tenant_id
        client_app_id     = var.aks_aad_client_app_id
        server_app_id     = var.aks_aad_server_app_id
        server_app_secret = var.aks_aad_server_app_secret
      }
    }
  }

  api_server_authorized_ip_ranges = ["0.0.0.0/0"]

  network_profile {
    network_plugin    = var.enable_aks_advanced_networking ? "azure" : "kubenet"
    load_balancer_sku = "Standard"

    pod_cidr = var.enable_aks_advanced_networking ? null : "10.244.0.0/16"

    network_policy     = var.enable_aks_calico ? "calico" : var.enable_aks_advanced_networking ? "azure" : null
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = var.aks_service_cidr
    dns_service_ip     = cidrhost(var.aks_service_cidr, 10)
  }

  default_node_pool {
    name                  = "default"
    type                  = "VirtualMachineScaleSets"
    tags                  = var.tags
    enable_auto_scaling   = true
    enable_node_public_ip = false

    vm_size    = var.aks_node_size
    node_count = var.aks_node_min_count
    min_count  = var.aks_node_min_count
    max_count  = var.aks_node_max_count

    vnet_subnet_id = var.enable_aks_advanced_networking ? data.azurerm_subnet.main[0].id : null
  }

  addon_profile {
    kube_dashboard {
      // Disabling to reduce default resource usage. If needed enable manually via Helm or Azure.
      enabled = false
    }

    oms_agent {
      enabled                    = var.enable_aks_oms_monitoring
      log_analytics_workspace_id = var.enable_aks_oms_monitoring ? azurerm_log_analytics_workspace.main[0].id : null
    }
  }

  lifecycle {
    ignore_changes = [
      default_node_pool,
      kubernetes_version,
      service_principal,
      role_based_access_control,
      addon_profile
    ]
  }
}

resource "azurerm_role_assignment" "main_aks_readers" {
  for_each = local.aad_kubernetes_groups

  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Reader"
  principal_id         = azuread_group.main[each.key].id
}

resource "azurerm_role_assignment" "main_aks_users" {
  for_each = local.aad_kubernetes_groups

  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_group.main[each.key].id
}

data "azurerm_monitor_diagnostic_categories" "main_aks" {
  resource_id = azurerm_kubernetes_cluster.main.id
}

resource "azurerm_monitor_diagnostic_setting" "main_aks" {
  count = var.enable_aks_oms_monitoring ? 1 : 0

  name                       = "${local.resource_prefix}-diag"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  dynamic log {
    for_each = data.azurerm_monitor_diagnostic_categories.main_aks.logs
    iterator = log_category

    content {
      category = log_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 7
      }
    }
  }

  dynamic metric {
    for_each = data.azurerm_monitor_diagnostic_categories.main_aks.metrics
    iterator = metric_category

    content {
      category = metric_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 7
      }
    }
  }
}

#####################################
# Kubernetes Cluster - Cluster-Level
#####################################
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
    cachingmode        = "ReadOnly"
    kind               = "Managed"
    storageaccounttype = each.value
  }
}

resource "kubernetes_storage_class" "main_azure_file" {
  // Default storage classes do not expand. Create these in the cluster as part of the deployment.
  for_each = {
    "azure-file-standard-lrs"   = "Standard_LRS"
    "azure-file-standard-grs"   = "Standard_GRS"
    "azure-file-standard-zrs"   = "Standard_ZRS"
    "azure-file-standard-ragrs" = "Standard_RAGRS"
    "azure-file-premium-lrs"    = "Premium_LRS"
    "azure-file-premium-zrs"    = "Premium_ZRS"
  }

  metadata {
    name = each.key

    labels = {
      "kubernetes.io/cluster-service" = "true"
    }
  }

  storage_provisioner    = "kubernetes.io/azure-file"
  reclaim_policy         = "Delete"
  allow_volume_expansion = "true"

  parameters = {
    skuName = each.value
  }
}

resource "kubernetes_cluster_role" "main_oms_reader" {
  metadata {
    name = "containerHealth-log-reader"
  }

  rule {
    api_groups = ["", "metrics.k8s.io", "extensions", "apps"]
    resources  = ["pods/log", "events", "nodes", "pods", "deployments", "replicasets"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "main_oms_reader" {
  metadata {
    name = "containerHealth-read-logs-global"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.main_oms_reader.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    namespace = "kube-system"
    name      = "clusterUser"
  }
}

resource "kubernetes_cluster_role_binding" "main_aad_groups" {
  for_each = local.aad_kubernetes_groups

  metadata {
    name = replace(azuread_group.main[each.key].name, " ", "-")
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = each.value
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    namespace = "kube-system"
    name      = azuread_group.main[each.key].id
  }
}

resource "helm_release" "main_ingress" {
  name = "nginx-ingress"

  repository = "https://kubernetes-charts.storage.googleapis.com"
  chart      = "nginx-ingress"
  version    = var.aks_nginx_ingress_chart_version
  namespace  = "kube-system"

  values = var.aks_nginx_ingress_values_file == "" ? [
    file("${path.module}/files/kubernetes/helm/values/nginx-ingress.yaml")
  ] : [file(var.aks_nginx_ingress_values_file)]

  wait = false
}
