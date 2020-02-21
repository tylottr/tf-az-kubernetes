# Terraform: Azure Kubernetes

This template will create a Kubernetes environment and bootstrap it so it is ready for use.

The environment deployed contains the following resources:
* A service policy to allow K8s to access the necessary Azure resources
* OPTIONAL: An Azure Container Registry for storing images
* RBAC Groups for in-cluster cluster-admins and viewers
* A bootstrapped Kubernetes cluster 
  * Kubeconfig stored in .terraform/.kube/clusters/your_cluster_name
  * Admin user named vmadmin with the ssh keys stored in .terraform/.kube/clusters/your_cluster_name.id_rsa
  * A read-only cluster role binding for the Kubernetes dashboard
  * A read-only binding allowing OMS to use the clusterUser account necessary access
  * A cluster-admin and view cluster role binding to an AAD Group
  * Tiller in the kube-system namespace set up for Helm
  * Helm releases have been configured so they are immediately available
    * stable/nginx-ingress
    * jetstack/cert-manager
  * Storage classes for Azure standard and premium storage

Following deployment there are some additional steps that need to be performed that are specific to the application - see the Post Deployment section.

## Prerequisites

Prior to deployment you need the following:
* [azcli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* [terraform](https://www.terraform.io/) - 0.12
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [helm](https://helm.sh/)

In Azure, you also need:
* A user account or service policy with Contributor level access to the target subscription and the Application Administrator and Group Administrator AAD roles
* If using AAD RBAC Integration, you also require a Client and Server component. See [here](https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration-cli) for the steps
    * For viewing live data, also consult [this](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-livedata-setup) page

## Variables

These are the variables used along with their defaults. For any without a value in default, the value must be filled in unless otherwise sateted otherwise the deployment will encounter failures.

|Variable|Description|Default|
|-|-|-|
|tenant_id|The tenant id of this deployment|null|
|subscription_id|The subscription id of this deployment|null|
|client_id|The client id used to authenticate to Azure|null|
|client_secret|The client secret used to authenticate to Azure|null|
|location|The location of this deployment|UK South|
|resource_prefix|A prefix for the name of the resource, used to generate the resource names|kubernetes|
|tags|Tags given to the resources created by this template|{}|
|enable_acr|Flag used to enable ACR|true|
|acr_sku|SKU of the ACR|Basic|
|acr_admin_enabled|Flag used to enable ACR Admin|true|
|aks_kubernetes_version|Version of Kubernetes to use in the cluster|null|
|enable_aks_aad_rbac|Flag used to enable AAD RBAC integration|false|
|aks_aad_client_app_id|App ID of the client application used for AAD RBAC|null|
|aks_aad_server_app_id|App ID of the server application used for AAD RBAC|null|
|aks_aad_server_app_secret|App Secret of the server application used for AAD RBAC|null|
|aks_node_vm_admin|Username for the node VM administrator|vmadmin|
|aks_node_size|Size of nodes in the AKS cluster|Standard_B2ms|
|aks_node_disk_size|Disk size of nodes in the AKS cluster (Minimum 30)|64|
|aks_node_min_count|Minimum number of nodes in the AKS cluster|1|
|aks_node_max_count|Maximum number of nodes in the AKS cluster|5|
|aks_nginx_ingress_chart_version|The chart version for the nginx-ingress Helm chart|1.29.2|
|aks_cert_manager_chart_version|The chart version for the cert-manager Helm chart|v0.13.0|

## Outputs

This template will output the following information:

|Output|Description|
|-|-|
|aks_cluster|Provides details of the AKS Cluster|
|container_registry|Provides details of the Container Registry|

## Deployment

Below describes the steps to deploy this template.

1. Set variables for the deployment
    * Terraform has a number of ways to set variables. See [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables) for more information.
2. Log into Azure with `az login` and set your subscription with `az account set --subscription='<replace with subscription id or name>'`
    * Terraform has a number of ways to authenticate. See [here](https://www.terraform.io/docs/providers/azurerm/guides/azure_cli.html) for more information.
3. Initialise Terraform with `terraform init`
    * By default, state is stored locally. State can be stored in different backends. See [here](https://www.terraform.io/docs/backends/types/index.html) for more information.
4. Set the workspace with `terraform workspace select <replace with environment>`
    * If the workspace does not exist, use `terraform workspace new <replace with environment>`
5. Generate a plan with `terraform plan -out tf.plan`
6. If the plan passes, apply it with `terraform apply tf.plan`

In the event the deployment needs to be destroyed, you can run `terraform destroy` in place of steps 5 and 6.

## Post-Deployment

### Connecting to the Cluster

You can connect to your new cluster using two methods:

1. Use the Kubeconfig file created under `.terraform/.kube/clusters` directory to get immediate access
2. Run `az aks get-credentials --name=<replace with cluster name> --resource-group=<replace with cluster resource group>`
    * If using RBAC integration, ensure you are also in the group (inherited or not) created as part of the Terraform run. These groups will be named `<cluster name> Kubernetes Cluster <role>`

### Kubernetes

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

## Maintenance

As the cluster requires and has components managed by AKS, you will need to occasionally update secrets to ensure the cluster is still healthy. This can be managed with azcli.

To update the AKS Service Principal, run the following command

```bash
az aks update-credentials --name=<replace with aks cluster name> --resource-group=<replace with aks cluster resource group> \
    --reset-service-principal \
    --service-principal=<replace with cluster client id> \
    --client-secret=<replace with cluster client secret>
```

To update the AAD Service Principal, run the following command

```bash
az aks update-credentials --name=<replace with aks cluster name> --resource-group=<replace with aks cluster resource group> \
    --reset-aad \
    --aad-tenant-id=<replace with cluster aad tenant id> \
    --aad-client-app-id=<replace with cluster aad client app id> \
    --aad-server-app-id=<replace with cluster aad server app id> \
    --aad-server-app-secret=<replace with cluster aad server app secret> \
```
