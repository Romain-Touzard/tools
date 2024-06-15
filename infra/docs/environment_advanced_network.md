# Advanced - Network Setup

- [GitLab Environment Toolkit - Quick Start Guide](environment_quick_start_guide.md)
- [GitLab Environment Toolkit - Preparing the environment](environment_prep.md)
- [GitLab Environment Toolkit - Provisioning the environment with Terraform](environment_provision.md)
- [GitLab Environment Toolkit - Configuring the environment with Ansible](environment_configure.md)
- [GitLab Environment Toolkit - Advanced - Custom Config / Tasks / Files, Data Disks, Advanced Search, Container Registry and more](environment_advanced.md)
- [GitLab Environment Toolkit - Advanced - Cloud Native Hybrid](environment_advanced_hybrid.md)
- [GitLab Environment Toolkit - Advanced - Component Cloud Services / Custom (Load Balancers, PostgreSQL, Redis)](environment_advanced_services.md)
- [GitLab Environment Toolkit - Advanced - SSL](environment_advanced_ssl.md)
- [**GitLab Environment Toolkit - Advanced - Network Setup**](environment_advanced_network.md)
- [GitLab Environment Toolkit - Advanced - Monitoring](environment_advanced_monitoring.md)
- [GitLab Environment Toolkit - Upgrades (Toolkit, Environment)](environment_upgrades.md)
- [GitLab Environment Toolkit - Considerations After Deployment - Backups, Security](environment_post_considerations.md)
- [GitLab Environment Toolkit - Geo](geo/README.md)
  - [GitLab Environment Toolkit - Geo - Provisioning the environment with Terraform](geo/geo_provision.md)
  - [GitLab Environment Toolkit - Geo - Configuring the environment with Ansible](geo/geo_configure.md)
  - [GitLab Environment Toolkit - Geo - Advanced](geo/geo_advanced.md)
- [GitLab Environment Toolkit - Troubleshooting](environment_troubleshooting.md)

By default, the Toolkit will configure network setup using the default cloud provider's network. However, it can also support other advanced setups on select cloud providers such as creating a new network or using an existing one.

On this page we'll detail all the supported advanced setups you can do with the Toolkit. We recommend you only do these setups if you have a good working knowledge of both the Toolkit and what the specific setups involve.

:exclamation:&nbsp; **{- Changing network setup on an existing environment must be treated with the utmost caution-}**. **Doing so can be considered a significant change and may trigger the recreation of the entire environment leading to data loss**.

[[_TOC_]]

## Configure network setup (GCP)

