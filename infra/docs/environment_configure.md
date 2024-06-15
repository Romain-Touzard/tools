# Configuring the environment with Ansible

- [GitLab Environment Toolkit - Quick Start Guide](environment_quick_start_guide.md)
- [GitLab Environment Toolkit - Preparing the environment](environment_prep.md)
- [GitLab Environment Toolkit - Provisioning the environment with Terraform](environment_provision.md)
- [**GitLab Environment Toolkit - Configuring the environment with Ansible**](environment_configure.md)
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

With [Ansible](https://docs.ansible.com/ansible/latest/index.html), you can automatically configure provisioned machines.

The Toolkit provides multiple curated [Ansible Playbooks and Roles](../ansible) that will install and configure GitLab as per the [Reference Architectures](https://docs.gitlab.com/ee/administration/reference_architectures/).

:information_source:&nbsp; It's recommended that users have a good working knowledge of Ansible and GitLab administration before proceeding. This documentation assumes this throughout.

[[_TOC_]]

## Overview

Installing and configuring GitLab automatically is the most complex part of the process, as such Ansible is the most complex part of the Toolkit as a result. It's worth highlighting then how it works at a high level before we detail the steps on how to set up and use it.

### Playbooks and Roles

In a nutshell Ansible runs through the Toolkit's provided Playbooks. We have a runner Playbook, `all.yml` that runs through the rest in the correct order for GitLab. Each [Playbook](https://docs.ansible.com/ansible/latest/user_guide/playbooks.html) in turn runs the associated [Role](https://docs.ansible.com/ansible/latest/user_guide/playbooks_reuse_roles.html) on the intended machines.

Each Role in the Toolkit is designed to be as simple as possible and match what's recommended in the GitLab docs as much as possible. They will generally run through the following steps:

1. Install required packages on the OS
1. Install GitLab Omnibus (EE)
1. Configure the `gitlab.rb` file depending on the machine
1. Run `gitlab-ctl reconfigure`

In some Roles there are extra steps depending on the components being setup, for example detecting the Primary Postgres node and these can be viewed in the Tasks files for each Role.

### Inventory and Groups

Ansible knows what Playbooks to run on what machines thanks to its [Inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html), which is a list of all target machine addresses available to Ansible. These machines can have labels that help Ansible select and filter through them, which the Toolkit uses extensively.

The Toolkit generally uses a variant of Inventories called [Dynamic Inventories](https://docs.ansible.com/ansible/latest/user_guide/intro_dynamic_inventory.html). These Inventories poll the target host provider for the current list of hosts based on several factors. With these you don't need to maintain a static Inventory file.

While with the Inventory Ansible can get a full list of hosts it's to configure it doesn't know what each one is specifically. With [Groups](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html#inventory-basics-formats-hosts-and-groups) Ansible can differentiate between the hosts and run the correct Playbooks against them. This is a crucial part to how Ansible runs. With Terraform, we called out that we set various labels on the provisioned VMs based on their role. Ansible can read these labels and set up groups based on them, for example `gitlab_rails`, `postgres` and so on.

### Variables

[Variables](https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html) are a versatile and integral part of Ansible and can be [defined in many locations](https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#understanding-variable-precedence). Ansible itself also collects [many variables](https://docs.ansible.com/ansible/latest/user_guide/playbooks_vars_facts.html) about the hosts it connects to such as IPs, machine specs and more.

The Toolkit uses these extensively to dynamically configure each GitLab machine depending on its type. This includes things such as selecting what and how to install or finding out IPs of other machines for example.

As mentioned there are various ways variables can be configured. The Toolkit uses the following locations for variables (in order of precedence):

- Inventory File vars - Contains variables specific to the environment. Can contain overrides for Role Defaults.
- Role Defaults (`<role>/default/main.yml`) - Contains default variables specific to the Role, e.g. Postgres specific settings. These can be overridden.
- Common Vars (`role/common_vars/default/main.yml`) - Variables that are shared between Roles, which are configured themselves in a Role and imported. Most variables can be found here such as IP lists for example.
- Environment Variables - The Playbooks have been configured to use certain env vars if available.

It's worth noting the Toolkit tweaks the default group variable precedence to better allow for different configurations per environment's inventory. Inventory group variables take a higher precedence here than playbook ones.

Hopefully with this overview its clearer how Ansible in the Toolkit works. Below we detail how to set up and use it.

## 1. Install Ansible

The Toolkit requires Ansible to be installed. We follow the [Ansible lifecycle](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html#ansible-community-changelogs) and aim to support the latest maintained version, in this case Ansible `9.0` or higher (`ansible-core 2.16`).

:information_source:&nbsp; Ansible itself typically has requirements on what Python version is installed on the control node. Whatever version you chose will have a corresponding Python version requirement. **For Ansible `9.x` (`ansible-core 2.16`), [Python `3.10` or higher is required](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#control-node-requirements)**. Note that this Python requirement only applies to the box actually running Ansible and not for the target boxes - Typically the latest available version from the OS is sufficient for the latter.

When choosing an [Ansible control node](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#control-node-requirements), we recommend that it's in the same or near location as the environment being built to avoid network slowdown. Additionally, if you plan to use a cloud machine as a control node it is _not_ recommended to use [burstable instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances.html) as they can lead to inconsistent behaviour.

It's [also strongly recommended that a recent version of `openssh` is installed on the machine](https://docs.ansible.com/ansible/latest/user_guide/connection_details.html#controlpersist-and-paramiko) where Ansible is going to be run to ensure consistent connections.

You can either use a Python virtual environment or install Ansible globally. Additionally, you can avoid installing anything by using the Toolkit's Docker image. We recommend using the method you're most familiar with.

### Using Ansible inside a Docker container

With Docker the only prerequisite is installation, the [Toolkit's image](https://gitlab.com/gitlab-org/gitlab-environment-toolkit/container_registry/2697240) contains everything else you'll need. The official [Docker installation instructions](https://docs.docker.com/engine/install/) should be followed to correctly install and run Docker.

### Installing Ansible with a Virtual Environment

If installing Ansible locally, we recommend using this approach as your local environment will be isolated from other python packages that you install on your machine. Additionally, your local environment will match the environment used for testing, validation, and building docker images, so there is less chance of package changes affecting the ansible environment you are running locally. The steps for all of this are as follows:

1. Create a virtual environment called `get-python-env` in the `gitlab-environment-toolkit` directory and activate it:

    ```sh
    python3 -m venv get-python-env
    . ./get-python-env/bin/activate
    ```

1. Install Ansible, and it's required Python packages via pip:

    ```sh
    pip3 install ansible
    pip3 install -r ansible/requirements/requirements.txt
    ```

1. Install Ansible Galaxy Collections and Roles:

    ```sh
    ansible-galaxy install -r ansible/requirements/ansible-galaxy-requirements.yml --force
    ```

1. Install OpenSSH Client if not already installed as per your OS.

:information_source:&nbsp; Note that if you're on a macOS machine you'll also need to install `gnu-tar` by running `brew install gnu-tar`

### Bring-Your-Own Ansible

If you have installed Ansible inside a virtual environment, you can skip this step.

Installing Ansible as per the official [Ansible Install Guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html). Note that Ansible requires Python 3 and you may need to install it and its package manager `pip3` separately.

Once you've installed Ansible, install the required dependencies. You'll need to install Python package dependencies on the machine along with some community roles from [Ansible Galaxy](https://galaxy.ansible.com/home) that allow for convenient deployment of some third party applications.

To do this you only have to run the following before proceeding:

1. Install Ansible's required Python packages via pip:

    ```sh
    pip3 install -r ansible/requirements/requirements.txt
    ```

1. Install Ansible Galaxy Collections and Roles:

    ```sh
    ansible-galaxy install -r ansible/requirements/ansible-galaxy-requirements.yml --force
    ```

1. Install OpenSSH Client if not already installed as per your OS.

:information_source:&nbsp; Note that if you're on a macOS machine you'll also need to install `gnu-tar` by running `brew install gnu-tar`

## 2. Set up the Environment's Inventory and Config

For your environment you'll need to set up some config and files to be used by Ansible.

We recommend this is done in the `ansible/environments` folder with the following recommended structure:

```sh
ansible
└── environments
    └── <env_name>
        ├── files
        └── inventory
```

With the above structure in place we can now look at the files to be configured. The rest of this guide will assume this structure is being used.

### Config Examples

[Full config examples are available for select Reference Architectures](../examples). The rest of this section will describe what the config does and how to use it.

### Configure Dynamic Inventory

One of the first pieces of config you will need to configure is the Inventory. As mentioned we use Dynamic Inventories as it automates the collection of machines and labels.

Using the recommended structure the file should be saved in the `inventory` folder, e.g. `environments/<env_name>/inventory`.

Each Dynamic Inventory is a plugin offered by Ansible themselves and are different depending on the host provider. As such, select the section for your host provider and move onto the next step.

#### Google Cloud Platform (GCP)

The Google Dynamic Inventory plugin is called [`gcp_compute`](https://docs.ansible.com/ansible/latest/collections/google/cloud/gcp_compute_inventory.html). This will have been installed already during the Ansible install process via `ansible-galaxy install`.

The config file for this plugin which requires the naming convention `*.gcp.yml`, e.g. `10k.gcp.yml`. Here's an example of the file with all config and descriptions below. Items in `<>` brackets need to be replaced with your config:

```yaml
plugin: gcp_compute
projects:
  - <gcp_project_id>
filters:
  - labels.gitlab_node_prefix = <prefix> # Same prefix set in Terraform
keyed_groups:
  - key: labels.gitlab_node_type
    separator: ''
  - key: labels.gitlab_node_level
    separator: ''
scopes:
  - https://www.googleapis.com/auth/compute
hostnames:
  # List host by name instead of the default public ip
  - name
compose:
  # Set an inventory parameter to use the Public IP address to connect to the host
  # For Private ip use "networkInterfaces[0].networkIP"
  ansible_host: networkInterfaces[0].accessConfigs[0].natIP
```

- `plugin` - The name of the Dynamic Inventory plugin. Must always be `gcp_compute`.
- `projects` - The ID of the GCP project for the environment
- `filters` - A label filter for Ansible to use. This ensures it only configures the machines we want on the project and not any others based on the machine label `gitlab_node_prefix` set automatically in Terraform. Should be set the same `prefix` value set in Terraform.
- `keyed_groups` - Configures Ansible to look for the labels automatically set by Terraform and to set up its host groups based on them. This config block shouldn't be changed from what's shown.
- `scopes` - A GCP specific setting for how to use its API. Should not be changed.
- `hostnames` - Config block for how Ansible should show the hosts in its output. This block configures the use of hostnames rather than IPs for better readability. This config block should not be changed.
- `compose`: As shown in the comment this sets what IPs Ansible should use. This config block shouldn't be changed unless private IPs are desired as mentioned in the comment.

##### Configure Authentication (GCP)

Finally, the last thing to configure is authentication. This is required to allow Ansible to access GCP to build its dynamic inventory.

Ansible provides several ways to authenticate with [GCP](https://docs.ansible.com/ansible/latest/scenario_guides/guide_gce.html#credentials), you can select any method that is desired.

All the methods given involve the Service Account file you generated previously. We've found the authentication methods that work best with the Toolkit in terms of ease of use are as follows:

- `GCP_SERVICE_ACCOUNT_FILE` environment variable - Particularly useful with CI pipelines, the variable should be set to the local path of the Service Account key file.
  - Note that the `GCP_AUTH_KIND` environment variable also needs to be set to `serviceaccount` for this authentication method.
- `gcloud` login - Authentication can also occur automatically through the [`gcloud`](https://cloud.google.com/sdk/gcloud/reference/auth/application-default) command line tool. To log in with the Service Account you created earlier the [`activate-service-account`](https://cloud.google.com/sdk/gcloud/reference/auth/activate-service-account) command is available.
  - Note that the `GCP_AUTH_KIND` environment variable also needs to be set to `application` for this authentication method.

Alternatively, instead of setting `GCP_AUTH_KIND`, you can add `auth_kind` to your Inventory config file to specify which authentication method you'd like to use.

#### Amazon Web Services (AWS)

The AWS Dynamic Inventory plugin is called [`aws_ec2`](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html). This will have been installed already during the Ansible install process via `ansible-galaxy install`.

The config file for this plugin which requires the naming convention `*.aws_ec2.yml`, e.g. `10k.aws_ec2.yml`. Here's an example of the file with all config and descriptions below. Items in `<>` brackets need to be replaced with your config:

```yaml
plugin: aws_ec2
regions:
  - <region>
filters:
  tag:gitlab_node_prefix: <prefix> # Same prefix set in Terraform
keyed_groups:
  - key: tags.gitlab_node_type
    separator: ''
  - key: tags.gitlab_node_level
    separator: ''
hostnames:
  # List host by name instead of the default public ip
  - tag:Name
compose:
  # Set to 'public_ip_address' to make Ansible SSH into the public IP address of the hosts.
  # Set to 'private_ip_address' to use the private (non-internet routable) IP addresses for the hosts.
  # (note: this does not modify inventory_hostname, which is set via I(hostnames))
  ansible_host: public_ip_address
```

- `plugin` - The name of the Dynamic Inventory plugin. Must always be `aws_ec2`.
- `regions` - AWS region the environment will run in.
- `filters` - A label filter for Ansible to use. This ensures it only configures the machines we want on the project and not any others based on the machine tab `gitlab_node_prefix` that set automatically in Terraform. Should be set the same `prefix` value set in Terraform.
- `keyed_groups` - Configures Ansible to look for the tags automatically set by Terraform and to set up its host groups based on them. This config block shouldn't be changed from what's shown.
- `hostnames` - Config block for how Ansible should show the hosts in its output. This block configures the use of hostnames rather than IPs for better readability. This config block should not be changed.
- `compose`: This sets what IP addresses Ansible should use. This config block should be changed when using private IP addresses.

##### Configure Authentication (AWS)

Finally, the last thing to configure is authentication. This is required to allow Ansible to access AWS to build its dynamic inventory.

Ansible provides several ways to authenticate with [AWS](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html#parameters), you can select any method that is desired.

All the methods given involve the AWS Access Key you generated previously. We've found that the easiest and secure way to do this is with the official [environment variables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#environment-variables):

- `AWS_ACCESS_KEY_ID` - Set to the AWS Access Key.
- `AWS_SECRET_ACCESS_KEY` - Set to the AWS Secret Key.

Once the two variables are either set locally or in your CI pipeline Ansible will be able to fully authenticate for both the provider and backend.

#### Azure

The Azure Dynamic Inventory plugin is called [`azure.azcollection.azure_rm`](https://docs.ansible.com/ansible/latest/collections/azure/azcollection/azure_rm_inventory.html). This will have been installed already during the Ansible install process via `ansible-galaxy install`.

The config file for this plugin which requires the naming convention `*.azure_rm.yml`, e.g. `10k.azure_rm.yml`. Here's an example of the file with all config and descriptions below. Items in `<>` brackets need to be replaced with your config:

```yaml
plugin: azure.azcollection.azure_rm

include_vm_resource_groups:
  - "<resource_group_name>"

keyed_groups:
  - prefix: ''
    separator: ''
    key: tags.gitlab_node_type | default('ungrouped')
  - prefix: ''
    separator: ''
    key: tags.gitlab_node_level | default('ungrouped')
```

- `plugin` - The name of the Dynamic Inventory plugin. Must always be `azure.azcollection.azure_rm`.
- `resource_group_name` - The name of the resource group previously created in the [Create Azure Resource Group](environment_prep.md#1-create-azure-resource-group) step.
- `keyed_groups` - Configures Ansible to look for the tags automatically set by Terraform and to set up its host groups based on them. This config block shouldn't be changed from what's shown.

##### Configure Authentication (Azure)

Finally, the last thing to configure is authentication. This is required to allow Ansible to access Azure to build its dynamic inventory.

Ansible provides several ways to authenticate with [Azure](https://docs.ansible.com/ansible/latest/collections/azure/azcollection/azure_rm_inventory.html#parameter-auth_source), you can select any method that is desired.

If you are planning to run the toolkit locally, use [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) authentication method; The credentials will be sourced from the Azure CLI profile. Otherwise, you can use either [Service Principal Credentials](https://docs.ansible.com/ansible/latest/scenario_guides/guide_azure.html#using-service-principal) or [Active Directory Username/Password](https://docs.ansible.com/ansible/latest/scenario_guides/guide_azure.html#using-active-directory-username-password). Refer to [Authenticating to Azure](https://docs.ansible.com/ansible/latest/scenario_guides/guide_azure.html#authenticating-with-azure) documentation for details. Once you have selected the authentication method and obtained the credentials you may export them as [Environment Variables](https://docs.ansible.com/ansible/latest/scenario_guides/guide_azure.html#using-environment-variables) following the Ansible instructions for the specific authentication type.

### Configure Variables

Next we need to configure various Environment specific variables that Ansible will use when configuring GitLab. This is done by setting Inventory variables in separate files alongside the dynamic inventory to ensure the variables are used only for the specific environment.

The structure of these files are flexible, ansible will merge all YAML files that are saved beside the Dynamic Inventory file. For the Toolkit, we use the following files:

- `vars.yml` - Contains all main config specific to the environment such as connection details, component settings, passwords and more.

#### Environment Config: `vars.yml`

Starting with the main environment config file, `vars.yml`, which should be **saved in the same folder as the Dynamic Inventory file**, e.g. `ansible/environments/<env_name>/inventory`. This is important as Ansible will load this file alongside the Dynamic Inventory file at runtime to get all the variables.

Here's an example of the file with all standard config and descriptions below. Items in `<>` brackets need to be replaced with your config. It's worth noting that this is config for a standard install and further variables may be required for more advanced deployments, where applicable we detail these under the relevant section in our [Advanced docs sections](environment_advanced.md).

```yml
all:
  vars:
    # Ansible Settings
    ansible_user: "<ssh_username>"
    ansible_ssh_private_key_file: "<private_ssh_key_path>"

    # Cloud Settings, available options: gcp, aws, azure, none
    cloud_provider: "gcp"

    # GCP only settings
    gcp_project: "<gcp_project_id>"


    # AWS only settings
    aws_region: "<aws_region>"

    # Azure only settings
    azure_storage_account_name: "<storage_account_name>"
    azure_storage_access_key: "<storage_access_key>"

    # General Settings
    prefix: "<environment_prefix>"
    external_url: "<external_url>"
    gitlab_license_file: "<gitlab_license_file_path>"

    # Component Settings
    patroni_remove_data_directory_on_rewind_failure: false
    patroni_remove_data_directory_on_diverged_timelines: false

    # Passwords / Secrets
    gitlab_root_password: '<gitlab_root_password>'
    postgres_password: '<postgres_password>'
    patroni_password: '<patroni_password>'
    consul_database_password: '<consul_database_password>'
    gitaly_token: '<gitaly_token>'
    pgbouncer_password: '<pgbouncer_password>'
    redis_password: '<redis_password>'
    praefect_external_token: '<praefect_external_token>'
    praefect_internal_token: '<praefect_internal_token>'
    praefect_postgres_password: '<praefect_postgres_password>'
```

Ansible Settings are specific config for Ansible to be able to connect to the machines:

- `ansible_user` - The SSH username that Ansible should use to SSH into the machines with. Previously created in the `Setup SSH Authentication` step ([GCP](environment_prep.md#4-setup-ssh-authentication-ssh-os-login-for-gcp-service-account), [AWS](environment_prep.md#2-setup-ssh-authentication-aws), [Azure](environment_prep.md#3-setup-ssh-authentication-azure)).
- `ansible_ssh_private_key_file` - Path to the private SSH key file. Previously created in the `Setup SSH Authentication` step ([GCP](environment_prep.md#4-setup-ssh-authentication-ssh-os-login-for-gcp-service-account), [AWS](environment_prep.md#2-setup-ssh-authentication-aws), [Azure](environment_prep.md#3-setup-ssh-authentication-azure))

Cloud settings are specific config relating to the cloud provider is running on. They're used primarily for the parts of the environment that require direct configuration on the provider, e.g. Object Storage.

- `cloud_provider` - Toolkit specific variable, used to dynamically configure cloud provider specific areas such as Object Storage. Should be set to `gcp`, `aws` or `azure`.
- `gcp_project` **_GCP only_** - ID of the GCP project. Note this must be the Project's unique ID and not just the name
- `aws_region`  **_AWS only_** - AWS region the environment will run in.
- `aws_s3_endpoint` **_AWS only_** - A specific service endpoint for S3 transactions. If not specified, AWS uses the default regional endpoint. See [AWS S3 endpoint documentation](https://docs.aws.amazon.com/general/latest/gr/rande.html) for more details.

- `storage_account_name` **_Azure only_** - The name of the storage account previously created in the [Setup Terraform State Storage - Azure Blob Storage](environment_prep.md#4-setup-terraform-state-storage-azure-blob-storage) step.
- `storage_access_key` **_Azure only_** - The access key of the storage account previously obtained in the [Setup Terraform State Storage - Azure Blob Storage](environment_prep.md#4-setup-terraform-state-storage-azure-blob-storage) step.

General settings are config used across the playbooks to configure GitLab:

- `prefix` - The configured prefix for the environment as set in Terraform.
- `external_url` - External URL that will be the main address for the environment. This can be a DNS hostname you've configured to point to the IP you created on the `Create Static External IP` step ([GCP](environment_prep.md#6-create-static-external-ip-gcp), [AWS](environment_prep.md#4-create-static-external-ip-aws-elastic-ip-allocation), [Azure](environment_prep.md#5-create-static-external-ip-azure)) step or the IP itself in URL form, e.g. `http://1.2.3.4`.
- `gitlab_license_file` - Local path to a valid GitLab License file. Toolkit will upload the license to the environment. Note that this is an optional setting.
  - If you purchased a GitLab subscription, use `gitlab_subscription_activation_code` instead of `gitlab_license_file` variable. An [activation code](https://docs.gitlab.com/ee/user/admin_area/license.html#activate-gitlab-ee) can be obtained from the Customers Portal.
- `gitlab_license_text` - An alternative to `gitlab_license_file` if the license is not stored in a local file, pass the license contents directly to Ansible. Either `gitlab_license_text`, or `gitlab_license_file`, or neither, should be set, but not both. This approach can be used to retrieve the license via a lookup. Note that this is an optional setting.

Component settings are specific component for GitLab components, e.g. Postgres:

- `patroni_remove_data_directory_on_rewind_failure` - A specific Patroni flag that enables resetting of database data on a secondary node if attempts to sync with the primary can't be achieved. **This may lead to data loss**, refer to the [GitLab Postgres documentation](https://docs.gitlab.com/ee/administration/postgresql/replication_and_failover.html#customizing-patroni-failover-behavior) for further info.
- `patroni_remove_data_directory_on_diverged_timelines` - A specific Patroni flag that enables resetting of database data on a secondary node if timelines have diverged with the primary. **This may lead to data loss**, refer to the [GitLab Postgres documentation](https://docs.gitlab.com/ee/administration/postgresql/replication_and_failover.html#customizing-patroni-failover-behavior) for further info.

Passwords and Secrets settings are what they suggest - all the various passwords and secrets that GitLab requires to be configured by the user.

- `gitlab_root_password` - Sets the password for the root user on first installation.
- `postgres_password` - Sets the password for the [GitLab's default Postgres user](https://docs.gitlab.com/ee/administration/postgresql/replication_and_failover.html#postgresql-information).
- `patroni_password` - Sets the password for the [Patroni REST API](https://docs.gitlab.com/ee/administration/postgresql/replication_and_failover.html#patroni-information) (GitLab 14.1+).
- `consul_database_password` - Sets the password for [Consul's database user](https://docs.gitlab.com/ee/administration/postgresql/replication_and_failover.html#consul-information). Required for Postgres HA.
- `pgbouncer_password` - Sets the password for [GitLab's default PgBouncer user](https://docs.gitlab.com/ee/administration/postgresql/replication_and_failover.html#pgbouncer-information)
- `redis_password` - Sets the password for [Redis](https://docs.gitlab.com/ee/administration/redis/replication_and_failover.html#step-1-configuring-the-primary-redis-instance).
- `praefect_external_token` **_Gitaly Cluster only_** - Sets the [external access token for Gitaly Cluster and Praefect](https://docs.gitlab.com/ee/administration/gitaly/praefect.html#secrets).
- `praefect_internal_token` **_Gitaly Cluster only_** - Sets the [internal access token for Gitaly Cluster and Praefect](https://docs.gitlab.com/ee/administration/gitaly/praefect.html#secrets).
- `praefect_postgres_password` **_Gitaly Cluster only_** - Sets the [password for Praefect's database user](https://docs.gitlab.com/ee/administration/gitaly/praefect.html#secrets).
- `gitaly_token` **_Gitaly Sharded only_** - Sets the [shared authentication token for Gitaly](https://docs.gitlab.com/ee/administration/gitaly/#configure-gitaly). Only used in [Gitaly Sharded](environment_advanced.md#gitaly-setups-cluster-or-sharded) setups.

#### Notable Optional Config

There are [various variables available](#full-config-list-and-further-examples) that optionally control how Ansible configures the environment. In this section though we'll call out some notable ones.

##### GitLab Omnibus Installation Options

By default, the Toolkit will deploy the latest [GitLab EE Omnibus package](https://packages.gitlab.com/gitlab/gitlab-ee) via the official repo. However, there are other methods with options available.

:information_source:&nbsp; Note that the [standard GitLab Upgrade rules still apply](https://docs.gitlab.com/ee/update/#upgrade-paths) when upgrading across multiple GitLab versions. You should refer to the docs to ensure the intended upgrade can be performed directly or if you need to upgrade to a certain version first.

The package can be installed via two different methods - Repository or Direct. Below we detail each and the options available:

###### Repository

The main method for installing the GitLab Omnibus package is from the [official repository](https://packages.gitlab.com/gitlab/gitlab-ee). This is the default method the Toolkit will look to use to both install and upgrade the package on subsequent runs.

This method can be customised in several ways via the following variables in your [`vars.yml`](#environment-config-varsyml) file as follows:

- `gitlab_version` - Sets the GitLab version to be installed from the repo. This should be set to the full semantic version, e.g. `14.0.0`. If left unset the Toolkit will look to install the latest version. Optional, default is `''`.
- `gitlab_edition` - Sets the GitLab edition to install, i.e. CE or EE. If left unset the Toolkit will look to install the EE edition as recommended for the Reference Architectures. Note that several components of the GitLab architecture are only available in the EE package such as Consul, PgBouncer and Patroni (Postgres HA), CE can only be configured on environments that don't have these components such as the [1k](https://docs.gitlab.com/ee/administration/reference_architectures/1k_users.html) and [2k](https://docs.gitlab.com/ee/administration/reference_architectures/2k_users.html) Reference Architectures. Optional, default is `gitlab-ee`.
- `gitlab_repo_script_url` - The URL of the installation script to use to set up the repo. Should only be changed if a custom repo is to be used. Optional, defaults to the official GitLab repository installation script for the selected `gitlab_edition` and OS. Can also be specified via the environment variable `GITLAB_REPO_SCRIPT_URL`.
- `gitlab_repo_package` - The full name of the GitLab package to be installed from the repo. Should only be changed if a custom package is to be used. Optional, defaults to the official package name for the selected `gitlab_edition` and `gitlab_version` (if specified). Can also be specified via the environment variable `GITLAB_REPO_PACKAGE`.

###### Direct

The GitLab Omnibus package can also be installed directly, for example a `.deb` or `.rpm` file. This is an alternative method for installing GitLab when access to a repo isn't desired. In this setup the file must be provided to the Toolkit locally or from a reachable URL.

This method can be customised in several ways via the following variables in your [`vars.yml`](#environment-config-varsyml) file as follows:

- `gitlab_deb_host_path` / `gitlab_rpm_host_path` - The local path of the installation file the Toolkit should use. Should not be used if file is to be downloaded from a URL via `gitlab_*_download_url`. Optional, default is `''`. Can also be specified via the environment variable `GITLAB_HOST_DEB_PATH` / `GITLAB_HOST_RPM_PATH`.
- `gitlab_deb_download_url` / `gitlab_rpm_download_url` - The remote URL of the installation file the Toolkit should use. Should not be used if the file is to be copied locally via `gitlab_*_host_path`. Optional, default is `''`. Can also be specified via the environment variable `GITLAB_DEB_DOWNLOAD_URL` / `GITLAB_RPM_DOWNLOAD_URL`.
  - `gitlab_deb_download_url_headers` / `gitlab_rpm_download_url_headers` - Additional headers to use when downloading the installation file from the remote URL set via `gitlab_*_download_url`, such as authorization. These need to be given in a dictionary format, e.g. `{ "Authorization": "Basic <TOKEN>" }`. Optional, default is `{}`. Can also be specified via the environment variable `GITLAB_DEB_DOWNLOAD_URL_HEADERS` / `GITLAB_RPM_DOWNLOAD_URL_HEADERS`.
- `gitlab_deb_target_path` / `gitlab_rpm_target_path` - The path where to store the installation file on the target machine. Optional, default is `tmp/gitlab_deb_package.deb` / `/tmp/gitlab_rpm_package.rpm`. Can also be specified via the environment variable `GITLAB_TARGET_DEB_PATH` / `GITLAB_TARGET_RPM_PATH`.

##### Object Storage Options

There are several options available in Ansible on how to configure Object Storage as detailed below.

###### Object Storage List

The `gitlab_object_storage_list` variable tells Ansible what Object Storage buckets it should expect to configure GitLab with. By default, this variable is configured to expect every bucket as this is the equivalent default in Terraform via the `object_storage_buckets` variable. This should only be changed in advanced scenarios where not all expected buckets are available, such as when the Object Storage buckets list has been modified in Terraform or if you're deploying On Prem.

###### Object Storage Prefix

If the `object_storage_prefix` variable was used in Terraform to change what prefix is used for the buckets then this should also be configured in Ansible via `gitlab_object_storage_prefix`.

#### Full config list and further examples

The default Ansible config is defined as [Role Defaults](https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#understanding-variable-precedence) to ensure correct precedence in the [`common_vars`](../ansible/roles/common_vars/defaults/main.yml) role.

Additional config can be found in the following locations:

- `group_vars/<group_name>.yml` - Variables specific to a group of nodes.
- `<role>/defaults/main.yml` - Variables specific to that role.

As mentioned earlier, we may also refer to additional variables in detail later in these docs under the [Advanced sections](environment_advanced.md) where they are applicable.

#### Sensitive variable handling in Ansible

As shown above, various sensitive variables such as passwords are required when configuring GitLab with the Toolkit. Storing passwords in plaintext should always be avoided in production systems and with any files stored in source control.

The Toolkit has been designed to be open in terms of sensitive variables as there are various strategies that could be used to secure them depending on your preferences. As long as the variables are configured in Ansible at runtime the Toolkit isn't concerned where they come from.

One of these strategies is [Ansible Lookup plugins](https://docs.ansible.com/ansible/latest/plugins/lookup.html), which can be configured to pull in variables from various sources such as Environment Variables or Secret Managers.

There are numerous available [Lookup plugins](https://docs.ansible.com/ansible/latest/collections/index_lookup.html) that you could use here based on your preferences or requirements. Below are some examples of select plugins that are well suited to this to give you an idea of how to do this.

##### Environment Variables

It's possible to set your passwords as Environment Variables and then configure the Toolkit to pull these in at runtime via the [`env lookup` plugin](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/env_lookup.html).

For example if you set an environment variable containing the GitLab Rails password named `GITLAB_RAILS_PASSWORD` Ansible can be configured to use this as follows in your [`vars.yml`](#environment-config-varsyml) file:

```yaml
gitlab_rails_password: "{{ lookup('env', 'GITLAB_RAILS_PASSWORD') }}"
```

This option is particularly useful for usage in CI, where passing variables in via Environment Variables is common.

##### Secret Managers

There are several plugins available for well known Secret Managers such as [AWS Secret Manager](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_secret_lookup.html) or [HashiCorp Vault](https://docs.ansible.com/ansible/latest/collections/community/hashi_vault/hashi_vault_lookup.html).

These sorts of plugins will typically need authentication configured, which is usually done via environment variables (refer to each plugin's docs for more info).

As an example - AWS Secret Manager can be favourable here for AWS environments as the same authentication is used as the one for the Dynamic Inventory, so no further authentication is required. If we had a secret configured in AWS Secret Manager for GitLab Rails Password called `gitlab_rails_password` this can be configured as follows:

```yaml
gitlab_rails_password: "{{ lookup('amazon.aws.aws_secret', 'gitlab_rails_password', region=aws_region) }}"
```

Note that region is required here but since you've already configured it earlier in your `vars.yml` file as `aws_region` this can be reused.

## 3. Run the GitLab Environment Toolkit's Docker container (optional)

Before running the [Docker container](https://gitlab.com/gitlab-org/gitlab-environment-toolkit/container_registry/2697240) you will need to set up your environment files by following [2. Set up the Environment's Inventory and Config](#2-set-up-the-environments-inventory-and-config). The container can be started once the files have been configured. When starting the container it is important to pass in your environment files and keys, as well as set any authentication based environment variables.

Below is an example of how to run the container when using a GCP service account:

```sh
docker run -it \
  -e GOOGLE_APPLICATION_CREDENTIALS="/gitlab-environment-toolkit/keys/<service account file>" \
  -v <path to keys directory>:/gitlab-environment-toolkit/keys \
  -v <path to Ansible environment>:/gitlab-environment-toolkit/ansible/environments/<environment name> \
  registry.gitlab.com/gitlab-org/gitlab-environment-toolkit:latest
```

You can also use a simplified command if you store your environment outside the toolkit. Using the folder structure below you're able to store multiple environments alongside each other and when using the Toolkit's container you can simply pass in a single folder and still have access to all your different environments.

```sh
get_environments
├──keys
└──<environment name>
|  └──ansible
|     └── inventory
|     |   ├── <environment name>.gcp.yml
|     |   └── vars.yml
|     └── files
└──<environment name>
   └──ansible
      └── inventory
```

```sh
docker run -it \
  -e GOOGLE_APPLICATION_CREDENTIALS="/gitlab-environment-toolkit/keys/<service account file>" \
  -v <path to `get_environments` directory>:/environments \
  registry.gitlab.com/gitlab-org/gitlab-environment-toolkit:latest
```

## 4. Configure

After the config has been set up you're now ready to configure the environment. This is done as follows:

1. `cd` to the `ansible/` directory if not already there.
1. (Optional) Run `ansible` module `ping` with the intended environment's inventory to list hosts which have been selected.

    ```shell
    ansible all -m ping -i environments/10k/inventory --list-hosts
    ```

1. Run `ansible-playbook` with the intended environment's inventory against the `all.yml` playbook

    ```shell
    ansible-playbook -i environments/10k/inventory playbooks/all.yml
    ```

    - Note that we pass the whole inventory folder - `environments/10k/inventory`. This ensures Ansible reads all the files in the directory.
    - If you only want to run a specific playbook & role against the respective VMs you can switch out `all.yml` and replace it with the intended playbook, e.g. `gitlab_rails.yml`

The same commands are used when you wish to update an existing environment.

:information_source:&nbsp; If you ever want to uninstall GitLab, you can do so by running:

```shell
ansible-playbook -i environments/10k/inventory playbooks/uninstall.yml
```

### Running with Ansible Collection (optional)

The Toolkit's Ansible Playbooks and Roles can be installed and run as a [Collection](https://docs.ansible.com/ansible/latest/user_guide/collections_using.html). Through this method you don't need the source code available locally to run, only your own Inventory and Variables.

To use this method all that's required is to install the Collection from this repo and then run it as normal.

First, installing the Collection is done as standard via the `ansible-galaxy` command from this repo:

:information_source:&nbsp; The Collection can only be installed from this repo as shown below and isn't available from Ansible Galaxy due to license compliance.

```shell
ansible-galaxy collection install git+https://gitlab.com/gitlab-org/gitlab-environment-toolkit.git#/ansible/
```

Once installed you can then run the Collection in [several possible ways](https://docs.ansible.com/ansible/latest/user_guide/collections_using.html). As an example you can run the `all` playbook directly via the collection name as follows:

```shell
ansible-playbook -i environments/50k/inventory gitlab.gitlab_environment_toolkit.all
```

## Steps after deployment

With the above steps completed you should now have a running environment. Head to the external address you've configured and try logging in to check.

Next you should consider any [advanced setups](environment_advanced.md) you may wish to explore, the notes on [Upgrades](environment_upgrades.md) as well as reading through the [considerations after deployment](environment_post_considerations.md) such as backups and security.
