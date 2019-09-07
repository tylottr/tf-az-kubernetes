Terraform: Azure Kubernetes
===========================

This template will create a Kubernetes environment and bootstrap it so it is ready for use.

The environment deployed contains the following resources:
* A service policy to allow K8s to access the necessary Azure resources
* OPTIONAL: An Azure Container Registry for storing images
* A bootstrapped Kubernetes cluster 
  * A new kubeconfig file is created at ~/.kube/$YOUR_CLUSTER_NAME
  * Helm is set up in the cluster with the stable repository and the Jetstack repository (assuming cert-manager is used)
  * Helm releases have been configured so they are immediately available
    * stable/nginx-ingress
    * stable/cluster-autoscaler
    * OPTIONAL: jetstack/cert-manager
  * Storage classes for Azure standard and premium storage

Following deployment there are some additional steps that need to be performed that are specific to the application - see the Post Deployment section.

Prerequisites
-------------

Prior to deployment you need the following:
* [azcli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* [terraform](https://www.terraform.io/) - 0.12.6
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [helm](https://helm.sh/)

In Azure, you also need:
* A user account or service policy with Contributor level access to the target subscription
    * This account also needs Azure AD access to create service principals

In addition to these packages, [VS Code](https://code.visualstudio.com/) is a useful, extensible code editor with plug-ins for Git, Terraform and more

Variables
---------

These are the variables used along with their defaults. For any without a value in default, the value must be filled in unless otherwise sateted otherwise the deployment will encounter failures.

|Variable|Description|Default|
|-|-|-|
|location|The location of this deployment|UK South|
|environment_prefix|A prefix for the environment this resource belongs in, used to generate the resource names|[NOT REQUIRED]|
|resource_prefix|A prefix for the name of the resource, used to generate the resource names|Kubernetes|
|tag_owner|Sets the value of this tag|Terraform|
|tag_environment|Sets the value of this tag|Test|
|tag_application|Sets the value of this tag|Kubernetes|
|tag_criticality|Sets the value of this tag|3|
|service_policy_password_expiry|The amount of time for a service policy passwords to be valid|43800h|
|enable_acr|Flag used to enable ACR|true|
|acr_sku|SKU of the ACR|Basic|
|aks_cluster_kubernetes_version|Version of Kubernetes to use in the cluster|[NOT REQUIRED]|
|aks_cluster_worker_min_count|Minimum number of workers in the AKS cluster|1|
|aks_cluster_worker_max_count|Maximum number of workers in the AKS cluster|5|
|aks_cluster_worker_size|Size of workers in the AKS cluster|Standard_B2ms|
|aks_cluster_worker_disk_size|Disk size of workers in the AKS cluster (Minimum 30)|30|
|aks_cluster_custom_backend_service|The custom backend service in the format NAMESPACE/SERVICE|[NOT REQUIRED]|
|aks_cluster_nginx_ingress_chart_version|The chart version for the nginx-ingress Helm chart|1.14.0|
|aks_cluster_cluster_autoscaler_chart_version|The chart version for the cluster-autoscaler Helm chart|3.2.0|
|aks_cluster_enable_cert_manager|Flag used to enable cert-manager|true|
|aks_cluster_cert_manager_chart_version|The chart version for the cert-manager Helm chart|v0.9.1|

Outputs
-------

This template will output the following information:
|Output|Description|
|-|-|
|kubernetes_service_principal|The object ID of the Kubernetes service principal|
|kubernetes_cluster_name|The name of the kubernetes cluster|
|kubernetes_rg_name|The name of the kubernetes cluster resource group|
|kubernetes_node_rg_name|The name of the kubernetes cluster's node resource group|
|kubeconfig|The full kubeconfig for the new cluster|
|acr_name|The name of the ACR|
|acr_id|The ID of the ACR|

Deployment
----------

Below describes the steps to deploy this template.

1. Set variables for the deployment
    * Terraform has a number of ways to set variables. See [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables)
2. Log into Azure with `az login`
    * If using a Service Principal instead, you can use the `--service-principal` flag
3. Select the correct subscription with `az account set --subscription $ARM_SUBSCRIPTION_ID`
4. Initialise Terraform with `terraform init`
    * By default, state is stored locally. State can be stored in different backends. See [here](https://www.terraform.io/docs/backends/types/index.html)
        * When using remote state, use the `-backend=true` flag in combination with the `-backend-config=var=val` arguments. The [azurerm](https://www.terraform.io/docs/backends/types/azurerm.html) backend documentation is here for an example.
5. Generate a plan with `terraform plan -out tf.plan`
6. Apply the plan with `terraform apply tf.plan`
    * This command will not prompt prior to running changes

In the event the deployment needs to be destroyed, you can run `terraform destroy`

Post-Deployment
---------------

### Kubernetes

Following deployment there are some resources within the cluster that need to be deployed separate to the Terraform deployment. These steps will not be tracked by Terraform itself.

Additional Kubernetes configuration files can be found under the [kubernetes](./kubernetes) directory.

#### Certificates

Certificates are handled by cert-manager to provide valid SSL certificates, which can optionally be deployed with the template. They utilise two main components: The Issuer, and the Certificate. The configuration file bases provided in this repository can be used to set up some basics.

* The Issuer can be namespaced (Issuer) or cluster-wide (ClusterIssuer)
* Certificates are namespaced
    * Certificates can support multiple names, assuming DNS is configured properly

#### RBAC

RBAC is enabled for clusters created with this template. Using the example rbac.yaml file will create a Service Account for a cluster-fullaccess and cluster-readonly with associated bindings. 
* Tokens can be retrieved from the associated secret for the service account

#### Kube Router

Kube-router allows the usage of routing policies and other features.
* To deploy for network policies, you can run `kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kube-router-firewall-daemonset.yaml`

Useful Links
------------

* [Terraform Documentation](https://www.terraform.io/docs/)
* [Azure Documentation](https://docs.microsoft.com/en-us/azure/)
* [Kubernetes Documentation](https://kubernetes.io/docs/home/)
* [cert-manager Repository](https://github.com/jetstack/cert-manager)
* [kube-router Repository](https://github.com/cloudnativelabs/kube-router)
