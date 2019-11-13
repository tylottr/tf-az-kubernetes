Terraform: Azure Kubernetes
===========================

This template will create a Kubernetes environment and bootstrap it so it is ready for use.

The environment deployed contains the following resources:
* A service policy to allow K8s to access the necessary Azure resources
* OPTIONAL: An Azure Container Registry for storing images
* A bootstrapped Kubernetes cluster 
  * Kubeconfig stored in .terraform/.kube/clusters/your_cluster_name
  * Admin user named vmadmin with the ssh keys stored in .terraform/.ssh/id_rsa
  * A read-only cluster role binding for the Kubernetes dashboard
  * Tiller in the kube-system namespace set up for Helm
  * Helm releases have been configured so they are immediately available
    * stable/nginx-ingress
    * jetstack/cert-manager
  * Storage classes for Azure standard and premium storage

Following deployment there are some additional steps that need to be performed that are specific to the application - see the Post Deployment section.

Prerequisites
-------------

Prior to deployment you need the following:
* [azcli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* [terraform](https://www.terraform.io/) - 0.12
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [helm](https://helm.sh/)

In Azure, you also need:
* A user account or service policy with Contributor level access to the target subscription and the Application Administrator AAD role

In addition to these packages, [VS Code](https://code.visualstudio.com/) is a useful, extensible code editor with plug-ins for Git, Terraform and more

Variables
---------

These are the variables used along with their defaults. For any without a value in default, the value must be filled in unless otherwise sateted otherwise the deployment will encounter failures.

|Variable|Description|Default|
|-|-|-|
|location|The location of this deployment|UK South|
|resource_prefix|A prefix for the name of the resource, used to generate the resource names|kubernetes|
|tags|Tags given to the resources created by this template|{}|
|enable_acr|Flag used to enable ACR|true|
|acr_sku|SKU of the ACR|Basic|
|aks_cluster_kubernetes_version|Version of Kubernetes to use in the cluster|[NOT REQUIRED]|
|aks_cluster_worker_min_count|Minimum number of workers in the AKS cluster|1|
|aks_cluster_worker_max_count|Maximum number of workers in the AKS cluster|5|
|aks_cluster_worker_size|Size of workers in the AKS cluster|Standard_B2ms|
|aks_cluster_worker_disk_size|Disk size of workers in the AKS cluster (Minimum 30)|64|
|aks_cluster_nginx_ingress_chart_version|The chart version for the nginx-ingress Helm chart|1.24.7|
|aks_cluster_custom_backend_service|The custom backend service in the format NAMESPACE/SERVICE|[NOT REQUIRED]|
|aks_cluster_cert_manager_chart_version|The chart version for the cert-manager Helm chart|v0.11.0|

Outputs
-------

This template will output the following information:

|Output|Description|
|-|-|
|kubernetes_service_principal|The object ID of the Kubernetes service principal|
|kubernetes_cluster_name|The name of the kubernetes cluster|
|kubernetes_rg_name|The name of the kubernetes cluster resource group|
|kubernetes_node_rg_name|The name of the kubernetes cluster's node resource group|
|acr_name|The name of the ACR|
|acr_id|The ID of the ACR|

Deployment
----------

Below describes the steps to deploy this template.

1. Set variables for the deployment
    * Terraform has a number of ways to set variables. See [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables)
2. Log into Azure with `az login` and set your subscription with `az account set --subscription $ARM_SUBSCRIPTION_ID`
3. Initialise Terraform with `terraform init`
    * By default, state is stored locally. State can be stored in different backends. See [here](https://www.terraform.io/docs/backends/types/index.html) for more information.
4. Generate a plan with `terraform plan -out tf.plan` and apply it with `terraform apply tf.plan`

In the event the deployment needs to be destroyed, you can run `terraform destroy`

Post-Deployment
---------------

### Kubernetes

Following deployment there are some resources within the cluster that need to be deployed separate to the Terraform deployment. These steps will not be tracked by Terraform itself.

Additional Kubernetes configuration files can be found under the [files/kubernetes/manifests](./files/kubernetes/manifests) directory.

#### Certificates

Certificates are handled by cert-manager to provide valid SSL certificates, which can optionally be deployed with the template. They utilise two main components: The Issuer, and the Certificate. The configuration file bases provided in this repository can be used to set up some basics.

* The Issuer can be namespaced (Issuer) or cluster-wide (ClusterIssuer)
* Certificates are namespaced
    * Certificates can support multiple names, assuming DNS is configured properly

Manifests under [files/kubernetes/manifests/cert-manager](./files/kubernetes/manifests/cert-manager) can be used as a guideline assuming DNS is set up for the endpoint.

#### Rbac Roles

Additional RBAC roles can be created for the cluster.

Manifests under [files/kubernetes/manifests/rbac](./files/kubernetes/manifests/rbac) can be used as a guideline or as-is with a cluster-admin and read-only role already in the folder.

#### Helm Charts

Additional values for some Helm charts have been stored under [files/kubernetes/helm/values](./files/kubernetes/helm/values) to provide some additional options for services to deploy to the cluster.

Useful Links
------------

* [Terraform Documentation](https://www.terraform.io/docs/)
* [Azure Documentation](https://docs.microsoft.com/en-us/azure/)
* [Kubernetes Documentation](https://kubernetes.io/docs/home/)