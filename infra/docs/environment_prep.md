# Preparing the environment

- [GitLab Environment Toolkit - Quick Start Guide](environment_quick_start_guide.md)
- [**GitLab Environment Toolkit - Preparing the environment**](environment_prep.md)
- [GitLab Environment Toolkit - Provisioning the environment with Terraform](environment_provision.md)
- [GitLab Environment Toolkit - Configuring the environment with Ansible](environment_configure.md)
- [GitLab Environment Toolkit - Advanced - Custom Config / Tasks / Files, Data Disks, Advanced Search, Container Registry and more](environment_advanced.md)
- [GitLab Environment Toolkit - Advanced - Cloud Native Hybrid](environment_advanced_hybrid.md)
- [GitLab Environment Toolkit - Advanced - Component Cloud Services / Custom (Load Balancers, PostgreSQL, Redis)](environment_advanced_services.md)
- [GitLab Environment Toolkit - Advanced - SSL](environment_advanced_ssl.md)
- [GitLab Environment Toolkit - Advanced - Network Setup](environment_advanced_network.md)
- [GitLab Environment Toolkit - Advanced - Monitoring](environment_advanced_monitoring.md)
- [GitLab Environment Toolkit - Upgrades (Toolkit, Environment)](environment_upgrades.md)
- [GitLab Environment Toolkit - Considerations After Deployment - Backups, Security](environment_post_considerations.md)
- [GitLab Environment Toolkit - Geo](geo/README.md)
  - [GitLab Environment Toolkit - Geo - Provisioning the environment with Terraform](geo/geo_provision.md)
  - [GitLab Environment Toolkit - Geo - Configuring the environment with Ansible](geo/geo_configure.md)
  - [GitLab Environment Toolkit - Geo - Advanced](geo/geo_advanced.md)
- [GitLab Environment Toolkit - Troubleshooting](environment_troubleshooting.md)

Preparation is required prior to building out an environment depending on where you intend to host it. These docs assume working knowledge of the selected host provider the environment is to run on, such as a specific Cloud provider.

This page starts off with general guidance around fundamentals but then will split off into the steps for each supported specific provider. As such, you should only follow the section for your provider after the general sections.

[[_TOC_]]

## Overview

Before you begin preparing your environment there are several fundamentals that are worth calling out regardless of provider.

After reading through these proceed to the steps for your specific provider.

### Authentication

Each of the tools in this Toolkit, and even GitLab itself, all require authentication to be configured for the following:

- Direct authentication with Cloud Platform (Terraform, Ansible)
- Authentication with Cloud Platform Object Storage (Terraform, GitLab)
- SSH authentication with machines (Ansible)

Authentication is fully dependent on the provider and are detailed fully in each provider's section below.

### Terraform State

