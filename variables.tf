### Variables ###
## Global ##
variable "location" {
  description = "The location of this deployment"
  type        = string
  default     = "UK South"
}

variable "environment_prefix" {
  description = "A prefix for the environment this resource belongs in, used to generate the resource names"
  type        = string
  default     = ""
}

variable "resource_prefix" {
  description = "A prefix for the name of the resource, used to generate the resource names"
  type        = string
  default     = "Kubernetes"
}

variable "tag_owner" {
  description = "Sets the value of this tag"
  type        = string
  default     = "Terraform"
}

variable "tag_environment" {
  description = "Sets the value of this tag"
  type        = string
  default     = "Test"
}

variable "tag_application" {
  description = "Sets the value of this tag"
  type        = string
  default     = "Kubernetes"
}

variable "tag_criticality" {
  description = "Sets the value of this tag"
  type        = string
  default     = "3"
}

variable "service_policy_password_expiry" {
  description = "The amount of time for a service policy passwords to be valid"
  type        = string
  default     = "43800h" # 5 Years
}

## Resource-specific ##
# Azure Container Registry #
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

# AKS Cluster #
# Azure-level
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
  default     = 30
}

# K8s-level
variable "aks_cluster_custom_backend_service" {
  description = "The custom backend service in the format NAMESPACE/SERVICE"
  type        = string
  default     = ""
}

variable "aks_cluster_nginx_ingress_chart_version" {
  description = "The chart version for the nginx-ingress Helm chart"
  type        = string
  default     = "1.14.0"
}

variable "aks_cluster_cluster_autoscaler_chart_version" {
  description = "The chart version for the cluster-autoscaler Helm chart"
  type        = string
  default     = "3.2.0"
}

variable "aks_cluster_enable_cert_manager" {
  description = "Flag used to enable cert-manager"
  type        = bool
  default     = true
}

variable "aks_cluster_cert_manager_chart_version" {
  description = "The chart version for the cert-manager Helm chart"
  type        = string
  default     = "v0.9.1"
}

## Locals ##
locals {
  resource_name = var.environment_prefix != "" ? "${lower(var.environment_prefix)}-${lower(var.resource_prefix)}" : lower(var.resource_prefix)

  tags = {
    "Owner"       = var.tag_owner
    "Environment" = var.tag_environment
    "Application" = var.tag_application
    "Criticality" = var.tag_criticality
  }
}