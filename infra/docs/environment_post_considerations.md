# Considerations After Deployment - Backups, Security

- [GitLab Environment Toolkit - Quick Start Guide](environment_quick_start_guide.md)
- [GitLab Environment Toolkit - Preparing the environment](environment_prep.md)
- [GitLab Environment Toolkit - Provisioning the environment with Terraform](environment_provision.md)
- [GitLab Environment Toolkit - Configuring the environment with Ansible](environment_configure.md)
- [GitLab Environment Toolkit - Advanced - Custom Config / Tasks / Files, Data Disks, Advanced Search, Container Registry and more](environment_advanced.md)
- [GitLab Environment Toolkit - Advanced - Cloud Native Hybrid](environment_advanced_hybrid.md)
- [GitLab Environment Toolkit - Advanced - Component Cloud Services / Custom (Load Balancers, PostgreSQL, Redis)](environment_advanced_services.md)
- [GitLab Environment Toolkit - Advanced - SSL](environment_advanced_ssl.md)
- [GitLab Environment Toolkit - Advanced - Network Setup](environment_advanced_network.md)
- [GitLab Environment Toolkit - Advanced - Monitoring](environment_advanced_monitoring.md)
- [GitLab Environment Toolkit - Upgrades (Toolkit, Environment)](environment_upgrades.md)
- [**GitLab Environment Toolkit - Considerations After Deployment - Backups, Security**](environment_post_considerations.md)
- [GitLab Environment Toolkit - Geo](geo/README.md)
  - [GitLab Environment Toolkit - Geo - Provisioning the environment with Terraform](geo/geo_provision.md)
  - [GitLab Environment Toolkit - Geo - Configuring the environment with Ansible](geo/geo_configure.md)
  - [GitLab Environment Toolkit - Geo - Advanced](geo/geo_advanced.md)
- [GitLab Environment Toolkit - Troubleshooting](environment_troubleshooting.md)

The Toolkit deploys a _base_ GitLab environment based on the [Reference Architectures](https://docs.gitlab.com/ee/administration/reference_architectures/). This is by design as the Toolkit is _one for all_, and it wouldn't be possible to cover every user's specific requirements with a general toolkit.

The goal rather is for the Toolkit to give you a good base to tweak as desired per your requirements. On this page we'll call out common considerations you may want to explore.

[[_TOC_]]

## Backups

The Toolkit doesn't configure any automated backups for the various pieces of data GitLab stores. This is due to there being numerous valid backup strategies that are available for you to consider based on your requirements.

For setting up backups, implement a strategy as per your requirements. Refer to the [main GitLab documentation](https://docs.gitlab.com/ee/raketasks/backup_restore.html) on this subject and how to implement. The following however should also be noted:

- The Toolkit _does_ create a `backups` Object Storage bucket and configures GitLab to use it by default as a convenience with its Rake task. Automated backups aren't configured however so if using this Object Storage as the backup source the actual backup Rake process [should be configured as desired](https://docs.gitlab.com/ee/raketasks/backup_restore.html#configuring-cron-to-make-daily-backups).
- Object Storage buckets such as `uploads` are **not** backed up with the GitLab provided Rake tasks. It's recommended to enable backups for these buckets as per the object storage provider used.

:information_source:&nbsp; If using Terraform from the Toolkit it must be noted that a `terraform destroy` command will **destroy all data and lead to data loss**. Issuing this command in any situation must be considered fully.

## Security

Security is a significant area and typically is very dependent on your specific requirements.

As a general rule the Toolkit will look to use reasonable setup practices in relation to security, but it's **strongly** recommended that you undertake a full review of the environment's setup to ensure it meets your requirements.

In addition to this we have [further documentation on various practices that apply to any GitLab environment that you may also want to consider](https://docs.gitlab.com/ee/security/index.html#securing-your-gitlab-installation).

## Monitoring

[The Toolkit does optionally provide a monitoring stack based on Prometheus](environment_advanced_monitoring.md).

However, do note this is optional and not required to be used. You can use a separate monitoring stack as desired, and the Toolkit aims to provide reasonable hooks for this such as [Custom Tasks](environment_advanced.md#custom-tasks) or [Custom Files](environment_advanced.md#custom-files).

### Logging

By default, the Toolkit doesn't configure any additional logging monitoring outside what's provided by default in Omnibus, Kubernetes and the respective Cloud Providers.

This is due to there being various logging strategies that are available for you to consider based on requirements and cost that's best handled directly.

However, the Toolkit does aim to provide reasonable hooks for you to set up whatever log monitoring as desired such as [Custom Tasks](environment_advanced.md#custom-tasks) or [Custom Files](environment_advanced.md#custom-files).
