# Advanced - Component Cloud Services / Custom (Load Balancers, PostgreSQL, Redis)

- [GitLab Environment Toolkit - Quick Start Guide](environment_quick_start_guide.md)
- [GitLab Environment Toolkit - Preparing the environment](environment_prep.md)
- [GitLab Environment Toolkit - Provisioning the environment with Terraform](environment_provision.md)
- [GitLab Environment Toolkit - Configuring the environment with Ansible](environment_configure.md)
- [GitLab Environment Toolkit - Advanced - Custom Config / Tasks / Files, Data Disks, Advanced Search, Container Registry and more](environment_advanced.md)
- [GitLab Environment Toolkit - Advanced - Cloud Native Hybrid](environment_advanced_hybrid.md)
- [**GitLab Environment Toolkit - Advanced - Component Cloud Services / Custom (Load Balancers, PostgreSQL, Redis)**](environment_advanced_services.md)
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

The Toolkit supports using alternative sources for select components, such as cloud services or custom servers, instead of deploying them directly. This is supported for the Load Balancer(s), PostgreSQL and Redis components as follows:

- Cloud Services - The Toolkit supports both _provisioning_ and _configuration_ for environments to use.
- Custom Servers - For servers, provided by users, the Toolkit supports the _configuration_ for environments to use.

On this page we'll detail how to set up the Toolkit to provision and/or configure these alternatives. **It's also worth noting this guide is supplementary to the rest of the docs, and it will assume this throughout.**

[[_TOC_]]

## Overview

It can be more convenient to use an alternative source for select components rather than having to manage them more directly. For example, cloud services have built in HA and don't require instance level maintenance.

Several components of the GitLab setup can be switched to a cloud service or custom server:

