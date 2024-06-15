# Geo

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
- [GitLab Environment Toolkit - Geo](README.md)
  - [GitLab Environment Toolkit - Geo - Provisioning the environment with Terraform](geo_provision.md)
  - [**GitLab Environment Toolkit - Geo - Configuring the environment with Ansible**](geo_configure.md)
  - [GitLab Environment Toolkit - Geo - Advanced](geo_advanced.md)
- [GitLab Environment Toolkit - Troubleshooting](../environment_troubleshooting.md)

[[_TOC_]]

## Ansible

We will need to start by creating new inventories for a Geo deployment. For Geo we will require at least 2 inventories, 1 for each site. It is recommended to store these in one parent folder to keep all the config together.

```bash
ansible
└── environments
    └── my-geo-deployment
        ├── site1
        |   ├── files
        |   └── inventory
        └── site2
            ├── files
            └── inventory
```

For the Linux package and Cloud Native Hybrid environments the inventory for each site should be set up following the standard [non Geo setup steps](../environment_configure.md), the below settings need to be added to enable Geo and only need to be added into the site that corresponds to its role e.g. `geo_primary_external_url` goes into the primary inventory and `geo_secondary_external_url` into the secondary.

- `geo_primary_external_url`/`geo_secondary_external_url` - The external URL for the site, should match `external_url`
- `geo_primary_internal_url`/`geo_secondary_internal_url` - An internal URL or IP address for the main load balancer. Optional, will default to the Geo external URL.
- `geo_primary_site_group_name`/`geo_secondary_site_group_name` - These should match the `geo_site` that was set in Terraform for the site you want to use as a primary/secondary, any `-` should be replaced with `_` as the names are altered when pulled from the cloud provider.
- `geo_primary_site_name`/`geo_secondary_site_name` - A name plain text name for each site, this will be displayed in the main Geo settings page.
- `geo_primary_registry_url` - The URL for the container registry. Optional, will default to `https://registry.{{ Geo primary URL }}`

You can also remove the GitLab license from the sites that will not be set as the primary before running the `ansible-playbook` command. To remove the license from the secondary site you can just remove the `gitlab_license_file` or `gitlab_subscription_activation_code` setting from the secondary `vars.yml` file.

For Cloud Native Hybrid environments some additional variables will need to be added to the primary and secondary sites `vars.yml` files:

- `cloud_native_hybrid_geo` - True/False flag to add addition settings into Charts for Geo.
- `cloud_native_hybrid_geo_role` - The role for the current Geo site. Should be set to either `primary` or `secondary`.
- `geo_primary_site_prefix` - Should match the prefix for each site.
- `geo_primary_site_gcp_project` - **GCP only** The GCP project ID the site is in.
- `geo_primary_site_gcp_zone` - **GCP only** The GCP zone the site is in e.g. `europe-west1-c`.
- `geo_secondary_site_aws_region` - **AWS only** The AWS region the site is in e.g. `us-east-2`.

When adding Geo specific settings into your Ansible configurations, depending on the GitLab installation type it can be important as to when the settings were added. When using the Linux package, the settings need to be added before the `gitlab_geo.yml` playbook is run. It's not important if the settings existed before or after the original `all.yml` playbook was ran, Geo is configured entirely by the Geo playbook. However, when using GitLab charts, some of the Geo configuration is handled before the Geo playbook is run, this means the Geo settings will need to be present when running the `all.yml` playbook. If the environment is already deployed before adding Geo, you can simply add the new Geo settings and rerun the `gitlab_charts.yml` playbook.

For both Linux package and Cloud Native Hybrid environments it's required to add new `keyed_groups` to your Dynamic Inventory config file for your chosen cloud provider:

GCP:

```yaml
- key: labels.gitlab_geo_site
    separator: ''
- key: labels.gitlab_geo_full_role
    separator: ''
```

AWS:

```yaml
- key: tags.gitlab_geo_site
  separator: ''
- key: tags.gitlab_geo_full_role
    separator: ''
```

Once all the settings are added, the steps for [GitLab Environment Toolkit - Configuring the environment with Ansible](../environment_configure.md) should be followed for each site. Once complete you will have multiple independent instances of GitLab.

Once done we can then run the command `ansible-playbook -i environments/my-geo-deployment/<secondary>/inventory -i environments/my-geo-deployment/<primary>/inventory playbooks/gitlab_geo.yml`.

:information_source:&nbsp; It should be noted, when passing in multiple inventories the second inventory's variables will take precedence over the first.

Once complete the two sites will now be part of the same Geo deployment.

:information_source:&nbsp; When setting up multiple Geo secondaries you will need to rerun the above command replacing the secondary path for each secondary inventory. After the first run, the primary will be set up and its tasks can be skipped for each consecutive secondary with the following command `ansible-playbook -i environments/my-geo-deployment/<secondary>/inventory -i environments/my-geo-deployment/<primary>/inventory playbooks/gitlab_geo.yml -t secondary`.
