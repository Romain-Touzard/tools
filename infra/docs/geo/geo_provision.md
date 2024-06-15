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
  - [**GitLab Environment Toolkit - Geo - Provisioning the environment with Terraform**](geo_provision.md)
  - [GitLab Environment Toolkit - Geo - Configuring the environment with Ansible](geo_configure.md)
  - [GitLab Environment Toolkit - Geo - Advanced](geo_advanced.md)
- [GitLab Environment Toolkit - Troubleshooting](../environment_troubleshooting.md)

[[_TOC_]]

## Terraform

When creating a new Terraform site for Geo it is recommended to create a new subfolder for your Geo deployment with sub-folders below that for each Geo sites config. Although not required, this does help to keep all the config for a single Geo deployment in one location. Each separate environment will always need their own folder here for Terraform to manage their State correctly.

```bash
my-geo-deployment
    ├── site1
    ├── site2
    └── site3
    ...
```

Next it is recommended to copy an existing reference architecture for each site. You could copy the 10k reference architecture to use as your primary site and the 3k for your secondary, or use 5k for both your primary and secondary sites, the Geo process will work for any combination with the same steps.

The main steps, up to the provisioning step, for [GitLab Environment Toolkit - Building environments](../environment_provision.md) should be followed when creating a new Terraform project.

Once you have copied the desired architecture sizes we will need to modify them to allow for Geo. The first step is to adjust the `ref_arch` module source variable, within the `environment.tf` file, to point to the right location. If you've followed the folder structure above, you will need to add an additional `../` to the path as we are now using sub-folders. For example:

```tf
module "gitlab_ref_arch_*" {
  source = "../../modules/gitlab_ref_arch_*"

  [...]
```

Next you need to add some new labels to every site within you deployment. These labels are used to identify each site as belonging to your Geo deployment:

- `geo_site` - used to identify each site with unique identifier. This should be a unique way to identify a site e.g. `london-office`. We recommend avoiding terms like primary and secondary in these site names, this is because the primary and secondary sites can change when performing failover.
- `geo_deployment` - used to identify that primary and secondary sites belong to the same Geo deployment. This must be unique across all Geo deployments that will be stored alongside each other e.g. within the same GCP project.

You will need to add them into your `environment.tf` file:

```tf
module "gitlab_ref_arch_*" {
  source = "../../modules/gitlab_ref_arch_*"

  geo_site = "geo-site-london"
  geo_deployment = "my-geo-deployment"

  [...]
```

