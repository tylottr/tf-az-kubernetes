# Global
variable "location" {
  description = "The location of this deployment"
  type        = string
  default     = "UK South"
}

variable "resource_prefix" {
  description = "A prefix for the name of the resource, used to generate the resource names"
  type        = string
  default     = "kubernetes"
}

variable "tags" {
  description = "Tags given to the resources created by this template"
  type        = map(string)
  default     = {}
}

# Resource-specific
## Azure Container Registry
variable "enable_acr" {
  description = "Flag used to enable ACR"
  type        = bool
  default     = true
}

variable "acr_sku" {
  description = "SKU of the ACR"
  type        = string
  default     = "Basic"
}

## AKS Cluster
### Azure-level
variable "aks_cluster_kubernetes_version" {
  description = "Version of Kubernetes to use in the cluster"
  type        = string
  default     = null
}

variable "enable_aad_rbac" {
  description = "Flag to enable AAD RBAC"
  type        = bool
  default     = false
}

variable "cluster_aad_client_app_id" {
  description = "App ID of the client application used for AAD RBAC"
  type        = string
  default     = null
}

variable "cluster_aad_server_app_id" {
  description = "App ID of the server application used for AAD RBAC"
  type        = string
  default     = null
}

variable "cluster_aad_server_app_secret" {
  description = "App Secret of the server application used for AAD RBAC"
  type        = string
  default     = null
}

variable "aks_cluster_worker_min_count" {
  description = "Minimum number of workers in the AKS cluster"
  type        = number
  default     = 1
}

variable "aks_cluster_worker_max_count" {
  description = "Maximum number of workers in the AKS cluster"
  type        = number
  default     = 5
}

variable "aks_cluster_worker_size" {
  description = "Size of workers in the AKS cluster"
  type        = string
  default     = "Standard_B2ms"
}

variable "aks_cluster_worker_disk_size" {
  description = "Disk size of workers in the AKS cluster (Minimum 30)"
  type        = number
  default     = 64
}

### K8s-level
variable "aks_cluster_nginx_ingress_chart_version" {
  description = "The chart version for the nginx-ingress Helm chart"
  type        = string
  default     = "1.24.7"
}

variable "aks_cluster_custom_backend_service" {
  description = "The custom backend service in the format NAMESPACE/SERVICE"
  type        = string
  default     = null
}

variable "aks_cluster_cert_manager_chart_version" {
  description = "The chart version for the cert-manager Helm chart"
  type        = string
  default     = "v0.11.0"
}

# Locals
locals {
  aad_rbac_prerequisites_satisfied = "${
    var.enable_aad_rbac == true &&
    var.cluster_aad_client_app_id != null &&
    var.cluster_aad_server_app_id != null &&
    var.cluster_aad_server_app_secret != null
    ? true
    : false
  }"
}