When using Terraform, one important caveat is preparing its [State](https://www.terraform.io/docs/state/index.html) file. Terraform's State is integral to how it works. For every action it will store and update the state with the full environment status each time. It then refers to this for subsequent actions to ensure the environment is always exactly as configured.

[Terraform has numerous possible backends](https://www.terraform.io/language/settings/backends) where the state can be stored. As a general guidance we recommend a remote backend that can be shared between applicable users such as the targeted Cloud Provider's Object Storage or [GitLab's own managed Terraform State backend](https://docs.gitlab.com/ee/user/infrastructure/iac/terraform_state.html). Whatever backend is chosen the configuration is set in the same location - the environment's `main.tf` file.

:information_source:&nbsp; These docs assume the target Cloud Provider's Object Storage is being used.

### Static External IP

Environments also require a Static External IP to be generated manually. This will be the main IP for accessing the environment and is required to be generated separately to prevent Terraform from destroying it during a teardown and breaking any subsequent DNS entries.

## Google Cloud Platform (GCP)

### 1. GCloud CLI

We recommend installing GCP's command line tool, `gcloud` as per the [official instructions](https://cloud.google.com/sdk/install). While this is not strictly required it makes authentication for Terraform and Ansible more straightforward on workstations along with numerous tools to help manage environments directly.

### 2. Create GCP Project

Each environment is recommended to have its own project on GCP for various reasons such as ensuring there are no conflicts. For example avoiding shared firewall rule changes /  or quota limits.

Existing projects can also be used, but this should be checked with the Project's stakeholders as this will affect things such as total CPU quotas for example.

:information_source:&nbsp; Ensure that you have the [Service Usage API](https://console.cloud.google.com/apis/api/serviceusage.googleapis.com/overview) and [Compute Engine API](https://console.developers.google.com/apis/api/compute.googleapis.com/overview) enabled.

### 3. Setup Provider Authentication: GCP Service Account

Authentication with GCP directly is done with a [Service Account](https://cloud.google.com/iam/docs/understanding-service-accounts), which is required by both Terraform and Ansible.

:information_source:&nbsp; To create and manage Service Accounts you may require permissions on your own account. Refer to the [GCP documentation for more information](https://cloud.google.com/iam/docs/service-accounts-create).

With the above set create the Service Account as follows:

1. Access GCP's [Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts) page.
1. Ensure that the correct project is selected in the dropdown at the top of the page.
1. Create an account with a descriptive name like `gitlab-qa` and take note of its email address for the next step.
1. Assign the following [IAM roles](https://cloud.google.com/iam/docs/granting-changing-revoking-access#granting-console):
   - `Compute Admin`
   - `Kubernetes Engine Admin`
   - `Storage Admin` (Note - Not `Compute Storage Admin`)
   - `Service Account Admin`
1. Assign the following additional IAM roles if you're planning on deploying the respective optional service:
   - [Cloud SQL](environment_advanced_services.md#gcp-cloud-sql)
     - `Cloud SQL Admin`
     - `Compute Network Admin`
     - Note that the [Cloud Resource Manager](https://cloud.google.com/resource-manager/reference/rest) and the [Cloud SQL Admin](https://console.cloud.google.com/apis/library/redis.googleapis.com) APIs will also need to be enabled on the project for Cloud SQL.
   - [Cloud Memorystore](environment_advanced_services.md#gcp-memorystore)
     - `Cloud Memorystore Redis Admin`
     - `Cloud Memorystore Redis Editor`
     - Note that the [Memorystore for Redis](https://console.cloud.google.com/apis/library/redis.googleapis.com) API will also need to be enabled on the project for Memorystore.
1. [Create and download a Service Account key](https://cloud.google.com/iam/docs/keys-create-delete#creating) to a [secure location](https://cloud.google.com/iam/docs/best-practices-for-managing-service-account-keys). This key will be used later by Terraform and Ansible to authenticate.

:information_source:&nbsp; The Toolkit will in turn create several required Service Accounts via Terraform during the provisioning stage for the resources. Refer to the [Service Accounts (GCP) section](environment_provision.md#service-accounts-gcp) for more information.

### 4. Setup SSH Authentication: SSH OS Login for GCP Service Account

In addition to creating the Service Account, set up [OS Login](https://cloud.google.com/compute/docs/instances/managing-instance-access) for the account to enable SSH access to the created VMs on GCP, which is required by Ansible. This is done as follows:

1. [Generate an SSH key pair](https://docs.gitlab.com/ee/user/ssh/#generate-an-ssh-key-pair) (ED25519 recommended) and store it in the [`keys`](../keys) directory by specifying the path, for example: `-f ./keys/id_ed25519`.

   :information_source:&nbsp; If you specify a passphrase when creating the key pair, Ansible will prompt for the passphrase many times.
   [Set up SSH agent to avoid this](https://docs.ansible.com/ansible/latest/inventory_guide/connection_details.html#setting-up-ssh-keys).
1. With the `gcloud` command set it to point at your intended project

   :information_source:&nbsp; You need the project's [ID](https://support.google.com/googleapi/answer/7014113?hl=en) here and not the name. You can find it in project's dashboard in GCP Console.

   ```terminal
   gcloud config set project <project-id>
   ```

1. Enable OS Login by setting the metadata `enable-oslogin=TRUE`. This can either be set [project-wide](https://cloud.google.com/compute/docs/metadata/setting-custom-metadata#set-projectwide) or [per instance](https://cloud.google.com/compute/docs/metadata/setting-custom-metadata#set-custom), once the instances have been provisioned by Terraform. To set the metadata project-wide, run the following command:

   ```terminal
   gcloud compute project-info add-metadata --metadata enable-oslogin=TRUE
   ```

1. Add the project's public SSH key to the Service Account

   :information_source:&nbsp; **This command will output the SSH Username for the Service Account, typically in the format of `sa_<ID>`. Take a note of this username as later, it will be used in the Ansible [Environment config - vars.yml](environment_configure.md#environment-config-varsyml) section.**

   ```terminal
   gcloud compute os-login ssh-keys add --key-file=<SSH key>.pub --impersonate-service-account=<service-account-email-address>
   ```

1. Switch back your logged in account in `gcloud` to your regular account using your email address.

   ```terminal
   gcloud config set account <account-email-address>
   ```

SSH access should now be enabled on the Service Account and this will be used by Ansible to SSH login to each VM.
More info on OS Login and how it's configured can be found [in Google's documentation](https://cloud.google.com/compute/docs/oslogin/).

That's all that's required for now. Later on in this guide we'll configure the Toolkit to use the key for accessing machines.

### 5. Setup Terraform State Storage Bucket: GCP Cloud Storage

Create a standard [GCP storage bucket](https://cloud.google.com/storage/docs/creating-buckets) on the intended environment's project
for its Terraform State. Give this a meaningful name such as `<env_short_name>-get-terraform-state`

As an example this bucket can be created via the `gsutil` cli as follows:

```terminal
# List of locations: https://cloud.google.com/storage/docs/locations
gsutil mb -l BUCKET_LOCATION gs://<env_shortname>-get-terraform-state
```

:information_source:&nbsp; The bucket may be named as desired. However, note that the Toolkit will create a bucket later with the naming format `<prefix>-terraform-state` for the [Terraform Module Registry](https://docs.gitlab.com/ee/user/packages/terraform_module_registry/) feature in GitLab by default (which can also be changed if required). Each bucket requires a unique name to avoid clashes.

After the Bucket is created this is all that's required for now. We'll configure Terraform to use it later in these docs.

### 6. Create Static External IP: GCP

A static IP can be generated in GCP as follows:

- Reserve a static external IP address in your project [as detailed in the GCP docs](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address).
- Use the default options when given a choice and ensure the IP is **regional**.
- Ensure IP has a unique name.

Once the IP is available take note of it for later.

## Amazon Web Services (AWS)

### 1. Setup Provider Authentication: Environment Variables

Authentication with AWS directly can be done in [various ways](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication).

The most straightforward of these options that work with both Terraform and AWS is to create access keys for your user and then set them via the Environment Variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` respectively.

To create an access key for your user follow [the official docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey). Once created save these in a secure location and then set each key to the respective environment variable as shown above in any shell or CI job you're looking to run the Toolkit.

### 2. Setup SSH Authentication: AWS

:information_source:&nbsp; If you intend to use an alternative method for connecting to machines, for example AWS SSM, you can skip this step.

SSH authentication for the created machines on AWS will require an SSH key. A key is required to be created and to be accessible for the Toolkit to handle the rest:

1. [Generate an SSH key pair](https://docs.gitlab.com/ee/user/ssh/#generate-an-ssh-key-pair) (ED25519 recommended) and store it in the [`keys`](../keys) directory by specifying the path, for example: `-f ./keys/id_ed25519`.

   :information_source:&nbsp; If you specify a passphrase when creating the key pair, Ansible will prompt for the passphrase many times.
   [Set up SSH agent to avoid this](https://docs.ansible.com/ansible/latest/inventory_guide/connection_details.html#setting-up-ssh-keys).

It is also possible to use an existing SSH key pair, but it is recommended to use a new key to avoid any potential security implications.

SSH usernames are provided by AWS depending on the [AMI Image](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connection-prereqs.html#connection-prereqs-get-info-about-instance) used. With the Toolkit's defaults this will typically be `ubuntu`.

:information_source:&nbsp; **Take a note of this username as later, as it will be used later in the Ansible [Environment config - vars.yml](environment_configure.md#environment-config-varsyml) section.**

That's all that's required for now. Later on in this guide we'll configure the Toolkit to use this key for adding into the AWS machines as well as accessing them.

### 3. Setup Terraform State Storage: AWS S3

Create a standard [AWS storage bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html) on the intended environment's project for its Terraform State. Give this a meaningful name such named as `<env_short_name>-get-terraform-state`.

:information_source:&nbsp; The bucket may be named as desired. However, note that the Toolkit will create a bucket later with the naming format `<prefix>-terraform-state` for the [Terraform Module Registry](https://docs.gitlab.com/ee/user/packages/terraform_module_registry/) feature in GitLab by default (which can also be changed if required). Each bucket requires a unique name to avoid clashes.

After the Bucket is created this is all that's required for now. We'll configure Terraform to use it later in these docs.

### 4. Create Static External IP: AWS Elastic IP Allocation

A static IP, AKA an Elastic IP, can be generated in AWS as follows:

- Reserve a static external IP address in your account [as detailed in the AWS docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html#using-instance-addressing-eips-allocating).
- Use the default options when given a choice.

Once the IP is available take note of its **allocation ID** [to specify in the Terraform `variables.tf` file](environment_provision.md#configure-variables-variablestf-1) during the environment provision steps.

:information_source:&nbsp; If you are deploying a Cloud Native Hybrid GitLab setup you'll need to create an Elastic IP for each subnet in the intended VPC instead of a single one.

## Azure

### 1. Create Azure Resource Group

Each environment is recommended to have its own [resource group](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#what-is-a-resource-group) on Azure. Create a group following the [official guide](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#create-resource-groups). When given a choice using the default options is fine.

Existing resource groups can also be used, but this should be checked with the Group's stakeholders as this will affect things such as total CPU quotas for example.

### 2. Setup Provider Authentication: Azure

Authentication with Azure directly can be done in [various ways](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure).

It's recommended to use either a Service Principal(with [Client Certificate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_certificate) or [Client Secret](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret)) or [Managed Service Identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/managed_service_identity) when running Terraform non-interactively (such as when running Terraform in a CI server) - and authenticating using the [Azure CLI](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli) when running Terraform locally.

Once you have selected the authentication method and obtained the credentials you may export them as Environment Variables following the Terraform instructions for the specific authentication type.

### 3. Setup SSH Authentication: Azure

SSH authentication for the created machines on Azure will require an admin username and an SSH key.

First think of an admin username that will be used for SSH connection to the Azure's virtual machines.

:information_source:&nbsp; **Take a note of the username you select as later, it will be used in the Terraform [Configure Variables (`variables.tf`)](environment_provision.md#configure-variables-variablestf-2) and Ansible [Environment config - vars.yml](environment_configure.md#environment-config-varsyml) sections.**

All that's required for an SSH key is to be created and then for this to be accessible for the Toolkit to handle the rest:

1. [Generate an SSH key pair](https://docs.gitlab.com/ee/user/ssh/#generate-an-ssh-key-pair) using [supported encryption](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys#supported-ssh-key-formats) and store it in the [`keys`](../keys) directory by specifying the path, for example: `-f ./keys/id_rsa`.

   :information_source:&nbsp; If you specify a passphrase when creating the key pair, Ansible will prompt for the passphrase many times.
   [Set up SSH agent to avoid this](https://docs.ansible.com/ansible/latest/inventory_guide/connection_details.html#setting-up-ssh-keys).

It is also possible to use an existing SSH key pair, but it is recommended to use a new key to avoid any potential security implications.

That's all that's required for now. Later on in this guide we'll configure the Toolkit to use the admin username and the key for adding into the Azure machines as well as accessing them.

### 4. Setup Terraform State Storage: Azure Blob Storage

Create a [storage account](https://docs.microsoft.com/en-us/azure/storage/common/storage-account-create) that will contain all of your Azure Storage data objects. Take a note of its name and [access key](https://docs.microsoft.com/en-us/azure/storage/common/storage-account-keys-manage) for later.

Then create a standard [Azure blob container](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal) on the intended environment's storage account for its Terraform State. Give this a meaningful name such as `<env_short_name>-get-terraform-state`.

:information_source:&nbsp; The bucket may be named as desired. However, note that the Toolkit will create a bucket later with the naming format `<prefix>-terraform-state` for the [Terraform Module Registry](https://docs.gitlab.com/ee/user/packages/terraform_module_registry/) feature in GitLab by default (which can also be changed if required). Each bucket requires a unique name to avoid clashes.

After the container is created this is all that's required for now. We'll configure Terraform to use it later in these docs.

### 5. Create Static External IP: Azure

A static IP can be generated in Azure as follows:

- Reserve a static external IP address in your resource group [as detailed in the Azure docs](https://docs.microsoft.com/en-us/azure/virtual-network/create-public-ip-portal?tabs=option-create-public-ip-standard-zones)
- Make sure to select the _[Standard SKU](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/create-public-ip-portal?tabs=option-1-create-public-ip-standard#create-a-standard-sku-public-ip-address)_ to ensure that the allocation is static

Once the IP is available take note of its name for later.

## Next Steps

After the above steps have been completed you can proceed to [Provisioning the environment with Terraform](environment_provision.md).
