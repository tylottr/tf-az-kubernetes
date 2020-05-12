# Terraform: Azure Kubernetes

This template will create a Kubernetes environment and bootstrap it so it is ready for use.

The environment deployed contains the following resources:

- If using AAD Integration, a Cluster-Admin and Cluster-Viewer AD group will be created that are then mapped to the cluster internally.
- A resource group to contain your AKS resources. This will be omitted if you use your own resource group.
- *(Optional)* An Azure Container Registry that is automatically allowing the cluster access to it.
- *(Optional)* A Log Analytics Workspace configured to pull in AKS Diagnostics, as well as internal logs and events
- An AKS Cluster with a single node pool
    - *(Optional)* Calico or Azure Network Policy
    - *(Optional)* This can be integrated with an existing Subnet
- Storage Classes for Azure Disk and Azure File storage types
- Roles allowing OMS access and AAD Group access
- The Nginx Ingress Controller with default values

Following deployment there are some additional steps that need to be performed that are specific to the application - see the Post Deployment section.

## Prerequisites

Prior to deployment you need the following:

* [terraform](https://www.terraform.io/) - 0.12
* [azcli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [helm](https://helm.sh/)

In Azure, you also need:
* A user account or service policy with Contributor level access to the target subscription and the Group Administrator AAD role
* If using AAD RBAC Integration, you also require a Client and Server component. See [here](https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration-cli) for the steps
    * For viewing live data, also consult [this](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-livedata-setup) page

## Variables

These are the variables used along with their defaults. For any without a value in default, the value must be filled in unless otherwise sateted otherwise the deployment will encounter failures.

**Global Variables**

|Variable|Description|Default Value|
|-|-|-|
|tenant_id|The tenant id of this deployment|`null`|
|subscription_id|The subscription id of this deployment|`null`|
|client_id|The client id used to authenticate to Azure|`null`|
|client_secret|The client secret used to authenticate to Azure|`null`|
|location|The location of this deployment|`"UK South"`|
|resource_group_name|The name of an existing resource group - this will override the creation of a new resource group|`""`|
|resource_prefix|A prefix for the name of the resource, used to generate the resource names||
|tags|Tags given to the resources created by this template|`{}`|

**Resource-Specific Variables**

|Variable|Description|Default Value|
|-|-|-|
|enable_acr|Flag used to enable ACR|`false`|
|acr_sku|SKU of the ACR|`"Basic"`|
|acr_georeplication_locations|Georeplication locations for ACR (Premium tier required)|`[]`|
|enable_acr_admin|Flag used to enable ACR Admin|`false`|
|aks_kubernetes_version|Version of Kubernetes to use in the cluster|`null`|
|enable_aks_oms_monitoring|Flag used to enable Log Analytics|`false`|
|enable_aks_aad_rbac|Flag used to enable AAD RBAC Integration|`false`|
|aks_aad_tenant_id|Tenant ID used for AAD RBAC (defaults to current tenant)|`null`|
|aks_aad_client_app_id|App ID of the client application used for AAD RBAC|`null`|
|aks_aad_server_app_id|App ID of the server application used for AAD RBAC|`null`|
|aks_aad_server_app_secret|App Secret of the server application used for AAD RBAC|`null`|
|enable_aks_calico|Flag used to enable Calico CNI (Ignored if enable_aks_advanced_networking is true)|`false`|
|enable_aks_advanced_networking|Flag used to enable Azure CNI|`false`|
|aks_subnet_name|Name of the subnet for Azure CNI (Ignored if enable_aks_advanced_networking is false)|`null`|
|aks_subnet_vnet_name|Name of the aks_subnet_name's VNet for Azure CNI (Ignored if enable_aks_advanced_networking is false)|`null`|
|aks_subnet_vnet_resource_group_name|Name of the resource group for aks_subnet_vnet_name for Azure CNI (Ignored if enable_aks_advanced_networking is false)|`null`|
|aks_service_cidr|Service CIDR for AKS|`"10.0.0.0/16"`|
|aks_node_size|Size of nodes in the AKS cluster|`"Standard_B2ms"`|
|aks_node_disk_size|Disk size of nodes in the AKS cluster (Minimum 30)|`127`|
|aks_node_min_count|Minimum number of nodes in the AKS cluster|`1`|
|aks_node_max_count|Maximum number of nodes in the AKS cluster|`1`|
|aks_nginx_ingress_values_file|Path to a custom values file used to deploy Nginx Ingress|`""`|
|aks_nginx_ingress_chart_version|The chart version for the nginx-ingress Helm chart|`"1.29.2"`|

## Outputs

This template will output the following information:

|Output|Description|
|-|-|
|aks_id|Resource ID of the AKS Cluster|
|aks_name|Name of the AKS Cluster|
|aks_resource_group_name|Name of the AKS Cluster Resource Group|
|aks_node_resource_group_name|Name of the AKS Cluster Resource Group|
|aks_principal_id|Principal ID of the AKS Cluster identity|
|aks_kubeconfig|Kubeconfig for the AKS Cluster|
|aks_ad_groups|Provides details of the AAD groups used for accessing and managing the AKS Cluster|
|container_registry_id|Resource ID of the container registry|
|container_registry_name|Name of the container registry|

## Deployment

Below describes the steps to deploy this template.

1. Set variables for the deployment
    * Terraform has a number of ways to set variables. See [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables) for more information.
2. Log into Azure with `az login` and set your subscription with `az account set --subscription='<REPLACE_WITH_SUBSCRIPTION_ID_OR_NAME>'`
    * Terraform has a number of ways to authenticate. See [here](https://www.terraform.io/docs/providers/azurerm/guides/azure_cli.html) for more information.
3. Initialise Terraform with `terraform init`
    * By default, state is stored locally. State can be stored in different backends. See [here](https://www.terraform.io/docs/backends/types/index.html) for more information.
4. Set the workspace with `terraform workspace select <REPLACE_WITH_ENVIRONMENT>`
    * If the workspace does not exist, use `terraform workspace new <REPLACE_WITH_ENVIRONMENT>`
5. Generate a plan with `terraform plan -out tf.plan`
6. If the plan passes, apply it with `terraform apply tf.plan`

In the event the deployment needs to be destroyed, you can run `terraform destroy` in place of steps 5 and 6.

## Known Issues

**Provider produced inconsistent final plan on first Apply** with `azurerm_monitor_diagnostic_setting.main_aks[0]` is related to https://github.com/terraform-providers/terraform-provider-azurerm/issues/6254

## Post-Deployment

### Connecting to the Cluster

You can connect to your new cluster using the following command: `az aks get-credentials --name <REPLACE_WITH_CLUSTER_NAME> --resource-group <REPLACE_WITH_CLUSTER_RESOURCE_GROUP>`

- If using AAD RBAC integration you must be in one of the created AD groups to properly authenticate.

### Adding users to AD Groups

To add users to the AD groups you can either do this in-portal or through command-line. To do this with Azure CLI:

1. Get the object ID of the needed group with `terraform output aks_cluster_groups`
2. Add the user to the group with `az ad group member add --group <REPLACE_WITH_GROUP_OBJECT_ID> --member-id <REPLACE_WITH_GROUP_MEMBER_OBJECT_ID>`
    * To get the current user's object ID you can run `az ad signed-in-user show --output tsv --query objectId`

### Kubernetes Setup

Following deployment there are some resources within the cluster that need to be deployed separate to the Terraform deployment. These steps will not be tracked by Terraform itself.

Additional Kubernetes configuration files can be found under the [files/kubernetes/manifests](./files/kubernetes/manifests) directory.

#### Certificates

Certificates are handled by cert-manager to provide valid SSL certificates, which can optionally be deployed with the template. They utilise two main components: The Issuer, and the Certificate. The configuration file bases provided in this repository can be used to set up some basics.

* The Issuer can be namespaced (Issuer) or cluster-wide (ClusterIssuer)
* Certificates are namespaced
    * Certificates can support multiple names, assuming DNS is configured properly

Manifests under [files/kubernetes/manifests/cert-manager](./files/kubernetes/manifests/cert-manager) can be used as a guideline assuming DNS is set up for the endpoint.

To update the certificate you can use the following snippet to convert a certificate's Issuer

```bash
kubectl patch certificate www.example.com-cert --type=merge --patch='{"spec":{"issuerRef":{"name":"letsencrypt-prod"}}}'
```

#### Rbac Roles

Additional RBAC roles can be created for the cluster.

Manifests under [files/kubernetes/manifests/rbac](./files/kubernetes/manifests/rbac) can be used as a guideline or as-is with a cluster-admin and read-only role already in the folder.

#### Helm Charts

Additional values for some Helm charts have been stored under [files/kubernetes/helm/values](./files/kubernetes/helm/values) to provide some additional options for services to deploy to the cluster.

These charts include Cert Manager, Grafana, Prometheus and Loki

## Maintenance

As the cluster requires and has components managed by AKS, you will need to occasionally update secrets to ensure the cluster is still healthy. This can be managed with azcli.

To update the AAD Service Principal, run the following command

```bash
az aks update-credentials --name <REPLACE_WITH_CLUSTER_NAME> --resource-group <REPLACE_WITH_CLUSTER_RESOURCE_GROUP> \
    --reset-aad \
    --aad-client-app-id <REPLACE_WITH_CLUSTER_AAD_CLIENT_APP_ID> \
    --aad-server-app-id <REPLACE_WITH_CLUSTER_AAD_SERVER_APP_ID> \
    --aad-server-app-secret <REPLACE_WITH_CLUSTER_AAD_SERVER_APP_SECRET>
```
