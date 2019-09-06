# Data
data "azurerm_client_config" "main" {
}

resource "random_integer" "main" {
  min = 0
  max = 9999
}

# Resources
## Azure Kubernetes
### Azure AD Service Principal for Kubernetes
resource "azuread_application" "main" {
  name                       = "${var.tag_environment} ${var.tag_application} Kubernetes"
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = false
  homepage                   = "https://${local.resource_name}-aks"
}

resource "azuread_service_principal" "main" {
  application_id = azuread_application.main.application_id

  provisioner "local-exec" {
    command = "sleep 30"
  }
}

resource "random_string" "main_secret" {
  length = 40
}

resource "azuread_service_principal_password" "main" {
  service_principal_id = azuread_service_principal.main.id
  value                = random_string.main_secret.result
  end_date_relative    = var.service_policy_password_expiry

  provisioner "local-exec" {
    command = "sleep 30"
  }
}

## Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${local.resource_name}-aks-rg"
  location = var.location
  tags     = local.tags
}

## Storage
resource "azurerm_container_registry" "main" {
  count = var.enable_acr ? 1 : 0
  name = replace(
    "${local.resource_name}acr${random_integer.main.result}",
    "-",
    "",
  )
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  sku           = var.acr_sku
  admin_enabled = false
}

## Kubernetes Role Assignments
resource "azurerm_role_assignment" "main_acr" {
  count                = var.enable_acr ? 1 : 0
  scope                = azurerm_container_registry.main[count.index].id
  role_definition_name = "AcrPull"
  principal_id         = azuread_service_principal.main.id
}

resource "azurerm_role_assignment" "main_management" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.main.id
}

## Kubernetes Compute (Azure-level)
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${local.resource_name}-aks"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  agent_pool_profile {
    name            = "nodepool1"
    count           = var.aks_cluster_worker_min_count
    vm_size         = var.aks_cluster_worker_size
    os_disk_size_gb = var.aks_cluster_worker_disk_size
    os_type         = "Linux"
  }

  dns_prefix = "${local.resource_name}-aks"

  network_profile {
    network_plugin     = "kubenet"
    service_cidr       = "10.0.0.0/16"
    dns_service_ip     = "10.0.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  service_principal {
    client_id     = azuread_service_principal.main.application_id
    client_secret = azuread_service_principal_password.main.value
  }

  role_based_access_control {
    enabled = true
  }

  lifecycle {
    ignore_changes = [agent_pool_profile[0].count]
  }
}

resource "local_file" "main_config" {
  filename          = ".terraform/.kube/clusters/${azurerm_kubernetes_cluster.main.name}"
  sensitive_content = azurerm_kubernetes_cluster.main.kube_config_raw
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
    <<EOF
rbac:
  create: true
controller:
  replicaCount: 2
  metrics:
    enabled: true
    service:
      annotations:
        prometheus.io/scrape: "true"
  config:
    enable-modsecurity: "true"
    enable-owasp-modsecurity-crs: "true"
  defaultBackendService: ${var.aks_cluster_custom_backend_service != "" ? var.aks_cluster_custom_backend_service : ""}
  resources:
    limits:
      cpu: 500m
      memory: 768Mi
    requests:
      cpu: 200m
      memory: 512Mi
  autoscaling:
    enabled: true
    maxReplicas: 5
    minReplicas: 2
    targetCPUUtilizationPercentage: 75
    targetMemoryUtilizationPercentage: 75
defaultBackend:
  enabled: ${var.aks_cluster_custom_backend_service != "" ? "false" : "true"}
    EOF
  ]

  depends_on = [kubernetes_cluster_role_binding.main_helm_tiller]
}

resource "helm_release" "main_autoscaler" {
  name = "cluster-autoscaler"

  repository = data.helm_repository.stable.metadata[0].name
  chart      = "cluster-autoscaler"
  version    = var.aks_cluster_cluster_autoscaler_chart_version
  namespace  = "kube-system"

  values = [
    <<EOF
rbac:
  create: true
autoscalingGroups:
- maxSize: ${var.aks_cluster_worker_max_count}
  minSize: ${var.aks_cluster_worker_min_count}
  name: ${azurerm_kubernetes_cluster.main.agent_pool_profile[0].name}
azureClientID: ${azuread_application.main.application_id}
azureClientSecret: '${azuread_service_principal_password.main.value}'
azureClusterName: ${azurerm_kubernetes_cluster.main.name}
azureNodeResourceGroup: ${azurerm_kubernetes_cluster.main.node_resource_group}
azureResourceGroup: ${azurerm_resource_group.main.name}
azureSubscriptionID: ${data.azurerm_client_config.main.subscription_id}
azureTenantID: ${data.azurerm_client_config.main.tenant_id}
azureVMType: AKS
cloudProvider: azure
resources:
  limits:
    cpu: 50m
    memory: 128Mi
  requests:
    cpu: 10m
    memory: 64Mi
EOF
  ]

  depends_on = [kubernetes_cluster_role_binding.main_helm_tiller]
}

resource "helm_release" "main_cert_manager" {
  count = var.aks_cluster_enable_cert_manager ? 1 : 0
  name  = "cert-manager"

  repository = data.helm_repository.jetstack.metadata[0].name
  chart      = "cert-manager"
  version    = var.aks_cluster_cert_manager_chart_version
  namespace  = "kube-system"

  values = [
    <<EOF
global:
  rbac:
    create: true
resources:
  limits:
    cpu: 20m
    memory: 64Mi
  requests:
    cpu: 10m
    memory: 32Mi
webhook:
  enabled: false
cainjector:
  enabled: false
EOF
  ]

  provisioner "local-exec" {
    command = <<EOS
kubectl apply --kubeconfig .terraform/.kube/clusters/${azurerm_kubernetes_cluster.main.name} -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.9/deploy/manifests/00-crds.yaml
EOS
  }

  depends_on = [kubernetes_cluster_role_binding.main_helm_tiller]
}

## Kubernetes Compute Environment (Kubernetes-level) - Storage
resource "kubernetes_storage_class" "main_azure" {
  // Default storage classes do not expand. Create these in the cluster as part of the deployment.
  for_each = {
    "azure-standard" = "Standard_LRS"
    "azure-premium"  = "Premium_LRS"
  }

  metadata {
    name = each.key

    labels = {
      "kubernetes.io/cluster-service" = "true"
    }
  }

  storage_provisioner    = "kubernetes.io/azure-disk"
  allow_volume_expansion = "true"
  reclaim_policy         = "Delete"

  parameters = {
    kind               = "managed"
    storageaccounttype = each.value
  }
}

## Kubernetes Service Accounts
### Full Access
resource "kubernetes_service_account" "main_full_access" {
  metadata {
    name      = "cluster-full-access"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "main_full_access" {
  metadata {
    name = "cluster-full-access"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.main_full_access.metadata[0].name
    namespace = kubernetes_service_account.main_full_access.metadata[0].namespace
  }
}

### Read Only
resource "kubernetes_service_account" "main_read_only" {
  metadata {
    name      = "cluster-read-only"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "main_read_only" {
  metadata {
    name = "cluster-read-only"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.main_read_only.metadata[0].name
    namespace = kubernetes_service_account.main_read_only.metadata[0].namespace
  }
}