The module for GCP can configure the [network stack](https://cloud.google.com/vpc/docs/vpc) (For example VPC or Subnets) for your environment in several ways:

- **Default** - Sets up the infrastructure on the default network stack as provided by GCP. This is the default for the module.
- **Created** - Creates the required network stack for the infrastructure.
- **Existing** - Will use a provided network stack passed in by the user.

In this section you will find the config required to set up each depending on your requirements.

:exclamation:&nbsp; **{- Changing network setup on an existing environment must be treated with the utmost caution-}**. **Doing so can be considered a significant change in GCP and may trigger the recreation of the entire environment leading to data loss**.

### Default (GCP)

This is the default setup for the module and is the recommended setup for most standard (Omnibus) environments where GCP will handle the networking by default.

No additional configuration is needed to use this setup.

To lock down network access to particular CIDR blocks follow [Configuring Network CIDR Access](#configuring-network-cidr-access) guidance.

### Created (GCP)

When configured the module will create a network stack to run the environment in. The network stack created is as follows:

- 1 VPC
- 1 Subnet
- Firewall rules to allow for required network connections

The environment's machines will be created in the created subnet.

This setup is recommended for users who want a specific network stack for their GitLab environment.

To configure this setup the following config should be added to the [module's environment config file](environment_provision.md#configure-module-settings-environmenttf):

- `create_network` - This variable should be set to `true` when you are wanting the module to create a new network stack.

An example of your environment config file then would look like:

```tf
module "gitlab_ref_arch_gcp" {
  source = "../../modules/gitlab_ref_arch_gcp"

  prefix = var.prefix
  project = var.project

  create_network = true

  [...]
```

In addition to the above the following _optional_ settings change how the network is configured:

- `subnet_cidr`- A [CIDR block](https://cloud.google.com/vpc/docs/vpc#manually_created_subnet_ip_ranges) that will be used for the created subnet. This shouldn't need to be changed in most scenarios unless you want to use a specific CIDR blocks. Default is `"10.86.0.0/16"`

### Existing (GCP)

For this advanced setup, you must have an existing network stack for the environment to use.

Ensure the network stack is configured correctly. Generally, a stack should include the same elements as listed in the **Created** section for the environment to work properly. Refer to the GCP docs for more info and specifics on how to do this.

Note that when this is configured the module will configure some GCP Firewall rules in your VPC to enable network access for the environment.

With an existing stack configure the following config should be added to the [module's environment config file](environment_provision.md#configure-module-settings-environmenttf):

- `vpc_name` - The name of your existing VPC.
- `subnet_name` - The name of your existing Subnet. The subnet should be located in the same existing VPC.

An example of your environment config file then would look like:

```tf
module "gitlab_ref_arch_gcp" {
  source = "../../modules/gitlab_ref_arch_gcp"

  prefix = var.prefix
  project = var.project

  vpc_name = "<vpc-name>"
  subnet_name = "<subnet-name>"

  [...]
}
```

### Disable External IPs (GCP)

On any of the network types above it's also possible to disable GCP provisioning external IPs for any VMs.

This is done in Terraform with the `setup_external_ips` variable being set to false in your `environment.tf` file.

**GCP**

```tf
module "gitlab_ref_arch_gcp" {
  source = "../../modules/gitlab_ref_arch_gcp"
[...]

  setup_external_ips = false
}
```

Once set, no external IPs will be created or added to your nodes.

In this setup however some tweaks will need to be made to Ansible:

- It will need to be run from a box that can access the boxes via internal IPs
- The `external_url` setting should be set to the URL that the instance will be reachable internally
- When using the Dynamic Inventory it will need to be adjusted to return internal IPs. This can be done by changing the `compose.ansible_host` setting to `private_ip_address`

## Configure network setup (AWS)

By default, the toolkit sets up the infrastructure on the default network stack as provided by AWS. However, it can also support other advanced setups such as creating a new network or using an existing one.

The module for AWS can configure the [network stack](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html) (For example VPC or Subnets) for your environment in several ways:

- **Default** - Sets up the infrastructure on the default network stack as provided by AWS. This is the default for the module.
- **Created** - Creates the required network stack for the infrastructure
- **Existing** - Will use a provided network stack passed in by the user

Additionally, for the Created and Existing network types above you can configure the subnets used to be private or public.

In this section you will find the config required to set up each depending on your requirements.

:exclamation:&nbsp; **{- Changing network setup on an existing environment must be avoided-}**. **Doing so is considered a significant change in AWS and will essentially trigger the recreation of the entire environment leading to data loss**.

### Default (AWS)

This is the default setup for the module where AWS will handle the networking by default. No additional configuration is needed to use this setup.

To lock down network access to particular CIDR blocks follow [Configuring Network CIDR Access](#configuring-network-cidr-access) guidance.

### Created (AWS)

When configured the module will create a network stack to run the environment in. The network stack created is as follows:

- 1 VPC
- 2 Subnets are created in the created VPC and are additionally spread across the available Availability Zones in the selected region.
  - The number of Subnets is configurable.
- 1 Internet Gateway
- 1 Route Table

The environment's machines will be spread across the created subnets and their Availability Zones evenly.

This setup is recommended for users who want a specific network stack for their GitLab environment. It's also recommended for Cloud Native Hybrid environments running on AWS.

To configure this setup the following config should be added to the [module's environment config file](environment_provision.md#configure-module-settings-environmenttf):

- `create_network` - This variable should be set to `true` when you are wanting the module to create a new network stack.

An example of your environment config file then would look like:

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  prefix = var.prefix
  ssh_public_key = file(var.ssh_public_key_file)

  create_network = true

  [...]
```

In addition to the above the following _optional_ settings change how the network is configured:

- `vpc_cidr_block` - The [CIDR block](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html#vpc-ip-addressing) that will be used for your VPC. This shouldn't need to be changed in most scenarios unless you want to use a specific CIDR block. Default is `172.31.0.0/16`.
- `subnet_pub_count` - The number of subnets to create in the VPC. This should only be changed if you want an increased subnet count for availability reasons. Refer to the below [Created Subnet Types (Public / Private)](#created-subnet-types-public-and-private) section for more info. Default is `2`.
- `subnet_pub_cidr_block`- A list of [CIDR blocks](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html#vpc-ip-addressing) that will be used for each public subnet created. This should be changed if you want to use specific CIDR blocks. Default is `["172.31.0.0/20","172.31.16.0/20","172.31.32.0/20"]`
  - The module has up to 3 subnet CIDR blocks it will use. If you have set `subnet_pub_count` higher than 3 then this variable will need to be adjusted to match the number of subnets to be created. The CIDR blocks will need to fit in the main block defined for the VPC via `vpc_cidr_block`.
- `subnet_priv_count` - The number of private subnets to create in the VPC. This should be changed if you want more resources to be created with private subnets. Refer to the below [Created Subnet Types (Public / Private)](#created-subnet-types-public-and-private) section for more info. Default is `0`.
- `subnet_priv_cidr_block`- A list of [CIDR blocks](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html#vpc-ip-addressing) that will be used for each private subnet created. This should be changed if you want to use specific CIDR blocks. Default is `["172.31.128.0/20", "172.31.144.0/20", "172.31.160.0/20"]`
  - The module has up to 3 subnet CIDR blocks it will use. If you have set `subnet_priv_count` higher than 3 then this variable will need to be adjusted to match the number of subnets to be created. The CIDR blocks will need to fit in the main block defined for the VPC via `vpc_cidr_block`.
- `zones_exclude` - In rare cases you may need to avoid specific Availability Zones [as they don't have the available resource to deploy the infrastructure in](https://aws.amazon.com/premiumsupport/knowledge-center/eks-cluster-creation-errors/). When this is the case you can specify a list of Zones by name via this setting that will then be avoided by the Toolkit, e.g. `["us-east-1e"]`. Default is `null`.
- `availability_zones` - Availability Zones resources should be spread across. By default, (subject to `zones_exclude`) zones are  automatically chosen in the VPC by lexical order (i.e. when two subnets are requested they will be in the zones with suffixes `a`, `b`). In some circumstances (e.g. exposing services via PrivateLink to other accounts) it may be desirable to choose the Availability Zones more precisely but still allow the Toolkit to create all the resources. In these cases, you can supply the list of Zones to use. If you supply fewer zones than the number of subnets, zones will be re-used in round-robin order; if you supply more zones than the number of subnets (N), only the first N zones will be used. `zones_exclude` will _not_ be applied to this list. Default is `[]`.

#### Created Subnet Types (Public and Private)

When creating a network the Toolkit supports creating both Public and Private subnets.

There are several possible combinations supported. The Toolkit will dynamically configure each based on what's been configured via the  `subnet_pub_count` and `subnet_priv_count` settings as follows:

- Public Subnets - The default. All resources are placed in public subnets and have public IPs.
  - When `subnet_pub_count` is higher than `0` and `subnet_priv_count` is `0`.
- Public + Private Subnets - All resources are placed in Private subnets by default except for those externally facing (HAProxy External, EKS Cluster + EKS Supporting Node that runs NGinx).
  - When `subnet_pub_count` is higher than `0` and `subnet_priv_count` is higher than `0`.
  - :information_source:&nbsp; **In this setup the number of Public and Private subnets must be the same**. This is to ensure [NAT Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) can be configured for each private subnet on the corresponding public subnet to allow Internet access.
- Private Subnets - A fully offline environment. All resources are placed in private subnets, additional setup will be required for GitLab to install, such as private OS package repos for example, along with resources such as private links to access.
  - When `subnet_pub_count` is `0` and `subnet_priv_count` is higher than `0`.

:information_source:&nbsp; When Private subnets are being used most VMs won't have a public IP address. As such, when running Ansible it should be run from within the network [with its Dynamic Inventory configured to connect via private IPs](environment_configure.md#amazon-web-services-aws) (`compose.ansible_host` set to `private_ip_address`).

### Existing (AWS)

For this advanced setup, you must have an existing network stack for the environment to use.

Ensure the network stack is configured correctly. Generally, a stack should include the same elements as listed in the **Created** section for the environment to work properly. Refer to the AWS docs for more info and specifics on how to do this.

Note that when this is configured the module will configure some AWS Security Groups in your VPC to enable network access for the environment.

With an existing stack configure the following config should be added to the [module's environment config file](environment_provision.md#configure-module-settings-environmenttf):

- `vpc_id` - The ID of your existing VPC
- `subnet_pub_ids` - A list of public subnet IDs the environment's machines should be spread across. The subnets should be located in the same existing VPC. Refer to the below [Existing Subnet Types (Public / Private)](#existing-subnet-types-public-and-private) section for more info.
- `subnet_priv_ids` - A list of private subnet IDs the environment's machines should be spread across. The subnets should be located in the same existing VPC and have any desired dependent infrastructure, e.g. NAT Gateway for internet access. Refer to the below [Existing Subnet Types (Public / Private)](#existing-subnet-types-public-and-private) section for more info.

An example of your environment config file with public subnets would look like:

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  prefix = var.prefix
  ssh_public_key = file(var.ssh_public_key_file)

  vpc_id = "<vpc-id>"
  subnet_pub_ids = ["<public-subnet-1-id>", "<public-subnet-2-id>"]

  [...]
```

#### Existing Subnet Types (Public and Private)

When providing an existing network to the Toolkit it also supports the passthrough of public / private subnets.

There are several possible combinations supported. The Toolkit will dynamically configure each based on what's been configured via the `subnet_pub_ids` and `subnet_priv_ids` settings as follows:

- Public Subnets - The default. All resources are placed in public subnets and have public IPs.
  - When `subnet_pub_ids` is higher than `0` and `subnet_priv_ids` is `0`.
- Public + Private Subnets - All resources are placed in Private subnets by default except for those externally facing (HAProxy External and EKS Cluster).
  - When `subnet_pub_ids` is higher than `0` and `subnet_priv_ids` is higher than `0`.
  - :information_source:&nbsp; In this setup resources running on Private Subnets require Internet access via a [NAT Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) to be configured.
- Private Subnets - A fully offline environment. All resources are placed in private subnets, additional setup will be required for GitLab to install, such as private OS package repos for example, along with resources such as private links to access.
  - When `subnet_pub_ids` is `0` and `subnet_priv_ids` is higher than `0`.

:information_source:&nbsp; When Private subnets are being used most VMs won't have a public IP address. As such, when running Ansible it should be run from within the network [with its Dynamic Inventory configured to connect via private IPs](environment_configure.md#amazon-web-services-aws) (`compose.ansible_host` set to `private_ip_address`).

### Custom Security Groups

The Toolkit manages all the [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html) required for the environment.

In some advanced cases additional security group configuration may be desired depending on the setup, such as allowing access to nodes from custom load balancers or direct access to web frontends.

For these scenarios the Toolkit supports customisation of node Security groups as follows via the [module's environment config file](environment_provision.md#configure-module-settings-environmenttf):

:information_source:&nbsp; It's recommended that these settings be used with caution as misconfigurations may result in exposed access to the selected machines unintentionally.

- `gitlab_rails_security_group_ids` - A list of additional Security Groups IDs for the GitLab Rails nodes. Optional, default is `[]`.
- `monitor_security_group_ids` - A list of additional Security Groups IDs for the Monitor node(s). Optional, default is `[]`.

### Internal Security Group Access (Default / Existing networks)

An Internal Networking security group is created by the Toolkit on AWS that allows for internal networking access to be configured between resources such as VMs or EKS Clusters in the VPC. This group is membership based as a best practice, as a result anything not in this group does not have access.

In some advanced cases though where your resources need internal access, such as a Bastion host on the same VPC, the Toolkit does provide for a way to configure this via [Security Group referencing](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html#security-group-referencing).

In this setup you would put your resources in separate Security Group(s) within the same VPC and in turn pass those group names into the Toolkit. The Internal Networking security group will then be configured to allow internal networking access for resources in those groups. Note that due to the nature of AWS networking this is only applicable to the Default or Existing network types where the network exists separately to allow for other internal resources to be deployed outside the Toolkit.

To pass in your Security Groups to be added for internal access this is done with the following variable in the [module's environment config file](environment_provision.md#configure-module-settings-environmenttf):

:information_source:&nbsp; It's recommended that this setting be used with caution. Full Internal Networking access will be granted to all resources in the configured Security Groups.

- `internal_allowed_ingress_security_group_ids` - A list of additional Security Groups IDs to allow internal networking access to VMs or EKS Clusters. Note that the groups must be in the same VPC as the GitLab resources. Optional, default is `[]`.

## Disable External IPs (Azure)

With Azure there is only one network type available - Created. With this though it's also possible to disable provisioning external IPs for VMs if desired.

This is done in Terraform with the `setup_external_ips` variable being set to false in your `environment.tf` file.

**Azure**

```tf
module "gitlab_ref_arch_azure" {
  source = "../../modules/gitlab_ref_arch_azure"
[...]

  setup_external_ips = false
}
```

Additionally, there's the following optional settings in Terraform:

- `nat_gateway_idle_timeout_in_minutes` - TCP connections [idle timeout](https://docs.microsoft.com/en-us/azure/virtual-network/nat-gateway/nat-gateway-resource#idle-timeout-timers). Default is `4`, can be increased to up to 120 minutes.

Once set no external IPs will be created or added to your nodes.

In this setup however some tweaks will need to be made to Ansible:

- It will need to be run from a box that can access the boxes via internal IPs
- The `external_url` setting should be set to the URL that the instance will be reachable internally

## Configuring Network CIDR Access

The Toolkit has multiple CIDR block settings to allow configuring network access to the environment for both external and internal connections. Through these settings you can restrict network access as required.

By default, the Toolkit will have these settings open to all connections. This is to allow you to get the environment up and running and then to configure the settings as desired, much like a standard build.

Refer to the below sections for more detail.

### External (Terraform)

To lock down external network access to particular CIDR blocks these _optional_ settings can be used in Terraform:

- `default_allowed_ingress_cidr_blocks`- A list of CIDR blocks that configures the IP ranges that will be able to access the network externally. This will apply to all external firewall rules that the Toolkit configures. Default is `["0.0.0.0/0"]`. More granular control over rules are also available via these settings:
  - `http_allowed_ingress_cidr_blocks`- A list of CIDR blocks that configures the IP ranges that will be able to access GitLab over HTTP/HTTPs.
  - `ssh_allowed_ingress_cidr_blocks`- A list of CIDR blocks that configures the IP ranges that will be able to access GitLab over SSH.
  - `external_ssh_allowed_ingress_cidr_blocks`- A list of CIDR blocks that configures the IP ranges that will be able to access the network over SSH.
  - `icmp_allowed_ingress_cidr_blocks`- **GCP and Azure only** - A list of CIDR blocks that configures the IP ranges that will be able to access the network over ICMP.

:exclamation:&nbsp; **{- Changing network setup on an existing environment must be treated with the utmost caution-}**. **Doing so can be considered a significant change in GCP and may trigger the recreation of the entire environment leading to data loss**.

### Internal (Ansible)

To lock down internal network access to particular CIDR blocks these _optional_ settings can be used in Ansible:

- `gitlab_rails_monitoring_cidr_blocks` - A list of CIDR blocks to be allowed access to [GitLab's Health Check endpoints](https://docs.gitlab.com/ee/user/admin_area/monitoring/health_check.html). Required for Load Balancers to perform Health Checks. Note that if changing this setting it should include any Load Balancers performing health checks, including any Toolkit provided HAProxy Load Balancers. Default is `['0.0.0.0/0']`.
- `postgres_trust_auth_cidr_blocks` - A list of CIDR blocks to be allowed access to [Postgres (Omnibus)](https://docs.gitlab.com/omnibus/settings/database.html#configure-postgresql-block). Default is `['0.0.0.0/0']`.
- `postgres_md5_auth_cidr_blocks` - A list of CIDR blocks to be allowed access to [Postgres (Omnibus)](https://docs.gitlab.com/omnibus/settings/database.html#configure-postgresql-block) with authentication. Default is `['0.0.0.0/0']`.
  - :information_source:&nbsp; Changes to this setting currently has some known issues in certain setups - [gitlab-org/omnibus-gitlab#6594](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/6594) and [gitlab-org/omnibus-gitlab#6590](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/6590).
  - :information_source:&nbsp; [There are additional considerations for this setting when using Geo](https://docs.gitlab.com/ee/administration/geo/setup/database.html#postgresql-replication).
- `geo_tracking_postgres_md5_auth_cidr_blocks` - A list of CIDR blocks to be allowed access to [Geo Tracking Postgres (Omnibus)](https://docs.gitlab.com/ee/administration/geo/replication/multiple_servers.html#step-3-configure-the-geo-tracking-database-on-the-geo-secondary-site). Default is `['0.0.0.0/0']`.

## Configuring Internal Connection Type (IPs and Hostnames)

The Toolkit by default uses IPs for internal connections. However, this can be switched to use internal hostnames as discovered by Ansible via the following setting in your [`vars.yml`](environment_configure.md#environment-config-varsyml) file:

- `internal_addr_use_hostnames` - Flag to switch the Toolkit to use internal hostnames for connections. Default is `false`.

:information_source:&nbsp; On the main Cloud Providers internal hostnames are available by default (For more info - [GCP](https://cloud.google.com/compute/docs/internal-dns), [AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-naming.html), [Azure](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances#reverse-dns-considerations)). Terraform output shows the hostnames for each VM. For On Prem installs hostnames and DNS will need to be configured separately.

## Offline Setup Guidance

The Toolkit supports setting up an [offline environment without internet access](https://docs.gitlab.com/ee/topics/offline/quick_start_guide.html). However, this does require some additional manual setup to function properly as there are several areas that the Toolkit expects internet access by default and alternatives need to be put in place accordingly.

In this section we'll detail each of these areas below.

### Ansible Offline Setup

In an offline environment Ansible will need to be run in the same network as the environment itself. As such, the Dynamic Inventory will need to be switched to return internal IPs instead. This can be done for [GCP](environment_configure.md#google-cloud-platform-gcp) / [AWS](environment_configure.md#amazon-web-services-aws) by changing the `compose.ansible_host` setting  to `private_ip_address`. Azure does not need any additional changes.

Additionally, the Toolkit needs to be configured to run in offline mode to stop it from running any actions that require internet access. This is done in Ansible via the following setting in your [`vars.yml`](environment_configure.md#environment-config-varsyml) file:

- `offline_setup` - Configures the Toolkit to avoid any actions that require the internet. Should only be set when there's no Internet access on the target environment. Default is `false`.

### System Packages

The Toolkit installs several system packages, required for GitLab or itself, on each target OS via the official repos as follows:

- Ubuntu / Debian _Main_ - `aptitude curl openssh-server ca-certificates tzdata python3-pip nfs-common postfix jq libpq-dev nvme-cli`
- RHEL _Main, EPEL_ - `curl openssh-server ca-certificates tzdata python3-pip python3-devel nfs-utils postfix jq nvme-cli gcc yum-plugin-versionlock libpq-devel`
- Amazon Linux 2 _Main, EPEL, Postgres_ - `curl openssh-server ca-certificates tzdata python3-pip python3-devel nfs-utils postfix jq nvme-cli gcc yum-plugin-versionlock postgresql-devel`
- Amazon Linux 2023 _Main_ - `openssh-server ca-certificates tzdata python3-pip python3-devel nfs-utils postfix jq nvme-cli gcc yum-plugin-versionlock libpq-devel`

:information_source:&nbsp; For the most up-to-date list of packages it's recommend to check the `system_packages_*` variables [in this file](../ansible/roles/common/defaults/main.yml).

When `offline_setup` is configured the Toolkit will not attempt to set up any repos or install the required packages. As such, you are required to ensure the packages are present before running Ansible. Note this also disables any setup of [Automatic Security Upgrades](environment_advanced.md#automatic-security-upgrades).

There are various ways this can be tackled. While this is outside the scope of this guide, all that's required here is that the packages are present beforehand. Some examples include installing the packages via an [offline repo](https://help.ubuntu.com/community/AptGet/Offline/Repository), directly via `deb` / `rpm` files.

### Python Packages

The Toolkit also installs several Python packages via PyPI as required by Ansible - `requests==2.27.1, google-auth==2.22.0, netaddr==0.8.0, openshift==0.13.2, PyYAML==6.0.1, docker==5.0.3, pexpect==4.8.0, psycopg2==2.9.5`. Note that the packages are version locked as recommend for Python installs.

When `offline_setup` is configured the Toolkit will not attempt to set up these packages. As such, you are required to ensure the packages are present before running Ansible. Similar to [System Packages](#system-packages) this can be done in [several ways](https://pip.pypa.io/en/stable/cli/pip_install/#pip-install-examples) such as installing the packages via an offline PyPI repo or directly.

:information_source:&nbsp; For the most up-to-date list of Python packages it's recommend to check the `python_packages` variable [in this file](../ansible/roles/common/defaults/main.yml).

### GitLab Omnibus Package

[By default](environment_configure.md#gitlab-omnibus-installation-options), the Toolkit will deploy the latest [GitLab EE Omnibus package](https://packages.gitlab.com/gitlab/gitlab-ee) via [the official repo](environment_configure.md#repository).

When `offline_setup` is configured the Toolkit will not attempt to do this. As such, you should configure the Toolkit to [install GitLab directly via a file](environment_configure.md#direct).

### Version Check and Service Ping

While the Toolkit is not setting this up directly, GitLab defaults to enabling a callback Version Check and Service Ping. [Refer to the docs](https://docs.gitlab.com/ee/topics/offline/quick_start_guide.html#disable-version-check-and-service-ping) on how to disable this.
