# Geo

The Toolkit supports the provisioning and configuration of [GitLab Geo](https://about.gitlab.com/solutions/geo/), where multiple secondary environments can be set up as replicas of the primary for more distributed setups.

In these pages we'll detail how to setup Geo. Only follow this setup if you have a good working knowledge of both the Toolkit and Geo. As such, a good starting point before provisioning a Geo deployment, is to follow the [quick start guide](../environment_quick_start_guide.md) and provision a standard GitLab deployment.

- [GitLab Environment Toolkit - Quick Start Guide](../environment_quick_start_guide.md)
- [GitLab Environment Toolkit - Preparing the environment](../environment_prep.md)
- [GitLab Environment Toolkit - Provisioning the environment with Terraform](../environment_provision.md)
- [GitLab Environment Toolkit - Configuring the environment with Ansible](../environment_configure.md)
- [GitLab Environment Toolkit - Advanced - Custom Config / Tasks / Files, Data Disks, Advanced Search, Container Registry and more](../environment_advanced.md)
- [GitLab Environment Toolkit - Advanced - Cloud Native Hybrid](../environment_advanced_hybrid.md)
- [GitLab Environment Toolkit - Advanced - Component Cloud Services / Custom (Load Balancers, PostgreSQL, Redis)](../environment_advanced_services.md)
- [GitLab Environment Toolkit - Advanced - SSL](../environment_advanced_ssl.md)
- [GitLab Environment Toolkit - Advanced - Network Setup](../environment_advanced_network.md)
- [GitLab Environment Toolkit - Advanced - Monitoring](../environment_advanced_monitoring.md)
- [GitLab Environment Toolkit - Upgrades (Toolkit, Environment)](../environment_upgrades.md)
- [GitLab Environment Toolkit - Considerations After Deployment - Backups, Security](../environment_post_considerations.md)
- [**GitLab Environment Toolkit - Geo**](README.md)
  - [GitLab Environment Toolkit - Geo - Provisioning the environment with Terraform](geo_provision.md)
  - [GitLab Environment Toolkit - Geo - Configuring the environment with Ansible](geo_configure.md)
  - [GitLab Environment Toolkit - Geo - Advanced](geo_advanced.md)
- [GitLab Environment Toolkit - Troubleshooting](../environment_troubleshooting.md)

## Creating a Geo Deployment

When provisioning a Geo deployment there are a few differences to a single environment that need to be made throughout the process to allow the Toolkit to properly manage the deployment:

- Both environments should share the same admin credentials. For example in the case of GCP the same Service Account.
- The GitLab license is shared between all sites. **The license only needs to be applied to the primary site**.

For the most part, the process is the same as when creating a single environment and as such you should follow the steps for a non Geo deployment starting with [Preparing the environment](../environment_prep.md).

The process to build the environments follows the documentation for [Geo for multiple nodes](https://docs.gitlab.com/ee/administration/geo/replication/multiple_servers.html). The high level steps that will be followed are:

1. [Provision at least 2 environments with Terraform](geo_provision.md)
    - Each environment will share some common labels to identify them as being part of the same Geo deployment
    - Each environment will be identified with a unique site name
2. [Configure the environments with Ansible](geo_configure.md)
    - Each environment will work as a separate environment until Geo is configured
3. Configure Geo on the Primary and Secondary sites
    - One environment will be identified as being a Primary site and all others will be a Secondary
