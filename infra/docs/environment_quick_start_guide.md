# Quick Start Guide

- [**GitLab Environment Toolkit - Quick Start Guide**](environment_quick_start_guide.md)
- [GitLab Environment Toolkit - Preparing the environment provider](environment_prep.md)
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

On this page you'll find a Quick Start Guide where we go through the steps with examples on how to set up a GitLab environment required with the Toolkit.

For the purpose of this guide we'll go through the steps required for one of the more common setups - An [Omnibus 10k Reference Architecture](https://docs.gitlab.com/ee/administration/reference_architectures/10k_users.html) on Amazon Web Services (AWS). This will be done by running the Toolkit natively from source via a Git checkout.

:information_source:&nbsp; This quick guide won't cover all the potential options available and assumes a good working knowledge of Terraform, Ansible and GitLab. It's recommended you still read the docs in full to ensure the environment is configured as per your requirements.

[[_TOC_]]

## Prerequisites

Before starting the quick guide there are some prerequisites you should go through below.

:information_source:&nbsp; **Any variable values in this guide with surrounding `<>` brackets indicates that they should be replaced.**

### Select an Environment Name

The Toolkit needs an appropriate environment name for it to name all the infrastructure accordingly. This should be something short and unique.

:information_source:&nbsp; **This will be referred to as `<ENV_NAME>` later in this guide.**

### Select an AWS Region

You should also select an [AWS Region](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-regions) where you want to deploy the environment such as `us-east-1`.

:information_source:&nbsp; **This will be referred to as `<AWS_REGION>` later in this guide.**

### Select Passwords and Tokens

There are various passwords and tokens to be set for GitLab. Later on in the guide you'll be asked to fill these in with any values you desire. You can generate these now or later accordingly.

:information_source:&nbsp; **Passwords will be referred to as `<*_PASSWORD>` and `<*_TOKEN>` respectively later in this guide.**

## 1. Preparing the environment provider