- [Load Balancers](https://docs.gitlab.com/ee/administration/load_balancer.html) - [AWS ELB](https://aws.amazon.com/elasticloadbalancing/), _Custom_
- [PostgreSQL](https://docs.gitlab.com/ee/administration/reference_architectures/10k_users.html#provide-your-own-postgresql-instance) - [AWS RDS](https://aws.amazon.com/rds/postgresql/), _Custom_
- [Redis](https://docs.gitlab.com/ee/administration/reference_architectures/10k_users.html#providing-your-own-redis-instance) - [AWS ElastiCache](https://aws.amazon.com/elasticache/redis/), _Custom_
- [Advanced Search](https://docs.gitlab.com/ee/user/search/advanced_search.html) - [AWS OpenSearch](https://aws.amazon.com/opensearch-service/), _Custom_

:information_source:&nbsp; Support for more services is ongoing. Unless specified otherwise the above is the currently supported services by the Toolkit.

## Load Balancers

The Toolkit supports select provisioning and/or configuring Load Balancer(s) that GitLab requires.

:information_source:&nbsp; Load Balancer service support will continue to expand in the future. Custom load balancers are also supported.

When using an alternative Load Balancer the following changes apply when deploying via the Toolkit (depending on the load balancer):

Internal:

- HAProxy Internal node no longer needs to be provisioned via Terraform
- Internal Load Balancer host name in Ansible is set to the Load Balancer host as given by the service

Head to the relevant section(s) below for details on how to provision and/or configure.

### Provisioning with Terraform

Provisioning the alternative Load Balancer(s) via cloud services is handled directly by the relevant Toolkit module. As such, it only requires some different config in your [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`).

Like the main provisioning docs there are sections for each supported provider on how to achieve this. Follow the section for your selected provider and then move onto the next step.

#### AWS ELB

##### Internal (NLB)

The Toolkit supports provisioning an AWS NLB service as the Internal Load Balancer with everything GitLab requires to be set up.

The variable(s) for this service start with the prefix `elb_internal_*` and should replace any previous `haproxy_internal_*` settings. The available variable(s) are as follows:

- `elb_internal_create` - Create the Internal Load Balancer service. Defaults to `false`.

To set up a standard AWS NLB service for the Internal Load Balancer it should look like the following in your [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`):

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  [...]

  elb_internal_create = true
}
```

Once the variables are set in your file you can proceed to provision the service as normal. Note that this can take several minutes on AWS's side.

Once provisioned you'll see a new output at the end of the process - `elb_internal_host`. This contains the hostname for the Load Balancer that then needs to be passed to Ansible to configure. Take a note of this hostname for the next step.

### Configuring with Ansible

To configure GitLab to use alternative Load Balancer(s) with Ansible, point the Toolkit at the Load Balancer(s) in your [Environment config file](environment_configure.md#environment-config-varsyml) (`vars.yml`)

:information_source:&nbsp; This config is the same for custom Load Balancers. In this setup, all required balancing rules must be in place and the URL to connect to the Balancer(s) never change. For the latest balancer rules needed to configure refer to the HAProxy config files provided as part of the Toolkit - [External](../ansible/roles/haproxy/templates/haproxy_external.cfg.j2), [Internal](../ansible/roles/haproxy/templates/haproxy_internal.cfg.j2).

The available variables in Ansible for this are as follows:

- `external_url` - The external load balancer URL. This is expected to be the same as the main URL that the environment is to be accessed on.
- `internal_lb_host` - The hostname of the Internal Load Balancer (not URL). Provided in Terraform outputs if provisioned earlier.
- `gitlab_rails_nginx_real_ip_trusted_cidr_blocks` - The array of Internal and External Load Balancer IPs. This allows GitLab to trust the `X-Forwarded-For` header from these IPs to [log the actual client IP](https://docs.gitlab.com/omnibus/settings/nginx.html#configuring-gitlab-trusted_proxies-and-the-nginx-real_ip-module).

## PostgreSQL

The Toolkit supports provisioning and/or configuring alternative PostgreSQL database(s) that meet the [requirements](https://docs.gitlab.com/ee/install/requirements.html#postgresql-requirements) and then pointing GitLab to use them accordingly, much in the same way as configuring Omnibus Postgres.

When using alternative PostgreSQL database(s) the following changes apply when deploying via the Toolkit:

- Postgres and PgBouncer nodes don't need to be provisioned via Terraform.
- Praefect may use the same database instance unless Geo is being used. In such a case the Praefect Postgres node doesn't need to be provisioned.
- Consul doesn't need to be provisioned via Terraform unless you're deploying Prometheus via the Monitor node (needed for monitoring auto discovery).

### Database Setup Options

There are several databases GitLab can use depending on the setup as follows:

- GitLab - The main database for the application
- Praefect - The database for Praefect to track Gitaly node status
- Geo Tracking - The database for Geo to track sync status on a secondary site

How and where these are configured can be done in several ways depending on if Geo is being used:

- Non Geo
  - GitLab and Praefect can be configured on the same Database instance (recommended) or separated
- Geo
  - GitLab and Praefect should be separated to avoid replication of the latter.
  - Geo Tracking DB can be configured on the same Database instance as Praefect on the secondary site (recommended) or separated

:information_source:&nbsp; In each case the databases given will need to be prepared for GitLab to use, such as the creation of users. The Toolkit will attempt to do this automatically for you by default. However, this may not be compatible with your specific database depending on your setup. Refer to the [Database Preparation](#database-preparation) section below for more info.

This section starts with the non Geo combined databases route with guidance being given on the alternatives where appropriate.

Head to the relevant section(s) below for details on how to provision and/or configure.

### Provisioning with Terraform

Provisioning a PostgreSQL database via a cloud service differs slightly per provider but has been designed in the Toolkit to be as similar as possible to deploying PostgreSQL via Omnibus. As such, it only requires some different config in your [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`).

Like the main provisioning docs there are sections for each supported provider on how to achieve this. Follow the section for your selected provider and then move onto the next step.

#### AWS RDS

The Toolkit supports provisioning an [AWS RDS PostgreSQL service](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html) instance with everything GitLab requires or recommends such as built in HA support over AZs and encryption.

The variables for this service start with the prefix `rds_postgres_*` and should replace any previous `postgres_*`, `pgbouncer_*` and `praefect_postgres_*` settings. The available variables are as follows:

- `rds_postgres_instance_type`- The [AWS Instance Type](https://aws.amazon.com/rds/instance-types/) for the RDS service to use without the `db.` prefix. For example, to use a `db.m5.2xlarge` RDS instance type, the value of this variable should be `m5.2xlarge`. **Required**.
- `rds_postgres_password` - The password for the instance. **Required**.
- `rds_postgres_username` - The username for the instance. Optional, default is `gitlab`.
- `rds_postgres_database_name` - The name of the main database in the instance for use by GitLab. Optional, default is `gitlabhq_production`.
- `rds_postgres_port` - The password for the instance. Should only be changed if desired. Optional, default is `5432`.
- `rds_postgres_allocated_storage` - The initial disk size for the instance. Optional, default is `100`.
- `rds_postgres_max_allocated_storage` - The max disk size for the instance. Optional, default is `1000`.
- `rds_postgres_multi_az` - Specifies if the RDS instance is multi-AZ. Should only be disabled when HA isn't required. Optional, default is `true`.
- `rds_postgres_default_subnet_count` - Specifies the number of default subnets to use when running on the default network. Optional, default is `2`.
- `rds_postgres_iops` - The amount of provisioned IOPS. Setting this requires a storage_type of `io1` (must be `1000` or higher) or `gp3` (only for `gp3` disks 400 GB or larger). Optional, default is `null`.
- `rds_postgres_storage_type` - The type of storage to use. Optional, default is `io1`.
- `rds_postgres_kms_key_arn` - The ARN for an existing [AWS KMS Key](https://aws.amazon.com/kms/) to be used to encrypt the database instance. If not provided `default_kms_key_arm` or the default AWS KMS key will be used in that order. Optional, default is `null`.
  - **Warning** Changing this value after the initial creation will result in the database being recreated and will lead to **data loss**.
- `rds_postgres_allowed_ingress_cidr_blocks` - A list of CIDR blocks that configures the IP ranges that will be able to access RDS over HTTP/HTTPs internally. Note this only applies for access from internal resources, the instance will not be accessible publicly. Optional, defaults to selected VPC internal CIDR block.
- [`rds_postgres_backup_retention_period`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance#backup_retention_period) - The number of days to retain backups for. Must be between 0 and 35. Must be greater than 0 when Read Replicas are to be used (Including Geo primary instances). Optional, default is `null`.
- [`rds_postgres_backup_window`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance#backup_window) - The daily time range where backups will be taken, e.g. `09:46-10:16`. Optional, default is `null`.
- [`rds_postgres_delete_automated_backups`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance#delete_automated_backups) - Whether automated backups (if taken) will be deleted when the RDS instance is deleted. Optional, default is `true`.
- [`rds_postgres_maintenance_window`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance#maintenance_window) - The window to perform maintenance in, e.g. `Mon:00:00-Mon:03:00`. Optional, default is `null`. Must not overlap with `rds_postgres_backup_window`.
- [`rds_postgres_tags`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance#tags) - A map of tags to assign to RDS instance. Optional, default is `{}`.
- `rds_postgres_performance_insights_enabled` - Enables [AWS RDS Performance Insights](https://aws.amazon.com/rds/performance-insights/). Optional, default is `null`.
- `rds_postgres_performance_insights_retention_period` - Sets the retention period for AWS RDS Performance Insights. 7 days are included for free, refer to the [AWS Pricing page](https://aws.amazon.com/rds/performance-insights/pricing/) for costs beyond the included retention period. Optional, default `null`.

To set up a standard AWS RDS PostgreSQL service for a 10k environment with the required variables, it should look like the following in the [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`):

:information_source:&nbsp; If a separate Database Instance for Praefect is desired then this can be done with the same settings above but with the `rds_praefect_postgres_*` prefix instead.

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  [...]

  rds_postgres_instance_type = "m5.2xlarge"
  rds_postgres_password = "<postgres_password>"
}
```

Once the variables are set in your file you can proceed to provision the service as normal. Note that this can take several minutes on AWS's side.

Once provisioned you'll see several new outputs at the end of the process. Key from this is the `rds_host` output, which contains the address for the database instance that then needs to be passed to Ansible to configure. Take a note of this address for the next step.

##### AWS RDS Version

When it comes to the version of PostgreSQL being deployed in AWS RDS, it's first worth noting that [AWS has several rules in place that can impact this on the server side](https://aws.amazon.com/rds/faqs/#Database_Engine_Versions), such as removing minor versions after a year or enabling minor upgrades by default. These rules can in turn can cause issues with Terraform, and its state as they happen automatically.

Due to the above as well as ensuring that major upgrades don't happen unexpectedly, the Toolkit handles RDS version as follows:

- The Toolkit will ask AWS RDS to deploy the current GitLab recommended version of PostgreSQL as chosen by AWS.
  - Conversely, if AWS decide to change the recommended version at a later date, Terraform will instruct AWS to upgrade the database to that version on the next run.
- The Toolkit disables any auto upgrade behaviour (`auto_minor_version_upgrade`) for the RDS instance to avoid any Terraform clashes.

While the above is the default behaviour it's recommended that you manage the version yourself in almost all cases by configuring the [recommended PostgreSQL version specifically for the version of GitLab you are deploying](https://docs.gitlab.com/ee/administration/package_information/postgresql_versions.html) and then changing that as required to do an upgrade.

:information_source:&nbsp; If the specific recommended version for GitLab isn't available on AWS RDS, then the latest minor version is expected to work instead.

Configuring how RDS version is selected in the Toolkit is done via the following variables:

- `rds_postgres_version` - The version of the PostgreSQL instance to set up. This should be set to the [recommended version for the version of GitLab being deployed](https://docs.gitlab.com/ee/administration/package_information/postgresql_versions.html) or latest minor version if not available. Changing this value to a newer version will trigger an upgrade during the next run. Optional, default is `13`.
  - :information_source:&nbsp; If performing a major upgrade, [it's recommended in the AWS documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.PostgreSQL.html#USER_UpgradeDBInstance.PostgreSQL.MajorVersion.Process) to run the `ANALYZE` operation after to avoid performance issues.
- [`rds_postgres_auto_minor_version_upgrade`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance#auto_minor_version_upgrade) - Whether automated upgrades to AWS selected minor versions should occur during the maintenance window. This is disabled by default and is not recommended being enabled as it can lead to clashes with Terraform's state. Optional, default is `false`.

:information_source:&nbsp; If a separate Database Instance for Praefect is desired then this can be done with the same settings above but with the `rds_praefect_postgres_*` prefix instead.

##### AWS RDS Parameters

It's possible to configure [RDS Postgres parameters](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.Parameters.html) via the Toolkit if desired.

By default, the Toolkit sets the [following parameters](https://gitlab.com/gitlab-org/gitlab-environment-toolkit/-/blob/main/terraform/modules/gitlab_ref_arch_aws/rds.tf#L9) to follow [GitLab recommendations](https://docs.gitlab.com/ee/administration/troubleshooting/postgresql.html#database-deadlocks):

```yaml
{
  password_encryption = "scram-sha-256"
  log_min_duration_statement = 1000
  idle_in_transaction_session_timeout = 60000
  statement_timeout = 15000
  deadlock_timeout = 5000
}
```

With the following variable you can configure any [available parameter](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.Parameters.html#Appendix.PostgreSQL.CommonDBATasks.Parameters.parameters-list), including the above in overriding fashion:

- `rds_postgres_params` - A map of [Postgres parameters](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.Parameters.html#Appendix.PostgreSQL.CommonDBATasks.Parameters.parameters-list) to configure in RDS. Any param set here will take precedence. Optional, default is `{}`.

:information_source:&nbsp; Parameters for Praefect or Geo Tracking RDS databases can also be done with the same setting above but with the `rds_praefect_postgres_*` or `rds_geo_tracking_postgres_*` prefixes respectively instead.

##### AWS RDS Read Replicas

The standard setup above will deploy an [RDS instance with a standby replica](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html) in a different Availability Zone to provide HA in case of a failure. This replica is only used for HA though and can't be reached.

As an additional feature RDS also offers the ability to spin up separate [Read Replicas](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html) that can be reached and serve read requests. With GitLab this feature can be used to enable [Database Load Balancing](https://docs.gitlab.com/ee/administration/postgresql/database_load_balancing.html) for additional performance and stability - As such, the Toolkit supports provisioning 1 or more read replicas per database.

Read Replicas, as implied, mimic their main database in most ways, so the number of options here is lower. Configuring Read Replicas is done via the following variables:

- `rds_postgres_read_replica_count` - The number of read replicas to configure for the RDS database of the PostgreSQL instance to set up. Optional, default is `0`.
- `rds_postgres_read_replica_port` - The port read replicas will run on. Optional, default is `5432`.
- `rds_postgres_read_replica_multi_az` - Whether each replica should itself have a standby replica to provide HA. Optional, default is `false`.

:information_source:&nbsp; AWS requires that the main RDS database for which Read Replicas are being configured for must have its Backup Retention Period value (e.g. `rds_postgres_backup_retention_period`) set to 1 or higher.

:information_source:&nbsp; Read replicas for Praefect or Geo Tracking RDS databases can also be done with the same settings above but with the `rds_praefect_postgres_*` or `rds_geo_tracking_postgres_*` prefixes respectively instead.

Once provisioned you'll see a new output added at the end of the Terraform process. Of note is the output from this is the `rds_read_replica_hosts` output (also `rds_praefect_read_replica_hosts` / `rds_geo_read_replica_hosts`), which contains the addresses of the read replicas that in turn can be used for [Database Load Balancing configuration later](#configuring-with-ansible-1).

##### Geo

When setting up Geo with RDS you must specify some extra settings to enable replication from the primary RDS instance to the secondary.

###### Primary Site

`rds_postgres_backup_retention_period` must have a value (in days) greater than 0 to enable it as a replication source.

###### Secondary Site

- `rds_postgres_kms_key_arn` should be set to the same KMS key ARN that was used to encrypt the primary sites RDS instance, the key will be shown in the output of the primary sites Terraform run.
- `rds_postgres_replication_database_arn` must be set to the ARN for the primary sites RDS instance. The ARN will be shown in the output of the primary sites Terraform run.

When using RDS with Geo, the secondary site will require separate RDS instance(s) for Praefect Postgres and the Geo Tracking database. The Tracking database and Praefect database can share a single separate instance or can be separated out into their own instances.

To configure these you can copy all the same variables listed above and replace `rds_postgres_*` with `rds_praefect_postgres_*` or `rds_geo_tracking_postgres_*` respectively with the following considerations:

- If you want the 2 databases to share a single instance then you only need to specify `rds_praefect_postgres_*` settings, which will also be used for the Geo Tracking database.
- If you're not using Gitaly Cluster (and therefore Praefect) then you must provide `rds_geo_tracking_postgres_*` settings.
- Similar to the main Postgres instance the only properties required to create an instance are `*_instance_type` and `*_password`.

The primary site can use a single RDS instance to house both the main GitLab database and the Praefect database. With this configuration you can avoid having 2 RDS instances for the primary site to reduce costs. The Praefect database will be replicated over to the secondary site and ignored.

#### GCP Cloud SQL

The Toolkit supports provisioning a [GCP Cloud SQL PostgreSQL service](https://cloud.google.com/sql/docs/postgres) instance with everything GitLab requires or recommends such as built in HA support over AZs and encryption.

:information_source:&nbsp; Ensure that [Cloud Resource Manager](https://cloud.google.com/resource-manager/reference/rest) and the [Cloud SQL Admin](https://console.cloud.google.com/apis/library/redis.googleapis.com) APIs are enabled on the target GCP project. The account that Terraform is running with also requires the `Cloud SQL Admin` and `Compute Network Admin` IAM roles.

:information_source:&nbsp; Note that Geo setups are not directly supported at this time. While the Toolkit can set up two separate Cloud SQL instances, additional manual setup for [VPC Network Peering](https://cloud.google.com/vpc/docs/vpc-peering) and [Logical Replication](https://cloud.google.com/sql/docs/postgres/replication/configure-logical-replication) will be required.

The variables for this service start with the prefix `cloud_sql_*` and should replace any previous `postgres_*`, `pgbouncer_*` and `praefect_postgres_*` settings. The available variables are as follows:

- `cloud_sql_postgres_machine_tier`- The [GCP Cloud SQL Machine Tier](https://cloud.google.com/sql/docs/postgres/create-instance#machine-types) for the service to use without the `db-` prefix. Note that for this service the standard GCP machine sizes don't apply, instead utilizing custom sizes in most cases. For example, to deploy an instance that matches a `n1-standard-4` machine type this can be configured as `custom-4-15360`. **Required**.
- `cloud_sql_postgres_edition` - The [Cloud SQL edition](https://cloud.google.com/sql/docs/postgres/editions-intro) to be used. Optional, defaults to `ENTERPRISE`.
- `cloud_sql_postgres_version` - The [Postgres version](https://cloud.google.com/sql/docs/postgres/db-versions) to be used. Changing this value will trigger an upgrade and may lead to some downtime. Optional, defaults to `POSTGRES_13`.
  - :information_source:&nbsp; If performing a major upgrade, [it's recommended in the GCP documentation](https://cloud.google.com/sql/docs/postgres/upgrade-major-db-version-inplace#complete_the_major_version_upgrade) to run the `ANALYZE` operation after to avoid performance issues.
- `cloud_sql_postgres_root_password` - The root password for the instance to be used for the default `postgres` user. If not set the user will not be given a password and access won't be available until a password is given manually. Optional, default is `null`.
- `cloud_sql_postgres_disk_type` - The initial disk type for the instance. Options are `PD-SSD` or `PD-HDD`. Optional, default is `PD-HDD`.
- `cloud_sql_postgres_disk_size` - The disk size for the instance. Note that the disk will autoresize as required. Optional, default is `100`.
- `cloud_sql_postgres_availability_type` - Specifies the [availability type](https://cloud.google.com/sql/docs/postgres/high-availability) for Cloud SQL instance (HA). Options are `ZONAL` (non-HA) or `REGIONAL` (HA) - GCP will default to `ZONAL` if not configured. Optional, default is `ZONAL`.
- `cloud_sql_postgres_deletion_protection` - If deletion protection should be enabled for the instance. Optional, default is `false`.
- `cloud_sql_postgres_encryption_key_name` - The GCP Key resource name for [CMEK disk encryption](environment_provision.md#customer-managed-encryption-keys-cmek-gcp). If not set Google provided keys will be used instead. Optional, default is `null`.

:information_source:&nbsp; If a separate Database Instance for Praefect is desired then this can be done with the same settings above but with the `cloud_sql_praefect_postgres_*` prefix instead.

To set up a standard GCP Cloud SQL PostgreSQL service for a 10k environment with the required variables, it should look like the following in the [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`):

```tf
module "gitlab_ref_arch_gcp" {
  source = "../../modules/gitlab_ref_arch_gcp"

  [...]

  cloud_sql_postgres_machine_tier = "custom-8-30720"
  cloud_sql_postgres_root_password = "<postgres_password>"
}
```

Once the variables are set in your file you can proceed to provision the service as normal. Note that this can take several minutes on GCP's side.

Once provisioned the database will be configured, and you'll see several new outputs at the end of the process. Key from this is the `cloud_sql_host` output, which contains the [Private IP](https://cloud.google.com/sql/docs/postgres/configure-private-ip#connect_to_an_instance_using_its_private_ip) address for the database instance that then needs to be passed to Ansible to configure. Take a note of this address for the next step.

##### GCP Cloud SQL Parameters

It's possible to configure [Cloud SQL Postgres parameters](https://cloud.google.com/sql/docs/postgres/flags) via the Toolkit if desired.

By default, the Toolkit sets the [following parameters](https://gitlab.com/gitlab-org/gitlab-environment-toolkit/-/blob/main/terraform/modules/gitlab_ref_arch_aws/rds.tf#L9) to follow [GitLab recommendations](https://docs.gitlab.com/ee/administration/troubleshooting/postgresql.html#database-deadlocks) as applicable:

```yaml
{
  password_encryption = "scram-sha-256"
  log_min_duration_statement = 1000
  idle_in_transaction_session_timeout = 60000
  deadlock_timeout = 5000
}
```

With the following variable you can configure any [available parameter](https://cloud.google.com/sql/docs/postgres/flags#list-flags-postgres), including the above in overriding fashion:

- `cloud_sql_postgres_params` - A map of [Postgres parameters](https://cloud.google.com/sql/docs/postgres/flags#list-flags-postgres) to configure in Cloud SQL. Any param set here will take precedence. Optional, default is `{}`.

:information_source:&nbsp; Parameters for the Praefect database can also be done if provisioned via the `cloud_sql_praefect_postgres_params` variable.

##### GCP Cloud SQL SSL config

GCP Cloud SQL does offer the ability to connect to Postgres over SSL. However, it should be noted this has some considerations:

- Certificates are self-signed and managed by Cloud SQL. [These will need to be downloaded](https://cloud.google.com/sql/docs/postgres/manage-ssl-instance) and propagated to the relevant GitLab components separately. This includes client certificates if the `require_ssl` option is enabled (see below).
- Setting the `require_ssl` option on Cloud SQL will enable mutual 2-way SSL. This will impact Ansible from performing the required [Database Preparation](#database-preparation) steps and as a result users and databases may need to be created separately.

If the above is desirable then the `require_ssl` option can be enabled via the following variable:

- `cloud_sql_postgres_require_ssl` - Sets if connections to the database require SSL (Mutual 2-way). Optional, default is `false`

For more information about GCP Cloud SQL SSL [refer to the provider's documentation](https://cloud.google.com/sql/docs/postgres/configure-ssl-instance).

##### GCP Cloud SQL Maintenance config

The Toolkit allows for configuring various Maintenance settings for a GCP Cloud SQL instance.

Maintenance settings are configured via the `cloud_sql_postgres_maintenance_window` object variable that has the following variables:

- `cloud_sql_postgres_maintenance_window`
  - [`day`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#day) - The day of the week when maintenance should occur. Options are `1` through `7`, where `1` is Monday. Optional, default is `null`.
  - [`hour`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#hour) - The hour of the day when maintenance should occur. Options are `0` through `23`, following 24 hour time notation. Optional, default is `null`.
  - [`update_track`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance##update_track) - The update track that maintenance should follow. Options are `stable` or `canary`. GCP will follow `stable` unless set otherwise as recommended. Optional, default is `null`.

An example of the above in Terraform would be as follows:

```tf
module "gitlab_ref_arch_gcp" {
  source = "../../modules/gitlab_ref_arch_gcp"

  [...]

  cloud_sql_postgres_maintenance_window = {
    day = 2
    hour = 11
  }
}
```

##### GCP Cloud SQL Backup config

The Toolkit allows for configuring various Backup settings for a GCP Cloud SQL instance.

Maintenance settings are configured via the `cloud_sql_postgres_maintenance_window` object variable that has the following variables:

- `cloud_sql_postgres_backup_configuration`
  - [`enabled`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#enabled) - If backups are enabled. Optional, default is `null`.
  - [`start_time`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#start_time) - The time when backups should be taken in `HH:MM` format. Optional, default is `null`.
  - [`location`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#location) - The region where backups will be stored. By default, to the same region as configured by the provider. Optional, default is `null`.
  - [`point_in_time_recovery_enabled`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#point_in_time_recovery_enabled) - If Point-in-time recovery is enabled. Optional, default is `null`.
  - [`transaction_log_retention_days`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#transaction_log_retention_days) - The number of days Point-in-time transaction logs should be retained. Options are `1` through `7`. Optional, default is `null`,
  - [`retained_backups`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#retained_backups) - The number of backups to retain. If not specified the Google default of `7` is used. Optional, default is `null`.

An example of the above in Terraform would be as follows:

```tf
module "gitlab_ref_arch_gcp" {
  source = "../../modules/gitlab_ref_arch_gcp"

  [...]

  cloud_sql_postgres_backup_configuration = {
    enabled = true

    retained_backups = 2
    point_in_time_recovery_enabled = true
    transaction_log_retention_days = 2
  }
}
```

##### GCP Cloud SQL Read Replicas

The standard setup above will deploy a standalone GCP Cloud SQL instance that optionally can also be configured to have an availability replica for HA purposes. This replica is only used for HA though and can't be reached or read from.

As an additional feature Cloud SQL also offers the ability to spin up separate [Read Replicas](https://cloud.google.com/sql/docs/postgres/replication/create-replica) that can be reached and serve read requests. With GitLab this feature can be used to enable [Database Load Balancing](https://docs.gitlab.com/ee/administration/postgresql/database_load_balancing.html) for additional performance and stability - As such, the Toolkit supports provisioning 1 or more read replicas per database.

:information_source:&nbsp; Note this Read Replicas are only available for the main GitLab instance and not others like Praefect as only the main database can utilize Database Load Balancing.

Read Replicas, as implied, mimic their main database in most ways, so the number of options here is lower. Configuring Read Replicas is done via the following variables:

- `cloud_sql_postgres_read_replica_count` - The number of read replicas to configure for the Cloud SQL database of the PostgreSQL instance to set up. Optional, default is `0`.
- `cloud_sql_postgres_read_replica_deletion_protection` - If deletion protection should be enabled for the read replica instance. Optional, default is `false`.
- `cloud_sql_postgres_read_replica_availability_type` - Specifies the [availability type](https://cloud.google.com/sql/docs/postgres/high-availability) for read replica instance (HA). Options are `ZONAL` (non-HA) or `REGIONAL` (HA) - GCP will default to `ZONAL` if not configured. Optional, default is `null`.

Once provisioned you'll see a new output added at the end of the Terraform process. Of note is the output from this is the `cloud_sql_read_replica_hosts` output, which contains the addresses of the read replicas that in turn can be used for [Database Load Balancing configuration later](#configuring-with-ansible-1).

### Configuring with Ansible

To configure GitLab to use an alternative PostgreSQL database with Ansible, point the Toolkit at the PostgreSQL instance(s) in your [Environment config file](environment_configure.md#environment-config-varsyml) (`vars.yml`)

:information_source:&nbsp; This config is the same for custom PostgreSQL databases that have been provisioned outside of Omnibus or Cloud Services. For this setup, it is required that HA is in place and the URL to connect to the PostgreSQL instance never changes.

:information_source:&nbsp; The Toolkit will attempt to do some database preparation by default when it's given external databases, such as creating users. However, this may not be compatible with your specific database depending on your setup. Refer to the [Database Preparation](#database-preparation) section below for more info.

As detailed in [Database Setup Options](#database-setup-options) GitLab has several potential databases to configure. This section will start with the combined non Geo route with additional guidance given for the alternatives.

The required variables in Ansible for this are as follows:

- `postgres_host` - The hostname of the PostgreSQL instance. Provided in Terraform outputs if provisioned earlier. **Required**.
- `postgres_username` - The username of the PostgreSQL instance. Optional, default is `gitlab`.
- `postgres_password` - The password for the user defined by `postgres_username`. **Required**.
- `postgres_database_name` - The name of the main database in the instance for use by GitLab. Optional, default is `gitlabhq_production`.
- `postgres_port` - The port of the PostgreSQL instance. Should only be changed if the instance isn't running with the default port. Optional, default is `5432`.
- `postgres_load_balancing_hosts` - A list of all PostgreSQL hostnames to use in [Database Load Balancing](https://docs.gitlab.com/ee/administration/postgresql/database_load_balancing.html). This is only applicable when running with an alternative Postgres setup (non-Omnibus) where you have multiple read replicas. The main host should also be included in this list to be used in load balancing. Optional, default is `[]`.
- `praefect_postgres_username` - The username to create for Praefect on the PostgreSQL instance. Optional, default is `praefect`.
- `praefect_postgres_password` - The password for the Praefect user on the PostgreSQL instance. **Required**.
- `praefect_postgres_database_name` - The name of the database to create for Praefect on the PostgreSQL instance. Optional, default is `praefect_production`.

Depending on your Database instance setup some additional config may be required:

- `postgres_migrations_host` / `postgres_migrations_port` - Required for running GitLab Migrations if the main connection is not direct (e.g. via a connection pooler like PgBouncer). This should be set to the direct connection details of your database.
- `postgres_admin_username` / `postgres_admin_password` - Required if the admin username for the Database instance differs from the main one.
  - **GCP only** - This must be set to `postgres` and the password set via Terraform when using a Toolkit provisioned GCP Cloud SQL instance (`cloud_sql_postgres_root_password`).
- `postgres_external_prep` - Sets up data on external main database as required by GitLab. Disable this if Ansible is unable to connect to the database directly. Refer to the [Database Preparation](#database-preparation) section below for more info. Optional, default is `true`.

If a separate Database instance is to be used for Praefect then the additional following config may be required:

- `praefect_postgres_host` / `praefect_postgres_port` - Host and port for the Praefect database.
- `praefect_postgres_cache_host` / `praefect_postgres_cache_port` - Host and port for the [Praefect cache connection](https://docs.gitlab.com/ee/administration/gitaly/praefect.html#reads-distribution-caching). This should be either set to the direct connection or through a PgBouncer connection that has session pooling enabled.
- `praefect_postgres_migrations_host` / `praefect_postgres_migrations_port` - Required for running Praefect Migrations if the main connection is not direct (e.g. via a connection pooler like PgBouncer). This should be set to the direct connection details of your database.
- `praefect_postgres_admin_username` / `praefect_postgres_admin_password` - Required if the admin username for the Database instance differs from the main one.
  - **GCP only** - This must be set to `postgres` and the password set via Terraform when using a Toolkit provisioned GCP Cloud SQL instance (`cloud_sql_postgres_root_password`).
- `praefect_postgres_external_prep` - Sets up data on the external Praefect database(s) as required by GitLab. Disable this if Ansible is unable to connect to the database directly. Refer to the [Database Preparation](#database-preparation) section below for more info. Optional, default is `true`.

Once set, Ansible can then be run as normal. During the run it will configure the various GitLab components to use the database as well as any additional tasks such as setting up a separate database in the same instance for Praefect.

After Ansible is finished running your environment will now be ready.

#### Database Preparation

When using an external database several preparation steps are required for GitLab to use them, including the setup of users, databases and extensions.

As a convenience, the Toolkit will attempt to do this for you automatically via Ansible's [`community.postgres`](https://docs.ansible.com/ansible/latest/collections/community/postgresql/) collection on one of the machines in the environment (as databases typically will only be available internally).

In some cases this may not be compatible however with your selected database setup in relation to access. If you have options such as Mutual 2-way SSL authentication or any other restrictions on database access these convenience actions may fail with an error such as `unable to connect to database: FATAL: <reason>`.

Due to the complexity of this area and restrictions in Ansible it's not possible to cover every potential permutation. In these cases you need to disable Ansible from attempting this behaviour by setting the `postgres_external_prep` / `praefect_postgres_external_prep` variables to `false` and doing the preparation steps manually as detailed in the main documentation as follows:

- [GitLab Database](https://docs.gitlab.com/ee/administration/postgresql/external.html)
- [Praefect Database](https://docs.gitlab.com/ee/administration/gitaly/praefect.html#manual-database-setup)
- [Geo Tracking Database](https://docs.gitlab.com/ee/administration/geo/setup/external_database.html#configure-the-tracking-database)
- [Required database extensions](https://docs.gitlab.com/ee/install/postgresql_extensions.html)

:information_source:&nbsp; In each of the guides above only the steps that are required to be done on the actual database servers need to be followed. Steps on the GitLab side, such as adding config in `/etc/gitlab/gitlab.rb`, can be ignored as the Toolkit will still manage this for you.

#### Geo

When setting up Geo with RDS you must specify some extra settings to configure the RDS instances being used. To configure these you can copy all the same variables listed above and replace `postgres_*` with `praefect_postgres_*` or `geo_tracking_postgres_*` respectively with the below considerations.

- `geo_secondary_postgres_host` - Should always be specified and needs to point to the secondary sites GitLab RDS instance.
- `geo_tracking_postgres_host` - By default this will use the same database used for Praefect. If Gitaly cluster is not being used then this must be set to a separate RDS instance than the main GitLab instance.
- `geo_tracking_postgres_port` - By default the Geo tracking database uses port `5431`, if the Geo tracking database is sharing an RDS instance with Praefect this needs to be set to the same value as `praefect_postgres_port` (`5432` by default).
- `geo_secondary_praefect_postgres_host` - If using Gitaly cluster this should point to the separate RDS instance being used for Praefect.

## Redis

The Toolkit supports provisioning and/or configuring an alternative Redis store and then pointing GitLab to use it accordingly, much in the same way as configuring Omnibus Redis.

When using an alternative Redis store the following changes apply when deploying via the Toolkit:

- The Toolkit can provision either a combined Redis store or separated ones for Cache and Persistent queues respectively, much like Omnibus Redis, depending on the size of Reference Architecture being followed.
- Redis, Redis Cache or Redis Persistent nodes don't need to be provisioned via Terraform.
- [GitLab specifically doesn't support Redis Cluster](https://docs.gitlab.com/ee/administration/redis/replication_and_failover_external.html#requirements). As such the Toolkit is always setting up Redis in a replica setup.

Head to the relevant section(s) below for details on how to provision and/or configure.

### Provisioning with Terraform

Provisioning an alternative Redis store via a cloud service differs slightly per provider but has been designed in the Toolkit to be as similar as possible to deploying Redis via Omnibus. As such, it only requires some different config in your [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`).

Like the main provisioning docs there are sections for each supported provider on how to achieve this. Follow the section for your selected provider and then move onto the next step.

#### AWS ElastiCache

The Toolkit supports provisioning an AWS ElastiCache Redis service instance with everything GitLab requires or recommends such as built in HA support over AZs and encryption.

There are different variables to be set depending on the target architecture size and if it requires separate Redis instances (10k and up). First we'll detail the general settings that apply to all Redis setups:

The variables to set are dependent on if the setup is to have combined or separated Redis queues depending on the target Reference Architecture. For the latter, some variables will have a different prefix depending on what Redis instances you're provisioning - `elasticache_redis_*`, `elasticache_redis_cache_*` and `elasticache_redis_persistent_*`, each replacing any applicable existing `redis_*`, `redis_cache_*` or `redis_persistent_*` variables respectively. These will be called out below.

For required variables they need to be set for each Redis service you are provisioning:

- `elasticache_redis_instance_type` - The [AWS Instance Type](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/CacheNodes.SupportedTypes.html) of the Redis instance to use without the `cache.` prefix. For example, to use a `cache.m5.2xlarge` ElastiCache instance type, the value of this variable should be `m5.2xlarge`. **Required**.
  - `elasticache_redis_cache_instance_type` or `elasticache_redis_persistent_instance_type` when setting up separate services.
- `elasticache_redis_node_count` - The number of replicas of the Redis instance to have for failover purposes. This should be set to at least `2` or higher for HA and `1` if this isn't a requirement. **Required**.
  - `elasticache_redis_cache_node_count` or `elasticache_redis_persistent_node_count` when setting up separate services.
- `elasticache_redis_kms_key_arn` - The ARN for an existing [AWS KMS Key](https://aws.amazon.com/kms/) to be used to encrypt the Redis instance. If not provided `default_kms_key_arm` or the default AWS KMS key will be used in that order. Optional, default is `null`.
  - `elasticache_redis_cache_kms_key_arn` or `elasticache_redis_persistent_kms_key_arn` when setting up separate services.
  - **Warning** Changing this value after the initial creation will result in the Redis instance being recreated and may lead to **data loss**.

Next are optional variables. The following variables can be set once with the `elasticache_redis_*` prefix, which will apply to every provisioned service, but you can also additionally override this behaviour with specific variables as follows:

- `elasticache_redis_password` - The password of the Redis instance. Must follow the [requirements as mandated by AWS](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/auth.html#auth-overview). **Required**.
  - Optionally `elasticache_redis_cache_password` or `elasticache_redis_persistent_password` can be used to override for separate services.
- `elasticache_redis_engine_version` - The version of the Redis instance. Should only be changed to versions that are supported by GitLab. Optional, default is `6.x`.
  - Optionally `elasticache_redis_cache_engine_version` or `elasticache_redis_persistent_engine_version` can be used to override for separate services.
- `elasticache_redis_port` - The port of the Redis instance. Should only be changed if required. Optional, default is `6379`.
  - Optionally `elasticache_redis_cache_port` or `elasticache_redis_persistent_port` can be used to override for separate services.
- `elasticache_redis_multi_az` - Specifies if the Redis instance is multi-AZ. Should only be disabled when HA isn't required. Optional, default is `true`.
  - Optionally `elasticache_redis_cache_multi_az` or `elasticache_redis_persistent_multi_az` can be used to override for separate services.
- `elasticache_redis_allowed_ingress_cidr_blocks` - A list of CIDR blocks that configures the IP ranges that will be able to access ElastiCache over HTTP/HTTPs internally. Note this only applies for access from internal resources, the instance will not be accessible publicly. Optional, defaults to selected VPC internal CIDR block.
  - Optionally `elasticache_redis_cache_allowed_ingress_cidr_blocks` or `elasticache_redis_persistent_allowed_ingress_cidr_blocks` can be used to override for separate services.
- [`elasticache_redis_maintenance_window`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group#maintenance_window) - The weekly time range for when maintenance on the instance is performed, e.g. `sun:05:00-sun:09:00`. Optional, default is `null`. Must not overlap with `elasticache_redis_snapshot_window`.
  - Optionally `elasticache_redis_cache_maintenance_window` or `elasticache_redis_persistent_maintenance_window` can be used to override for separate services.
- [`elasticache_redis_snapshot_retention_limit`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group#snapshot_retention_limit) - The number of days to retain backups for. Optional, default is `null`.
  - Optionally `elasticache_redis_cache_snapshot_retention_limit` or `elasticache_redis_persistent_snapshot_retention_limit` can be used to override for separate services.
- [`elasticache_redis_snapshot_window`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group#snapshot_window) - The daily time range where backups will be taken, e.g. `09:46-10:16`. Optional, default is `null`.
  - Optionally `elasticache_redis_cache_snapshot_window` or `elasticache_redis_persistent_snapshot_window` can be used to override for separate services.
- `elasticache_redis_default_subnet_count` - Specifies the number of default subnets to use when running on the default network. Optional, default is `2`.

The following optional variables do not default to the `elasticache_redis_*` prefix if set and must be set for each specific service if desired:

- [`elasticache_redis_final_snapshot_identifier`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group#final_snapshot_identifier) - Name of final snapshot to create if cluster is destroyed. If `null` no snapshot is created. Note that this can cause name clashes if a cluster has been destroyed multiple times and the snapshot persists. Optional, default is `null`.
  - `elasticache_redis_cache_snapshot_name` or `elasticache_redis_persistent_final_snapshot_identifier` when setting up separate services.
- [`elasticache_redis_snapshot_name`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group#snapshot_name) - Name of a snapshot from which to restore data into the new node group. Changing this setting forces a new resource. Optional, default is `null`.
  - `elasticache_redis_cache_snapshot_name` or `elasticache_redis_persistent_snapshot_name` when setting up separate services.
- [`elasticache_redis_tags` / `elasticache_redis_cache_tags` / `elasticache_redis_persistent_tags`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group#tags) - A map of [tags](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html) to assign to ElastiCache instance. Optional, default is `{}`.
  - `elasticache_redis_cache_tags` or `elasticache_redis_persistent_tags` when setting up separate services.

If deploying a combined Redis setup that contains all queues (5k and lower) the following settings should be set (replacing any previous `redis_*` settings):

As an example, to set up a standard AWS ElastiCache Redis service for a [5k](https://docs.gitlab.com/ee/administration/reference_architectures/5k_users.html) environment with the required variables should look like the following in your [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`):

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  [...]

  elasticache_redis_node_count = 2
  elasticache_redis_instance_type = "m5.large"
}
```

And for a larger environment, such as a [10k](https://docs.gitlab.com/ee/administration/reference_architectures/10k_users.html), where Redis is separated:

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  [...]

  elasticache_redis_cache_node_count = 2
  elasticache_redis_cache_instance_type = "m5.xlarge"

  elasticache_redis_persistent_node_count = 2
  elasticache_redis_persistent_instance_type = "m5.xlarge"
}
```

Once the variables are set in your file you can proceed to provision the service as normal. Note that this can take several minutes on AWS's side.

Once provisioned you'll see several new outputs at the end of the process. Key from this is the `elasticache_redis*_host` output, which contains the address for the Redis instance that then needs to be passed to Ansible to configure. Take a note of this address for the next step.

#### GCP Memorystore

The Toolkit supports provisioning a GCP Memorystore Redis service instance with everything GitLab requires or recommends such as built in HA support and encryption.

:information_source:&nbsp; Ensure that [Memorystore for Redis API](https://console.cloud.google.com/apis/library/redis.googleapis.com) is enabled on your target GCP project. Refer to the [GCP instructions](https://cloud.google.com/memorystore/docs/redis/create-instance-terraform) for more information.

There are different variables to be set depending on the target architecture size and if it requires separate Redis instances (10k and up). First we'll detail the general settings that apply to all Redis setups:

The variables to set are dependent on if the setup is to have combined or separated Redis queues depending on the target Reference Architecture. For the latter, some variables will have a different prefix depending on what Redis instances you're provisioning - `memorystore_redis_*`, `memorystore_redis_cache_*` and `memorystore_redis_persistent_*`, each replacing any applicable existing `redis_*`, `redis_cache_*` or `redis_persistent_*` variables respectively. These will be called out below.

For required variables they need to be set for each Redis service you are provisioning:

- `memorystore_redis_memory_size_gb` - The memory size in GiB of the Redis instance to use. Note that this is [how the service's machine specs are decided](https://cloud.google.com/memorystore/docs/redis/scaling-instances). Should be an integer. **Required**.
  - `memorystore_redis_cache_memory_size_gb` or `memorystore_redis_persistent_memory_size_gb` when setting up separate services.
- `memorystore_redis_node_count` - The number of replicas of the Redis instance to have for failover purposes. This should be set to at least `2` or higher for HA and `1` if this isn't a requirement. **Required**.
  - `memorystore_redis_cache_node_count` or `memorystore_redis_persistent_node_count` when setting up separate services.

For optional variables they work in a default like manner. When configuring for any Redis types the main `memorystore_redis_*` variable can be set once and this will apply to all but you can also additionally override this behaviour with specific variables as follows:

- `memorystore_redis_version` - The version of the Redis instance. Should only be changed to versions [that are supported by GitLab](https://docs.gitlab.com/ee/install/requirements.html#redis-versions). Optional, default is `6.x`.
  - Optionally `memorystore_redis_cache_version` or `memorystore_redis_persistent_version` can be used to override for separate services.
- `memorystore_redis_transit_encryption_mode` - The [TLS mode of the Redis](https://cloud.google.com/memorystore/docs/redis/reference/rest/v1/projects.locations.instances#tlscertificate) instance for the [In-transit encryption](https://cloud.google.com/memorystore/docs/redis/in-transit-encryption). Optional, default is `DISABLED`. To enable set to `SERVER_AUTHENTICATION`.
  - Optionally `memorystore_redis_cache_transit_encryption_mode` or `memorystore_redis_persistent_transit_encryption_mode` can be used to override for separate services.
  - If you would like to enable TLS, you need to follow guidance on [how to configure internal SSL](environment_advanced_ssl.md#configuring-internal-ssl-via-custom-files-and-custom-config) after environment is provisioned.
  - :information_source:&nbsp; Note that the service will generate its own CA certificate, and [you will need to download it from GCP directly](https://cloud.google.com/memorystore/docs/redis/enabling-in-transit-encryption#downloading_the_certificate_authority).
- `memorystore_redis_customer_managed_key` - The GCP Key resource name for [CMEK disk encryption](environment_provision.md#customer-managed-encryption-keys-cmek-gcp). If not set Google provided keys will be used instead. Optional, default is `null`.
  - Optionally `memorystore_redis_cache_customer_managed_key` or `memorystore_redis_persistent_customer_managed_key` can be used to override for separate services.
- [`memorystore_redis_weekly_maintenance_window_day`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance#day) - The day of week that maintenance updates occur, e.g. `MONDAY`. Optional, default is `null`.
  - Optionally `memorystore_redis_cache_weekly_maintenance_window_day` or `memorystore_redis_persistent_weekly_maintenance_window_day` can be used to override for separate services.
- [`memorystore_redis_weekly_maintenance_window_start_time`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance#start_time) - Start time when maintenance updates occur. Optional, default is `null`.
  - Optionally `memorystore_redis_cache_weekly_maintenance_window_start_time` or `memorystore_redis_persistent_weekly_maintenance_window_start_time` can be used to override for separate services.
  - <details><summary>Example value</summary>

      ```tf
      memorystore_redis_cache_weekly_maintenance_window_start_time = [ {
          hours = 0
          minutes = 30
          seconds = 0
          nanos = 0
        }
      ]
     ```

    </details>

:information_source:&nbsp; Note that due to the service's design, you can't set the AUTH string (or password) directly. It's set on GCP's side during creation, and you have to then [retrieve it accordingly](https://cloud.google.com/memorystore/docs/redis/managing-auth#getting_the_auth_string).

If deploying a combined Redis setup that contains all queues (5k and lower) the following settings should be set (replacing any previous `redis_*` settings):

As an example, to set up a standard GCP Memorystore Redis service for a [5k](https://docs.gitlab.com/ee/administration/reference_architectures/5k_users.html) environment with the required variables should look like the following in your [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`):

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  [...]

  memorystore_redis_node_count     = 3
  memorystore_redis_memory_size_gb = 7
}
```

And for a larger environment, such as a [10k](https://docs.gitlab.com/ee/administration/reference_architectures/10k_users.html), where Redis is separated:

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  [...]

  memorystore_redis_cache_node_count     = 3
  memorystore_redis_cache_memory_size_gb = 15

  memorystore_redis_persistent_node_count     = 3
  memorystore_redis_persistent_memory_size_gb = 15
}
```

Once all the above is done, you can proceed to provision the service as normal. Note that this can take several minutes on GCP's side.

Once provisioned you'll see several new outputs at the end of the process. Keys from this are the `memorystore_redis*_host` and `memorystore_redis*_port` outputs, which contains the address and port for the Redis instance that then needs to be passed to Ansible to configure. Take a note of these values for the next step.

### Configuring with Ansible

To configure GitLab to use alternative Redis store(s) with Ansible, point the Toolkit at the Redis instance(s) in your [Environment config file](environment_configure.md#environment-config-varsyml) (`vars.yml`)

:information_source:&nbsp; This config is the same for custom Redis instance(s) that have been provisioned outside of Omnibus or Cloud Services. For this setup, it is required that HA is in place and the URL to connect to the Redis instance(s) never changes.

The variables to set are dependent on if the setup is to have combined or separated Redis queues depending on the target Reference Architecture. The only difference is that the prefix of the variables change depending on what Redis instances you're provisioning - `redis_*`, `redis_cache_*` and `redis_persistent_*` respectively. All the variables are the same for each instance type and are described once below:

- `redis_password` - The password for the instance. **Required**.
  - Becomes `redis_cache_password` and `redis_persistent_password` when setting up separate stores.
  - **GCP only** - Password for the Redis instances should be copied from the Google Cloud console following [Getting the AUTH string](https://cloud.google.com/memorystore/docs/redis/managing-auth#getting_the_auth_string) guidance.
- `redis_host` - The hostname of the Redis instance. Provided in Terraform outputs if provisioned earlier. **Required**.
  - Becomes `redis_cache_host` or `redis_persistent_host` when setting up separate stores.
  - **GCP only** - With this service this will typically be an internal IP. This can be retrieved directly via the GCP console.
- `redis_port` - The port of the Redis instance. Default is `6379`
  - Becomes `redis_cache_port` or `redis_persistent_port` when setting up separate stores. Will default to `redis_port` if not specified.
  - **GCP only** - Note that while typically the port on this service is `6379`, it may differ at times. This can be checked directly via the GCP console.
  - **AWS only** - No changes are needed. Optional parameter. Should only be changed when custom port was specified during provisioning.
  - **GCP only** - Provided in Terraform outputs if provisioned earlier.
- `redis_external_ssl` - Sets GitLab to use SSL connections to the Redis store.
  - **AWS only** - Default is `true`. Should only be changed when Redis store doesn't have SSL configured. ElastiCache stores provisioned by the Toolkit will always use SSL.
  - **GCP only** - Default is `false`. Should only be changed when Memorystore have SSL configured.
    - If TLS encryption was enabled via `memorystore_redis*_transit_encryption_mode`, follow guidance on [how to configure internal SSL](environment_advanced_ssl.md#configuring-internal-ssl-via-custom-files-and-custom-config) for Redis.
      - :information_source:&nbsp; Note that the service will generate its own CA certificate, and [you will need to download it from GCP directly](https://cloud.google.com/memorystore/docs/redis/enabling-in-transit-encryption#downloading_the_certificate_authority).
- `redis_external_enable_client` - Configures the use of the Redis `client` command, as this is restricted on certain Cloud Providers such as [GCP](https://docs.gitlab.com/omnibus/settings/redis.html#using-google-cloud-memorystore). This command is only used for debugging purposes in Omnibus.
  - **AWS only** - Default is `true`.
  - **GCP only** - Default is `false`.

Once set, Ansible can then be run as normal. During the run it will configure the various GitLab components to use the database as well as any additional tasks such as setting up a separate database in the same instance for Praefect.

After Ansible is finished running your environment will now be ready.

## Advanced Search

The Toolkit supports provisioning and / or configuring an alternative search backend for [GitLab Advanced Search](https://docs.gitlab.com/ee/user/search/advanced_search.html).

:information_source:&nbsp; The Reference Architectures [don't proffer guidance on sizing Search backends at this time](https://docs.gitlab.com/ee/administration/reference_architectures/10k_users.html#configure-advanced-search). This is due to search backend requirements varying notably depending on data shape and search index design. However, as a general guidance in testing we've found that sizing the Search backends similarly to the Gitaly nodes looks to be a good starting point that you can then adjust accordingly.

When using an alternative search backend the following changes apply when deploying via the Toolkit:

- OpenSearch doesn't need to be provisioned in Terraform.

Head to the relevant section(s) below for details on how to provision and/or configure.

### Provisioning with Terraform

Provisioning an alternative search backend via a cloud service differs slightly but has been designed in the Toolkit to be as similar as possible to deploying OpenSearch directly via the Toolkit. As such, it only requires some different config in your [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`).

Like the main provisioning docs there are sections for each supported provider on how to achieve this. Follow the section for your selected provider and then move onto the next step.

#### AWS OpenSearch

The Toolkit supports provisioning an [AWS OpenSearch](https://aws.amazon.com/opensearch-service/) service domain (instance) with everything GitLab requires or recommends such as built in HA support over AZs and encryption.

:information_source:&nbsp; [AWS OpenSearch requires a service-linked role to be present](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/slr.html) in the AWS account before setup. [Refer to the specific section below for more info](#aws-opensearch-service-linked-iam-role).

:information_source:&nbsp; [AWS OpenSearch](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/what-is.html) specifically only supports 1, 2 or 3 Availability Zones.

The variables for this service start with the prefix `opensearch_service_*` and should replace any previous `opensearch_vm_*` variables in your [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`). The available variables are as follows:

- `opensearch_service_node_count` - The number of data nodes for the OpenSearch domain that serve search requests. This should be set to at least `2` or higher and should match the number of intended subnets. **Required**.
- `opensearch_service_instance_type`- The [AWS Instance Type](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/supported-instance-types.html) for the OpenSearch domain to use without the `.search` suffix. For example, to use a `c5.4xlarge` OpenSearch instance type, the value of this variable should be `c5.4xlarge`. **Required**.
- `opensearch_service_engine_version` - The [engine and version](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/what-is.html#choosing-version) of the OpenSearch domain. Should only be changed to versions that are supported by GitLab. The setting should be given in the format `<ENGINE_VERSION>`, e.g. `OpenSearch_1.1`. If not set will use the AWS default. Optional.
  - :information_source:&nbsp; Opensearch engine is only supported by GitLab versions 15 and higher.
- `opensearch_service_volume_size` - The volume size per data node. Optional, default is `500`.
- `opensearch_service_volume_type` - The type of storage to use per data node. Optional, default is `io1`.
- `opensearch_service_volume_iops` - The amount of provisioned IOPS. Setting this requires a storage_type of `io1` (must be `1000` or higher) or `gp3` (only for `gp3` disks 400 GB or larger). Optional, default is `null`.
- `opensearch_service_multi_az` - Specifies if the OpenSearch domain is multi-AZ. Should only be disabled when HA isn't required. Optional, default is `true`.
- `opensearch_service_default_subnet_count` - Specifies the number of default subnets to use when running on the default network. Can be set to either `1`, `2` or `3`. Optional, default is `2`.
- `opensearch_service_kms_key_arn` - The ARN for an existing [AWS KMS Key](https://aws.amazon.com/kms/) to be used to encrypt the OpenSearch domain. If not provided `default_kms_key_arm` or the default AWS KMS key will be used in that order. Optional, default is `null`.
- `opensearch_service_allowed_ingress_cidr_blocks` - A list of CIDR blocks that configures the IP ranges that will be able to access OpenSearch over HTTP/HTTPs internally. Note this only applies for access from internal resources, the instance will not be accessible publicly. Optional, defaults to selected VPC internal CIDR block.
- `opensearch_service_linked_role_create` - Sets if the Toolkit should manage the [OpenSearch service-link role](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/slr.html). Will create or destroy the role when set to `true`. Set to `false` if the role already exists in the AWS account. Refer to the [specific section below](#aws-opensearch-service-linked-iam-role) for more info. Optional, default is `false`.
- `opensearch_service_tags` - A map of additional [tags](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html) to assign to OpenSearch domain. Optional, default is `{}`.

In addition to the above there are several optional features available in AWS OpenSearch that the Toolkit can also configure via the following variables:

- `opensearch_service_master_node_count` - The number of [master nodes](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-dedicatedmasternodes.html) for the OpenSearch domain that can optionally manage the data nodes. Deploying these nodes is optional but refer to the AWS docs linked for the latest guidance. If set the general recommendation from AWS is to deploy `3` master nodes.
- `opensearch_service_master_instance_type` - The [AWS Instance Type](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/supported-instance-types.html) for the master nodes to use without the `.search` suffix. For example, to use a `c5.large` OpenSearch instance type, the value of this variable should be `c5.large`.
- `opensearch_service_warm_node_count` - The number of [UltraWarm storage nodes](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/ultrawarm.html) for the OpenSearch domain that can optionally store read only data that doesn't change often. Deploying these nodes is optional but refer to the AWS docs linked for the latest guidance but note they do require master nodes to be deployed. If set, note that the minimum supported number is `2`.
- `opensearch_service_warm_instance_type` - The [AWS UltraWarm Instance Type](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/ultrawarm.html#ultrawarm-calc) for the warm nodes to use. Note that these instance types have a different naming convention and the only options are `ultrawarm1.medium.search` and `ultrawarm1.large.search`. Refer to the AWS docs for more info.

Once the variables are set in your file you can proceed to provision the service as normal. Note that this can take several minutes on AWS's side.

Once provisioned you'll see several new outputs at the end of the process. Key from this is the `opensearch_host` output, which contains the address for the OpenSearch domain that then needs to be passed to Ansible to configure. Take a note of this address for the next step.

##### AWS OpenSearch service-linked IAM role

[AWS OpenSearch requires a service-linked role to be present](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/slr.html) in your AWS account named `AWSServiceRoleForAmazonOpenSearchService`.

A key limitation of this service managed role is that **only one can exist in the entire AWS account**. As such, you can't create more than one role or conversely delete it if it's being used.

Due to this limitation the Toolkit will _not_ attempt to create this role for you due to the likelihood of clashes, and it's strongly recommended that this role is created separately beforehand.

However, the Toolkit can be configured to manage this role for you via the `opensearch_service_linked_role_create` variable in your [Environment config file](environment_provision.md#configure-module-settings-environmenttf) (`environment.tf`). This should only be set to `true` if you are confident that there won't be any other OpenSearch domains being created in this account.

### Configuring with Ansible

To configure GitLab to use alternative search backend(s) with Ansible, point the Toolkit at the Search instance(s) in your [Environment config file](environment_configure.md#environment-config-varsyml) (`vars.yml`)

:information_source:&nbsp; This config is the same for custom search backend(s) that have been provisioned outside of Omnibus or Cloud Services. For this setup, it is required that HA is in place and the URL to connect to the search backend(s) never changes.

The available variables in Ansible for this are as follows:

- `advanced_search_hosts` - The list of search backend URLs GitLab should use for Advanced Search. Provided in Terraform outputs if provisioned earlier. **Required**.
  - When using a service such as AWS OpenSearch this will typically be only one address but still be provided in list format, e.g. `["https://<AWS_OPENSEARCH_URL>"]`.
- `advanced_search_enable` - A boolean flag to enable or disable the searching option for Advanced Search. When set to `false`, indexing is still enabled and will happen asynchronously in the background. Optional, `true` by default.

Once set, Ansible can then be run as normal. During the run it will configure the various GitLab components to use the search backend(s) as given.

After Ansible is finished running your environment will now be ready.

## Sensitive variable handling

When configuring these alternatives you'll sometimes need to configure sensitive values such as passwords. Earlier in the documentation, guidance was given on how to handle these more securely in both Terraform and Ansible. Refer to the below sections for further information.

- [Sensitive variable handling in Terraform](environment_provision.md#sensitive-variable-handling-in-terraform)
- [Sensitive variable handling in Ansible](environment_configure.md#sensitive-variable-handling-in-ansible)