Once the configuration has been updated, you may need to add some additional configuration settings depending on your setup. If you are using cloud provided [object storage replication](./geo_provision.md#object-storage-replication) or [VPC Peering](./geo_provision.md#vpc-peering) then you should read the corresponding sections below. Once all settings are in place we can run the `terraform apply` command against the primary site followed by any secondary sites.

## Object Storage Replication

By default, object storage replication will be handled by GitLab, if required, object storage replication can be configured to be handled by the cloud provider instead. To do so you will first need to disable Ansible from enabling replication by adding `geo_enable_object_storage_replication: false` into your primary site's Ansible inventory.
Next you will need to follow the below steps for your cloud provider.

### GCP Bucket Replication

For Cloud Native Hybrid environments using GCP, depending on your bucket setup, you will need to add at least one of the following labels to the secondary config to enable object storage replication with the primary in the `environment.tf` file:

- `geo_primary_site_object_storage_prefix` - The prefix used for buckets on the primary site. If a custom prefix was used for the buckets on the primary with the `object_storage_prefix` setting, this should match that value, if no custom naming was used this should match the `prefix` setting for the primary site.
- `geo_primary_site_object_storage_buckets` - The list of all bucket names used on the primary site to setup replication with. Should be set only if the list of buckets on the Primary site was changed via the [`object_storage_buckets`](../environment_provision.md#configure-module-settings-environmenttf) setting.

An example of setting these variables would be:

```tf
  geo_primary_site_object_storage_buckets = ["artifacts", "backups", "dependency-proxy"]
  geo_primary_site_object_storage_prefix = "geo-primary-bucket-prefix"
```

### AWS S3 Bucket Replication

Enabling [AWS Object Storage Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html) will automatically copy new items from your current primary's S3 storage buckets to your secondaries. To enable this you will first need to create the buckets for your primary and secondary sites. Once the secondary site is created. you will be able to take the object storage buckets information from the Terraform output.

:exclamation:&nbsp; Ensure you copy over all the values listed below in full. Failure to do so will cause Geo Replication to fail.

```json
  "object_storage_buckets": {
    "artifacts" = "<artifacts_bucket_arn>"
    "backups" = "<backups_bucket_arn>"
    "dependency-proxy" = "<dependency-proxy_bucket_arn>"
    "lfs" = "<lfs_bucket_arn>"
    "mr-diffs" = "<mr-diffs_bucket_arn>"
    "packages" = "<packages_bucket_arn>"
    "registry" = "<registry_bucket_arn>"
    "terraform-state" = "<terraform-state_bucket_arn>"
    "uploads" = "<uploads_bucket_arn>"
    "ci_secure_files" = "<ci_secure_files_bucket_arn>"
  },
  "object_storage_kms_key_arn": "<object_storage_kms_key_arn>"
```

Using this output, add the below values to the primary sites `environment.tf` file. These values are used so that the primary can setup replication rules with the secondaries buckets.

- `object_storage_destination_buckets` - A map of each destination buckets name and ARN. For example:

  ```yml
  object_storage_destination_buckets = tomap({
      "artifacts"        = "<artifacts_bucket_arn>"
      "backups"          = "<backups_bucket_arn>"
      "dependency-proxy" = "<dependency-proxy_bucket_arn>"
      "lfs"              = "<lfs_bucket_arn>"
      "mr-diffs"         = "<mr-diffs_bucket_arn>"
      "packages"         = "<packages_bucket_arn>"
      "registry"         = "<registry_bucket_arn>"
      "terraform-state"  = "<terraform-state_bucket_arn>"
      "uploads"          = "<uploads_bucket_arn>"
      "ci_secure_files"  = "<ci_secure_files_bucket_arn>"
    })
  ```

- `object_storage_replica_kms_key_id` - The ARN used to encrypt the secondaries object storage buckets.

Once the settings have been added you will need to rerun `terraform apply` for the primary site. This will create the replication rules from the primary's source buckets to the secondaries.

:information_source:&nbsp; Once replication is enabled AWS will only replicate new objects. AWS recommends using [batch replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-batch-replication-batch.html) to copy any existing items.

## VPC Peering

Currently, the Toolkit supports configuring VPC peering only for AWS, [support for GCP](https://gitlab.com/gitlab-org/gitlab-environment-toolkit/-/issues/657) is planned to be added later.

### VPC Peering (AWS)

The Toolkit can configure [AWS VPC peering](https://docs.aws.amazon.com/vpc/latest/peering/vpc-peering-basics.html) which allows traffic to flow in both directions from a primary and secondary site just like a normal internal connection. This is required if the Geo sites are located in different AWS regions.

:information_source:&nbsp; Peering can only be configured directly by the Toolkit when using a [created network](../environment_advanced_network.md#created-aws) with `create_network = true` on all Geo sites. For existing networks, peering should be configured separately.

:information_source:&nbsp; Peering is only available when using a single secondary site.

AWS VPC peering requires a handshake, a VPC must first request the peering and the other has to then accept it. As such, this requires Terraform to be executed a couple of times to go through this process.

To set up VPC peering:

1. On the primary site, provision it by running `terraform apply`. This will output some values that are required by the secondary site to set up peering.

   ```json
   "network" = {
     "peer_connection_id" = "<peer_connection_id>"
     "vpc_cidr_block" = "<vpc_cidr_block>"
     "vpc_id" = "<vpc_id>"
     "vpc_subnet_priv_ids" =["vpc_subnet_priv_id1", "vpc_subnet_priv_id2"]
     "vpc_subnet_pub_ids" = ["vpc_subnet_pub_id1", "vpc_subnet_pub_id2"]
   }
   ```

2. Using the Terraform output in the last step, add the below values to the secondary site's `environment.tf` file. These values are used so that the secondary site is able to set up a peering connection with the primary site's VPC.

   - `peer_region` - The AWS region used for the primary site. This won't be in the output for Terraform but is something that is defined as part of the environment config.
   - `peer_vpc_id` - The VPC ID of the primary site.
   - `peer_vpc_cidr` - The CIDR used for the internal network as part of the VPC.

   :information_source:&nbsp; When setting up VPC peering, the CIDR used for each VPC must be different and cannot overlap.

3. On the secondary site, provision it by running `terraform apply`. This will output some values that are required by the primary site to complete the peering setup.

   ```json
   "network" = {
     "peer_connection_id" = "<peer_connection_id>"
     "vpc_cidr_block" = "<vpc_cidr_block>"
     "vpc_id" = "<vpc_id>"
     "vpc_subnet_priv_ids" =["vpc_subnet_priv_id1", "vpc_subnet_priv_id2"]
     "vpc_subnet_pub_ids" = ["vpc_subnet_pub_id1", "vpc_subnet_pub_id2"]
   }
   ```

4. Using the Terraform output in the last step, add the below values to the primary site's `environment.tf` file.

   - `peer_connection_id` - The ID of the peer connection created.
   - `peer_vpc_cidr` - The CIDR used for the internal network as part of the VPC on the secondary site.

5. On the primary site, rerun `terraform apply`. This will accept the peering request created by the secondary site as well as create routing and firewall rules to allow traffic from the secondary VPC. After this, peering will now be configured and allow your Geo sites to communicate internally.