The first step is to [prepare the environment's provider](environment_prep.md). This includes setting up authentication, SSH key, Terraform State and configuring an IP for the environment.

Let's go through each for AWS:

### 1a. Authentication

First we need to sort how Terraform and Ansible will authenticate against AWS.

- [Generate an Access Key on AWS](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey) for the user you intend the Toolkit to use.
- Take the key values and set them to the environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` respectively on the machine you're running the Toolkit

<details><summary>Example command to export environment variables</summary>

```sh
export AWS_ACCESS_KEY_ID="<AWS_ACCESS_KEY_ID>" AWS_SECRET_ACCESS_KEY="<AWS_SECRET_ACCESS_KEY>"
```

</details>

### 1b. SSH Key

Next we need an SSH key to be configured on the machines to allow Ansible access directly to the boxes.

Generating the key itself is as normal and covered in the main [GitLab docs](https://docs.gitlab.com/ee/user/ssh.html#generate-an-ssh-key-pair) (ED25519 recommended). Name the public and private keys as desired and copy them to `gitlab-environment-toolkit/keys`.

:information_source:&nbsp; **The public SSH file name will be referred to as `<SSH_PUBLIC_KEY_FILE_NAME>` and private `<SSH_PRIVATE_KEY_FILE_NAME>` later in this guide.**

### 1c. Terraform State Storage

Next we need a place to save the Terraform State file. It's recommended this is in a remote location as this allows all users ensure they're on the same state.

With AWS this is straightforward as we can store the file on S3 object storage. Create a standard [AWS storage bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html) for this using all the default options in the same region you intend to deploy the environment.

This can be named as desired, but note that **AWS requires the name to be globally unique across all users**. _Avoid_ using `<ENV_NAME>-terraform-state` as Toolkit will create a bucket with this naming format for the [Terraform Module Registry](https://docs.gitlab.com/ee/user/packages/terraform_module_registry/) feature.

:information_source:&nbsp; **The Terraform state Bucket name wil be referred to as `<TERRAFORM_STATE_BUCKET_NAME>` later in this guide.**

### 1d. Static External IP

Finally, the last bit of prep we need is a Static External IP that the environment will use as its address.

Follow [AWS's docs on how to do this](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html#using-instance-addressing-eips-allocating), selecting the default options **making sure to create the IP in the same region as you selected earlier**.

Once created you'll be given an allocation ID and IP address. Keep a note of this to be used later.

:information_source:&nbsp; **The IP will be referred to as `<AWS_IP>` and the allocation ID `<AWS_IP_ALLOCATION_ID>` later in this guide.**

## 2. Provisioning the environment with Terraform

With the prep done [we're now ready to set up the config for Terraform to provision](environment_provision.md) the environment's infrastructure on AWS. This involves installing Terraform, setting up the config and then running Terraform.

Let's go through the steps for each.

Config is recommended to be placed in a new folder named after the environment under the `gitlab-environment-toolkit/terraform/environments` folder, e.g. `gitlab-environment-toolkit/terraform/environments/<ENV_NAME>`.

:information_source:&nbsp; For the purposes of this guide we're running the Toolkit natively from source where the modules are all available on disk.

### 2a. Installing Terraform with `mise`

First we need to install Terraform. To easily switch between Terraform versions we recommend installing with [`mise`](https://github.com/jdx/mise) as follows:

1. Install `mise` as per its [documentation](https://mise.jdx.dev/getting-started.html)
1. In the Toolkit directory, install the default version of Terraform by first adding its plugin and then installing:

    ```sh
    mise install terraform -y
    ```

:information_source:&nbsp; The version of Terraform that's installed is set in the [`.tool-versions` file](../.tool-versions). Other versions can be installed as required.

Terraform should now be installed and ready on your `PATH`.

### 2b. Setup Config

Now we'll set up the Terraform config for the environment. There are 3 config files to configure - Variables (`variables.tf`), Main (`main.tf`) and Environment (`environment.tf`) - as follows:

First is the Variables file, which contains some variables to be used by Terraform for connecting to AWS as well as setting some environment basics such as the AWS Region:

<details><summary>Variables - <code>gitlab-environment-toolkit/terraform/environments/&#60;ENV_NAME&#62;/variables.tf</code></summary>

```tf
variable "prefix" {
  default = "<ENV_NAME>"
}

variable "region" {
  default = "<AWS_REGION>"
}

variable "ssh_public_key_file" {
  default = "../../../keys/<SSH_PUBLIC_KEY_FILE_NAME>"
}

variable "external_ip_allocation" {
  default = "<AWS_IP_ALLOCATION_ID>"
}
```

</details>

Next is the Main file, which configures Terraform how to authenticate against AWS and where to save its state:

<details><summary>Main - <code>gitlab-environment-toolkit/terraform/environments/&#60;ENV_NAME&#62;/main.tf</code></summary>

```tf
terraform {
  backend "s3" {
    bucket = "<TERRAFORM_STATE_BUCKET_NAME>"
    key    = "<ENV_NAME>.tfstate"
    region = "<AWS_REGION>"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}
```

</details>

Finally, we have the Environment file, which configures the Toolkit's modules on how to actually build the environment:

<details><summary>Environment - <code>gitlab-environment-toolkit/terraform/environments/&#60;ENV_NAME&#62;/environment.tf</code></summary>

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  prefix = var.prefix
  ssh_public_key = file(var.ssh_public_key_file)

  # 10k
  consul_node_count = 3
  consul_instance_type = "c5.large"

  opensearch_vm_node_count = 3
  opensearch_vm_instance_type = "c5.4xlarge"

  gitaly_node_count = 3
  gitaly_instance_type = "m5.4xlarge"

  praefect_node_count = 3
  praefect_instance_type = "c5.large"

  praefect_postgres_node_count = 1
  praefect_postgres_instance_type = "c5.large"

  gitlab_rails_node_count = 3
  gitlab_rails_instance_type = "c5.9xlarge"

  haproxy_external_node_count = 1
  haproxy_external_instance_type = "c5.large"
  haproxy_external_elastic_ip_allocation_ids = [var.external_ip_allocation]
  haproxy_internal_node_count = 1
  haproxy_internal_instance_type = "c5.large"

  monitor_node_count = 1
  monitor_instance_type = "c5.xlarge"

  pgbouncer_node_count = 3
  pgbouncer_instance_type = "c5.large"

  postgres_node_count = 3
  postgres_instance_type = "m5.2xlarge"

  redis_cache_node_count = 3
  redis_cache_instance_type = "m5.xlarge"
  redis_persistent_node_count = 3
  redis_persistent_instance_type = "m5.xlarge"

  sidekiq_node_count = 4
  sidekiq_instance_type = "m5.xlarge"
}

output "gitlab_ref_arch_aws" {
  value = module.gitlab_ref_arch_aws
}
```

</details>

With the above config in place we should now be ready to run Terraform.

### 2c. Provision

The machines and infrastructure are now ready to be provisioned with Terraform. This is done via a few commands as follows:

1. Ensure that [Authentication environment variables](#1a-authentication) are set.
1. Change to the Terraform directory under the `gitlab-environment-toolkit` directory:

    ```sh
    cd terraform/environments/<ENV_NAME>
    ```

1. Run `terraform init` to initialize Terraform and perform required preparation such as downloading required providers. This typically only needs to be run once for the first build or after any notable config changes:

    ```sh
    terraform init
    ```

1. Run `terraform apply` to actually provision the infrastructure, a confirmation prompt will be shown by Terraform before proceeding:

    ```sh
    terraform apply
    ```

After Terraform has finished running, the machines and other infrastructure will now be provisioned.

## 3. Configuring the environment with Ansible

With the machines and infrastructure provisioned, we're now ready to [set up Ansible to configure GitLab](environment_configure.md). This involves installing Ansible, setting up the config and then running Ansible.

Let's go through the steps for each.

Config is recommended to be placed in a new folder named after the environment under the `gitlab-environment-toolkit/ansible/environments/` folder, e.g. `gitlab-environment-toolkit/ansible/environments/<ENV_NAME>/inventory`.

:information_source:&nbsp; For the purposes of this guide we're running the Toolkit natively from source where the playbooks and roles are all available on disk.

### 3a. Installing Ansible with a Virtual Environment

First we need to install Ansible. There are various ways to install Ansible, we recommend using Python in a Virtual Environment. Once installed we also need to install some Python and Ansible packages. The steps for all of this are as follows:

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

### 3b. Setup Config

Now we'll set up the Ansible config for the environment. There are 2 config files to configure - Dynamic Inventory (`<ENV_NAME>.aws_ec2.yml`) and Environment (`vars.yml`) - as follows:

:information_source:&nbsp; Note that some of the config we set here matches config set in Terraform.

First is the Dynamic Inventory file, which configures Ansible to retrieve the machine list from AWS and their details:

<details><summary>Dynamic Inventory - <code>gitlab-environment-toolkit/ansible/environments/&#60;ENV_NAME&#62;/inventory/ENV_NAME.aws_ec2.yml</code></summary>

:information_source:&nbsp; Only values in `<>` brackets should be changed in this file and the rest should match. It also must be saved with the suffix `aws_ec2.yml`.

```yaml
plugin: aws_ec2
regions:
  - <AWS_REGION>
filters:
  tag:gitlab_node_prefix: <ENV_NAME>
keyed_groups:
  - key: tags.gitlab_node_type
    separator: ''
  - key: tags.gitlab_node_level
    separator: ''
hostnames:
  # List host by name instead of the default public ip
  - tag:Name
compose:
  # Use the public IP address to connect to the host
  # (note: this does not modify inventory_hostname, which is set via I(hostnames))
  ansible_host: public_ip_address
```

</details>

Next is the Environment config file that contains all the config for configuring GitLab:

<details><summary>Environment - <code>gitlab-environment-toolkit/ansible/environments/&#60;ENV_NAME&#62;/inventory/vars.yml</code></summary>

:information_source:&nbsp; [As mentioned earlier in this guide](#select-passwords-and-tokens) all `<*_PASSWORD>` and `<*_TOKEN>` entries should be replaced with your own.

```yaml
all:
  vars:
    # Ansible Settings
    ansible_user: "ubuntu"
    ansible_ssh_private_key_file: "{{ lookup('env', 'PWD') }}/../keys/<SSH_PRIVATE_KEY_FILE_NAME>"

    # Cloud Settings, available options: gcp, aws, azure
    cloud_provider: "aws"

    # AWS only settings
    aws_region: "<AWS_REGION>"

    # General Settings
    prefix: "<ENV_NAME>"
    external_url: "http://<AWS_IP>"

    # Passwords / Secrets (Replace values accordingly)
    gitlab_root_password: '<GITLAB_ROOT_PASSWORD>'
    postgres_password: '<POSTGRES_PASSWORD>'
    consul_database_password: '<CONSUL_DATABASE_PASSWORD>'
    gitaly_token: '<GITALY_TOKEN>'
    pgbouncer_password: '<PGBOUNCER_PASSWORD>'
    redis_password: '<REDIS_PASSWORD>'
    praefect_external_token: '<PRAEFECT_EXTERNAL_TOKEN>'
    praefect_internal_token: '<PRAEFECT_INTERNAL_TOKEN>'
    praefect_postgres_password: '<PRAEFECT_POSTGRES_PASSWORD>'
```

</details>

### 3c. Configure

GitLab is now ready to be configured with Ansible. This is done via a few commands as follows:

1. Change to the Ansible directory - `cd ansible` in the `gitlab-environment-toolkit` directory.
1. Ensure that [Authentication environment variables](#1a-authentication) are set
1. Run `ansible-playbook -i environments/<ENV_NAME>/inventory playbooks/all.yml` to run through all the playbooks and configure GitLab.

After Ansible has finished running, GitLab will now be configured and the environment ready to go.

## Config Examples

[Full config examples are available for select Reference Architectures](../examples).

## Steps after deployment

With the above steps completed you should now have a running environment. Head to the external address you've configured and try logging in to check.

Next you should consider any [advanced setups](environment_advanced.md) you may wish to explore, the notes on [Upgrades](environment_upgrades.md) as well as reading through the [considerations after deployment](environment_post_considerations.md) such as backups and security.

## Troubleshooting

If you encounter any errors in this process, the [Troubleshooting](environment_troubleshooting.md) page contains further guidance on various common errors seen and how to address them.
