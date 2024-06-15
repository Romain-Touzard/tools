# Advanced - Custom Config / Tasks / Files, Data Disks, Advanced Search and more

- [GitLab Environment Toolkit - Quick Start Guide](environment_quick_start_guide.md)
- [GitLab Environment Toolkit - Preparing the environment](environment_prep.md)
- [GitLab Environment Toolkit - Provisioning the environment with Terraform](environment_provision.md)
- [GitLab Environment Toolkit - Configuring the environment with Ansible](environment_configure.md)
- [**GitLab Environment Toolkit - Advanced - Custom Config / Tasks / Files, Data Disks, Advanced Search, Container Registry and more**](environment_advanced.md)
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

The Toolkit by default will deploy the latest version of the selected [Reference Architecture](https://docs.gitlab.com/ee/administration/reference_architectures/). However, it can also support other advanced setups such as Geo or different component makeups such as Gitaly Sharded.

On this page we'll detail all the supported advanced setups you can do with the Toolkit. We recommend you only do these setups if you have a good working knowledge of both the Toolkit and what the specific setups involve.

[[_TOC_]]

## Custom Config

The Toolkit allows for providing custom GitLab config that will be used when setting up components via Omnibus or Helm charts.

:exclamation:&nbsp; **This is an advanced feature, and it must be used with caution**. Any custom config passed will always take precedence and may lead to various unintended consequences or broken environments if not used carefully.

Custom config should only be used in advanced scenarios where you are fully aware of the intended effects or for areas that the Toolkit doesn't support natively due to potential permutations such as:

- [OmniAuth](https://docs.gitlab.com/ee/integration/omniauth.html)
- [Custom Object Storage](https://docs.gitlab.com/ee/administration/object_storage.html)
- [Email](https://docs.gitlab.com/omnibus/settings/smtp.html)
- [GitLab agent server for Kubernetes (KAS)](https://docs.gitlab.com/ee/administration/clusters/kas.html#for-omnibus)
  - The KAS agent will be enabled in the environment as per it's defaults but further configuration of specific keys and URLs are required.

Custom configs are treated the same as our built-in config templates. As such you have access to the same variables for added flexibility.

In this section we detail how to set up custom config for Omnibus and Helm charts components respectively.

### Omnibus

Providing custom config for components deployed via Omnibus is done as follows:

1. Create a [gitlab.rb](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template) template file in the correct format with the specific custom settings you wish to apply.
1. By default, the Toolkit looks for [Jinja2 template files](https://docs.ansible.com/ansible/latest/user_guide/playbooks_templating.html) in the [environment's](environment_configure.md#2-set-up-the-environments-inventory-and-config) `files/gitlab_configs` folder path. E.G. `ansible/environments/<env_name>/files/gitlab_configs/<component>.rb.j2`. Save your file in this location with the same name.
    - Files should be saved in Ansible template format - `.j2`.
    - If you wish to store your file in a different location or use a different name the full path that Ansible should use can be set via a variable for each different component e.g. `<component>_custom_config_file`.
    - Available component options: `consul`, `postgres`, `pgbouncer`, `redis`, `redis_cache`, `redis_persistent`, `praefect_postgres`, `praefect`, `gitaly`, `gitlab_rails`, `sidekiq` and `monitor`.

:information_source:&nbsp; From GitLab 16.0 onwards note that the config format for [Gitaly](https://docs.gitlab.com/ee/update/#gitaly-omnibus-gitlab-configuration-structure-change) and [Praefect](https://docs.gitlab.com/ee/update/#praefect-omnibus-gitlab-configuration-structure-change) respectively have changed to be under a new `['configuration']` key. When looking to add Custom Config for either of these components you can still do so normal, but you should follow the new structure. For example, to change the logging level for Gitaly you would set configure this as `gitaly['configuration']['logging']['level']`.

With the above done the file will be picked up by the Toolkit and used when configuring Omnibus.

### Helm

Providing custom config for components deployed via Helm charts in Cloud Native Hybrid environments is done as follows:

1. Create a [GitLab Charts](https://docs.gitlab.com/charts/) yaml template file in the correct format with the specific custom settings you wish to apply
1. By default, the Toolkit looks for a [Jinja2 template file](https://docs.ansible.com/ansible/latest/user_guide/playbooks_templating.html) named `gitlab_charts.yml.j2` in the [environment's](environment_configure.md#2-set-up-the-environments-inventory-and-config) `files/gitlab_configs` folder path. E.G. `ansible/environments/<env_name>/files/gitlab_configs/gitlab_charts.yml.j2`. Save your file in this location with the same name.
    - Files should be saved in Ansible template format - `.j2`.
    - If you wish to store your file in a different location or use a different name the full path that Ansible should use can be set via the `gitlab_charts_custom_config_file` inventory variable.

With the above done the file will be picked up by the Toolkit and used when configuring the Helm charts.

## Custom Tasks

The Toolkit allows for providing custom Ansible tasks that can be run at several points in the setup. This allows you to run tasks as required in addition to the main GitLab setup such as installing monitoring tools.

The Toolkit has hooks to allow tasks to be run at the following points during the setup:

- Common - Tasks to run on every VM **before** the component has deployed such as installing general monitoring tools.
- Omnibus - Tasks to run on specific Omnibus VMs **after** the component has been set up via Omnibus such as installing any specific tools for the component.
- Helm - Tasks to run for the Kubernetes Cluster **after** the Charts have been deployed such as deploying additional components into the Cluster.
- Post Configure - Tasks to run against the environment **after** setup from the Ansible runner.
- Uninstall - Tasks to run as part of the uninstallation process such as uninstalling any additional tools.

:exclamation:&nbsp; **This is an advanced feature, and it must be used with caution**. Running custom tasks may lead to various unintended consequences or broken environments if not used carefully.

Setting up common tasks is done in the same manner for each hook as follows:

1. Create a standard Ansible Tasks yaml file with the tasks you wish to run.
    - The file must be in a format that can be run in Ansible's [`include_tasks`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/include_tasks_module.html) module.
    - You can add the tag `custom_tasks` to your tasks if you wish to run the tasks in isolation.
1. By default, the Toolkit looks for each hook's Custom Tasks file(s) in the [environment inventory's](environment_configure.md#2-set-up-the-environments-inventory-and-config) `files/gitlab_tasks` folder path. E.G. `ansible/environments/<env_name>/files/gitlab_tasks/<custom_tasks_file>.yml`. This is controlled by the following settings for each:
    - `common_custom_tasks_file` - Full path for the Common tasks file. Defaults to `<inventory_dir>/../files/gitlab_tasks/common.yml`.
    - `haproxy_custom_tasks_file` - Full path for the HAProxy tasks file. Defaults to `<inventory_dir>/../files/gitlab_tasks/haproxy.yml`.
    - `<component>_custom_tasks_file` - Full path for Omnibus custom tasks files. Where `<component>` should be replaced with the one intended (options below). Defaults to `<inventory_dir>/../files/gitlab_tasks/<component>.yml`.
      - Available component options: `consul`, `postgres`, `pgbouncer`, `redis`, `redis_cache`, `redis_persistent`, `praefect_postgres`, `praefect`, `gitaly`, `gitlab_rails`, `sidekiq` and `monitor`.
    - `gitlab_charts_custom_tasks_file` - Full path for the Helm custom tasks file. Defaults to `<inventory_dir>/../files/gitlab_tasks/gitlab_charts.yml`.
    - `post_configure_custom_tasks_file` - Full path for the Post Configure custom tasks file. Defaults to `<inventory_dir>/../files/gitlab_tasks/post_configure.yml`.
    - `uninstall_custom_tasks_file` - Full path for the uninstallation custom tasks file. Defaults to `<inventory_dir>/../files/gitlab_tasks/uninstall.yml`.

Any task within the [Ansible library](https://docs.ansible.com/ansible/2.9/modules/list_of_all_modules.html) can be used for custom tasks, although it's worth noting the following general guidance when writing tasks:

- Any Ansible tasks that aren't core, i.e. available within a standard Ansible install, will need their requirements installed manually before running.
- If there's a requirement to only run Common tasks across all Omnibus VMs only you can do this by setting a `when` condition on the tasks to the Toolkit provided variable `omnibus_node`.
- Except for Common, tasks will run after component setup.

## Custom Files

The Toolkit allows for copying files or folders to component node groups as desired. This can be useful when additional files are required for setup such as SSL certificates.

:exclamation:&nbsp; **This is an advanced feature, and it must be used with caution**. Adding custom files may lead to various unintended consequences or broken environments if not used carefully.

Setting up common files is straightforward. All that's required is for you to have the files ready in a location that's reachable by Ansible on the machine it's running on and then configuring Ansible to copy the files or folder from that location to a specified one on the node group as follows:

1. Place the files you wish to be copied for each component node group in a location that's reachable by Ansible. Similar to Custom Tasks we recommend you place your files or folder in the inventory under the `files/` folder, E.G. `ansible/environments/<env_name>/files/<component>/`.
1. Configure Ansible to copy the files and where to via the `*_custom_files_paths` setting (see structure below) in your [`vars.yml`](environment_configure.md#environment-config-varsyml) file.
    - Available component options: `consul`, `postgres`, `pgbouncer`, `redis`, `redis_cache`, `redis_persistent`, `praefect_postgres`, `praefect`, `gitaly`, `gitlab_rails`, `sidekiq` and `monitor`.

:information_source:&nbsp; Files are always copied before any components are configured.

The `*_custom_files_paths` setting is a list of files or folders for each component that Ansible is to copy. An example for Gitaly with descriptions below is as follows:

```yml
gitaly_custom_files_paths: [
  { src_path: "<custom_files_path>/gitaly/example_folder", dest_path: "/etc/gitlab/ssl/", mode: "0644" },
  { src_path: "<custom_files_path>/gitaly/example.file", dest_path: "/etc/gitlab/ssl/" }
]
```

- `*_custom_files_paths` - The main setting for each node group. Default is `[]`.
  - `src_path` - The path on the machine running Ansible where it can expect to find the file or folder to copy.
    - If the path is a folder it will be copied recursively as a child folder.
    - If the path is a folder and ends with a `/` only the contents of the folder will be copied.
  - `dest_path` - The path on the target machine to copy the files to.
    - If the path doesn't exist it will be created when either the path ends with a `/` or `src_path` is a directory.
  - `mode` - Sets the permissions for the file or folder to have when copied. If not specified the permissions of the source files or folder are preserved.

With the above done the files will be copied by the Toolkit.

## Custom GitLab Secrets

[GitLab runs with several secrets internally](https://docs.gitlab.com/ee/development/application_secrets.html) that the Toolkit will propagate accordingly across nodes and / or Kubernetes clusters as required.

As an additional feature, it's possible for you to pass in your own GitLab secrets, either some or all, that the Toolkit will merge with any existing secrets on the environment and subsequently propagate out.

:exclamation:&nbsp; **This is an advanced feature, and it must be used with caution**. Adding custom GitLab secrets may lead to various unintended consequences or broken environments if not used carefully.

Custom GitLab secrets can be given as a JSON string via the following variable in your [`vars.yml`](environment_configure.md#environment-config-varsyml) file:

- `gitlab_custom_secrets_json` - A JSON string containing any [GitLab secrets](https://docs.gitlab.com/ee/development/application_secrets.html) that is to be used instead of the generated defaults. Any secret passed in this string will always take precedence. Optional, default is `""`.

The value must be correctly formatted JSON that matches the structure of the GitLab secrets file for the Toolkit to parse correctly. An example of one way to do this in Ansible with a multiline YAML string is as follows:

```yml
gitlab_custom_secrets_json: |
  {
    "gitlab_workhorse": {
      "secret_token": "<example_secret>"
    }
  }
```

## Data Disks (GCP, AWS)

The Toolkit supports provisioning and configuring extra disks, AKA data disks, for each group of machines (i.e. for all Gitaly nodes). With this set up you can have additional disk volumes mounted for storing data for added resilience and flexibility.

Like other resources the process here is similar - The disks are provisioned and attached via Terraform and then configured and mounted via Ansible. Below are sections detailing each step.

### Provisioning with Terraform

Using Terraform, provision and attach the disks to the selected machine groups.

Additional config is required in your [`environment.tf`](environment_provision.md#configure-module-settings-environmenttf) file.

The config is given per node type and is passed an array of hashes (each hash represents a disk). Additionally, config differs between cloud providers; below are examples and descriptions for each provider:

**GCP**

```tf
gitaly_disks = [
  { device_name = "data", size = 500, type = "pd-ssd" },
  { device_name = "logs", size = 50 }
]
```

- `*_disks` - The main setting for each node group.
  - `device_name` - The name _and_ block device identifier for each disk attached. Must be unique per machine. **Required**.
  - `size` - The size of the disk in GB. **Optional**, default is `100`.
  - `type` - The [type](https://cloud.google.com/compute/docs/disks) of the disk. **Optional**, default is `pd-standard`.

**AWS**

```tf
gitaly_data_disks = [
  { name = "data", device_name = "/dev/sdf", size = 500, iops = 8000, snapshots = { start_time = "01:00", interval = "24", retain_count = "14" } },
  { name = "logs", device_name = "/dev/sdg" }
]
```

- `*_data_disks` - The main setting for each node group.
  - `name` - The name for each disk attached. Must be unique per machine. **Required**.
  - `device_name` = The block device name for each disk attached. For AWS, due to limitations, this must be in the format `/dev/sd[f-p]` and unique for each disk (more info [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html)). Additionally, each block device name must be available on all machines in the target group (e.g. `gitaly-1` or `gitaly-2`). **Required**.
  - `size` - The size of the disk in GB. **Optional**, default is `100`.
  - `type` - The [type](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html) of the disk. **Optional**, default is `gp3`.
  - `iops` - The amount of IOPS to provision for the disk. Only valid for types of `io1`, `io2` or `gp3`. **Optional**, default is `null`.
  - `skip_destroy` - Set this to true if you do not wish to detach the volume from the instance to which it is attached at destroy time, and instead just remove the attachment from Terraform state. This is useful when destroying an instance which has volumes created by some other means attached. **Optional**, defaults to false
  - `snapshots` - Configuration to schedule backup snapshots of the disk via AWS Data Lifecycle Manager. **Optional**
    - `start_time` - The time to start the schedule from.
    - `interval` - The interval in hours between snapshots e.g. `24`. Possible values are `1`, `2`, `3`, `4`, `6`, `8`, `12` or `24`.
    - `retain_count` - Number of snapshots that should be retained.

### Configuring with Ansible

The next step is to configure and mount the disks.

This is done with Ansible and as such will require additional config in your [`vars.yml`](environment_configure.md#environment-config-varsyml) file.

It's worth noting that the Toolkit will always mount disks via UUID to ensure the correct disks are always mounted in the same way through reboots.

The config for this area is given per node type and is passed an array of dictionaries, where each dictionary represents a disk. The config has been designed to be platform-agnostic, but the actual values may differ, in such a case the difference will be called out clearly. Below is an example of this config with full details after:

**GCP**

```yaml
gitaly_data_disks:
  - { device_name: 'data', mount_dir: '/var/opt/gitlab' }
  - { device_name: 'logs', mount_dir: '/var/log/gitlab' }
```

**AWS**

```yaml
gitaly_data_disks:
  - { device_name: '/dev/sdf', mount_dir: '/var/opt/gitlab' }
  - { device_name: '/dev/sdg', mount_dir: '/var/log/gitlab' }
```

- `*_disks` - The main setting for each node group.
  - `device_name` - The block device name of the disk. Differs depending on Cloud Provider (see below). **Required**.
    - GCP - Device name is the same as its main name. Can be either the short name of the attached disks, e.g. `data`, or the full path, e.g. `/dev/disk/by-id/google-data`.
    - AWS - Must be the block device name you provisioned with Terraform (i.e. `/dev/sd[f-p]`). Can be either the short name of device name, e.g. `sdf`, or the full path, e.g. `/dev/sdf`.
  - `mount_dir` - The path on the machine to mount the disk on.

Note that for AWS, the Toolkit will create symlinks to [match the block device name to the attached NVMe path](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/nvme-ebs-volumes.html#identify-nvme-ebs-device).

### Suggested disk mount paths for GitLab

This feature can support mounting a disk on any path in machine groups as desired.

For GitLab, we suggest the following mount paths are suggested:

- `/var/opt/gitlab` - Common path for GitLab to store stateful data (e.g. Git Repo data).
- `/var/log/gitlab` - Common path for GitLab to store its logs.

## Gitaly Setups: Cluster or Sharded

[Gitaly](https://docs.gitlab.com/ee/administration/gitaly/), which is our repo storage backend, can be run in two different ways:

- [Gitaly Cluster](https://docs.gitlab.com/ee/administration/gitaly/praefect.html) - A HA set up that stores the same copy of data on each Gitaly node with additional performance benefits. [Praefect](https://docs.gitlab.com/ee/administration/gitaly/praefect.html#praefect) is additionally deployed in this set up to manage replication and failover.
- [Gitaly Sharded](https://docs.gitlab.com/ee/administration/gitaly/configure_gitaly.html) - Individual Gitaly nodes that don't offer HA.

The Toolkit supports setting up both of these setups. This is controlled simply by not provisioning the Praefect nodes required in Cluster. If these nodes aren't present the Toolkit automatically assumes that the environment is using Gitaly Sharded and will configure in that way.

:information_source:&nbsp; Attempting to switch an existing environment from using Gitaly Cluster to Sharded or vice versa is not supported in the Toolkit and may lead to data loss.

## GitLab SSH

The `git+ssh` service in GitLab allows for users to perform [Git actions such as pushes or pulls over SSH](https://docs.gitlab.com/ee/development/gitlab_shell/features.html#git-operations). There are multiple options on how to configure this service as detailed below.

### GitLab SSH Daemon

GitLab offers two server daemon options for serving Git operations over SSH - `openssh` or [`gitlab-sshd`](https://docs.gitlab.com/ee/administration/operations/gitlab_sshd.html). The latter being a bespoke offering that provides additional features.

By default, `openssh` will be used, but you can switch over to `gitlab-sshd` via the following Ansible variable in [Environment `vars.yml` file](environment_configure.md#environment-config-varsyml):

- `gitlab_shell_ssh_daemon` - Configures what SSH server daemon GitLab should set up and use for Git operations. Options are `openssh` or `gitlab-sshd`. Default is `openssh`.

### GitLab SSH Port (External / Internal)

The Toolkit allows you to configure the External and Internal ports used for serving Git operations over SSH, where external is the port users will use and internal is the port that the selected SSH daemon runs on. These can be configured via the following Ansible variables in the [Environment `vars.yml` file](environment_configure.md#environment-config-varsyml):

- `gitlab_shell_ssh_port` - The external port to be used for serving Git operations over SSH. This port will be used to configure all parts of the external connection - HAProxy (Linux installs) or Kubernetes Ingress. Optional, default is `2222` (Linux) / `22` (Cloud Native Hybrid).
  - :information_source:&nbsp; On Linux installs with the Toolkit, the external SSH port can not be `22` to prevent clashes with the system SSH service. This is due to Ansible needing to connect over SSH in most cases.
  - :information_source:&nbsp; On Linux installs using the default HAProxy External load balancer, if the default port of `2222` is intended to be changed the port will need to be adjusted on the HAProxy External node as well. This can be done by changing the `external_ssh_port` in your Terraform [Environment config file](environment_provision.md#configure-module-settings-environmenttf) to the new value.
    - Additionally, it should be noted in this setup that the external SSH port can not be `22` to prevent clashes with the system SSH service. This is due to Ansible needing to connect over SSH in most cases.
- `gitlab_shell_ssh_internal_port` - The internal port the GitLab SSH daemon is running on. This port depends on the environmental type as well as the SSH Daemon being used. For `openssh` this port should match what the system SSH is running on and for `gitlab-sshd` this will change whatever port the service runs on (Note for `gitlab-sshd` [it can not be run on a port number lower than `1024`](https://docs.gitlab.com/ee/administration/operations/gitlab_sshd.html#enable-gitlab-sshd)). Optional, default is `22` (Linux `openssh`) / `2222` (Linux `gitlab-sshd`, Cloud Native Hybrid).

## Advanced Search

The Toolkit supports automatically setting up GitLab's [Advanced Search](https://docs.gitlab.com/ee/integration/advanced_search/elasticsearch.html) functionality. This includes provisioning and configuring [OpenSearch](https://opensearch.org/) nodes to be a cluster as well as configuring GitLab to use it.

:information_source:&nbsp; Note that to be able to enable Advanced Search you'll require at least a GitLab Premium License.

Due to the nature of OpenSearch it's difficult to give specific guidance on what size and shape the cluster should take as it's heavily dependent on aspects such as data or expected usage. That being said [some guidance for Elasticsearch that also applies to OpenSearch can be found in our Advanced Search documentation](https://docs.gitlab.com/ee/integration/advanced_search/elasticsearch.html#guidance-on-choosing-optimal-cluster-configuration). As a starting point sizing similar to Gitaly seems to work well in most cases.

Enabling Advanced Search on your environment is designed to be as easy possible and can be done as follows:

- OpenSearch nodes should be provisioned as normal via Terraform.
- Once the nodes are available Ansible will automatically configure them, downloading and setting up the OpenSearch Docker image.
  - To deploy a specific version you can set the `opensearch_version` variable in Ansible accordingly. Otherwise the Toolkit deploys the latest supported version.
- Ansible will then configure the GitLab environment near the end of its run to enable Advanced Search against those nodes and perform the first index.
  - If it's desired to complete indexing before enabling the search feature (e.g. for large datasets that may require long indexing times), set the `advanced_search_enable` variable to `false`. Indexing will be started while the search feature is still disabled. Once indexing is complete, set `advanced_search_enable` to `true` (or remove the variable to use the default setting) and run Ansible again to enable search.

## Container Registry (GCP, AWS)

The Toolkit configures the [GitLab Container Registry](https://docs.gitlab.com/ee/user/packages/container_registry/) by default on GCP and AWS environments when [External SSL](environment_advanced_ssl.md#external-ssl) is enabled in a best practice fashion, including the management of Object Storage.

With both Omnibus and Cloud Native Hybrid setups the registry is configured to run on the subdomain `registry.<external_host>` by default, where `external_host` is the hostname configured via the `external_url` setting. For example, if an environment was configured with `external_url` set to `https://gitlab.test.com` the registry will be made available on `https://registry.gitlab.test.com`.

For all setups, the below settings configure how the service and dependents are set up:

- `container_registry_enable` - Controls whether the container registry and dependents are enabled. Optional, default is `true` when using [External SSL](environment_advanced_ssl.md#external-ssl) on AWS or GCP and if a `registry` Object Storage bucket has been configured.
- `container_registry_external_url` - The URL registry will be available on. Optional, default is `https://registry.<external_host>`.
- `gitlab_object_storage_registry_chunksize_mb` - The registry chunksize for multi-part uploads. Note this only applies when using Registry with Object Storage on either AWS or GCP. Consider increasing it somewhere between 25 and 50 if experiencing failures with large images, see [GitLab documentation](https://docs.gitlab.com/ee/administration/packages/container_registry.html#aws-s3-with-the-gitlab-registry-error-when-pushing-large-images) for more information. Optional, default is `10` on AWS and `5` on GCP.

:information_source:&nbsp; When configuring [External SSL with user provided certificates](environment_advanced_ssl.md#user-provided-certificates) the URL configured via `container_registry_external_url` must be included as a Subject Alternative Name (SAN) name.

## Pages

:information_source:&nbsp; Pages is currently only supported on Cloud Native Hybrid installations.

Ansible variables are available to configure the [GitLab Charts' Pages sub-chart](https://docs.gitlab.com/charts/charts/gitlab/gitlab-pages/) as part of a GET-managed cloud-native hybrid installation:

- `pages_external_url` -  [Wildcard URL root](https://docs.gitlab.com/ee/administration/pages/index.html#wildcard-domains) that will be used to serve Pages content for this instance. Provided as a url format including protocol, e.g. `https://pages.example.io`. Specifying HTTPS protocol will enable wildcard SSL, and require `pages_ssl_cert_file` and `pages_ssl_key_file` to be specified. **Required**.
- `pages_ssl_cert_file` - Path to SSL certificate file for the Pages daemon to serve. Must be specified with `pages_ssl_key_file`. Required if `pages_external_url` protocol is HTTPS. Certificate must meet [the following requirements](https://docs.gitlab.com/ee/administration/pages/index.html#wildcard-domains-with-tls-support).
  - `pages_ssl_cert` - An alternative to `pages_ssl_cert_file` if the certificate is not stored in a local file, to pass the certificate contents directly to Ansible. Use `pages_ssl_cert`, or `pages_ssl_cert_file`, but not both. This approach can be used to retrieve the certificate via a lookup.
- `pages_ssl_key_file` - Path to key file for SSL certificate that the Pages daemon will serve. Must be specified with `pages_ssl_cert_file`. Required if `pages_external_url` protocol is HTTPS.
  - `pages_ssl_key` - An alternative to `pages_ssl_key_file` if the private key is not stored in a local file, to pass the private key contents directly to Ansible. Use `pages_ssl_key`, or `pages_ssl_key_file`, but not both. This approach can be used to retrieve the private key via a lookup.

## Custom Servers (On Prem)

While the Toolkit has primarily been designed to support Cloud Providers, there is partial support for configuring Custom Servers (e.g. On prem servers running locally in your network) with Ansible via a [Static Inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html).

Note the following before proceeding:

- Your milage may vary - Due to the sheer potential number of customizations this support is offered on a best effort basis.
- Custom Server setups must follow the [requirements](../README.md#requirements).
- Terraform support is not available. VMs and services must be provisioned separately.
- [Object Storage](https://docs.gitlab.com/ee/administration/object_storage.html) config must be configured via [Custom Config](#custom-config) on any GitLab Rails or Sidekiq nodes as well as Helm Chart for Cloud Native Hybrid environments.
- Data Disks configuration is not supported. These must be configured separately.
- On Cloud Native Hybrid environments the Kubernetes cluster must be configured as per the [Reference Architectures](https://docs.gitlab.com/ee/administration/reference_architectures/10k_users.html#cloud-native-hybrid-reference-architecture-with-helm-charts-alternative) and `kubeconfig` file created separately.

To configure Custom Servers with Ansible the setup process involves the following:

1. Creating a Static Inventory file
1. Generating the Facts Cache
1. Configuring the [Environment `vars.yml` file](environment_configure.md#environment-config-varsyml)

Refer to each section below for how to do each:

### Environment Config

Configuring the environment config `vars.yml` file is [much the same as it would be normally](environment_configure.md#environment-config-varsyml) with the following differences:

- `cloud_provider` **must** be set to `none`. This should be set when running with any static inventory.
- Any Cloud Provider specific variables, such as `gcp_project` should be removed.
- `prefix` can also be removed.

### Static Config

First an [Ansible Static Inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html) is required instead of a [Dynamic Inventory](environment_configure.md#configure-dynamic-inventory).

Using the same recommended structure the Static Inventory file should be saved in the inventory folder, e.g. `environments/<env_name>/inventory` alongside the [Environment `vars.yml` file](environment_configure.md#environment-config-varsyml). Several file formats are supported by Ansible but for consistency we'll use `yml` format.

An example of a 10k environment's static inventory file that's Toolkit compatible is below but note the following:

- All text in `<>` brackets should be replaced accordingly with the IP addresses that Ansible can access
- Group names (e.g. `gitaly`) and Inventory Hostnames (e.g. `gitlab-gitaly-1`) should not be replaced. These are required internally by Ansible to help correctly identify hosts.

<details><summary>10k Static Inventory</summary>

```yml
all:
  children:
    consul:
      hosts:
        gitlab-consul-1:
          ansible_host: <CONSUL-1-ADDRESS>
        gitlab-consul-2:
          ansible_host: <CONSUL-2-ADDRESS>
        gitlab-consul-3:
          ansible_host: <CONSUL-3-ADDRESS>
    gitaly:
      children:
        gitaly_primary:
          hosts:
            gitlab-gitaly-1:
              ansible_host: <GITALY-1-ADDRESS>
        gitaly_secondary:
          hosts:
            gitlab-gitaly-2:
              ansible_host: <GITALY-2-ADDRESS>
            gitlab-gitaly-3:
              ansible_host: <GITALY-3-ADDRESS>
    gitlab_nfs:
      hosts:
        gitlab-nfs-1:
          ansible_host: <GITLAB-NFS-1-ADDRESS>
    gitlab_rails:
      children:
        gitlab_rails_primary:
          hosts:
            gitlab-rails-1:
              ansible_host: <GITLAB-RAILS-1-ADDRESS>
        gitlab_rails_secondary:
          hosts:
            gitlab-rails-2:
              ansible_host: <GITLAB-RAILS-2-ADDRESS>
            gitlab-rails-3:
              ansible_host: <GITLAB-RAILS-3-ADDRESS>
    haproxy_external:
      hosts:
        gitlab-haproxy-external-1:
          ansible_host: <HAPROXY-EXTERNAL-1-ADDRESS>
    haproxy_internal:
      hosts:
        gitlab-haproxy-internal-1:
          ansible_host: <HAPROXY-INTERNAL-1-ADDRESS>
    monitor:
      hosts:
        gitlab-monitor-1:
          ansible_host: <MONITOR-1-ADDRESS>
    pgbouncer:
      hosts:
        gitlab-pgbouncer-1:
          ansible_host: <PGBOUNCER-1-ADDRESS>
        gitlab-pgbouncer-2:
          ansible_host: <PGBOUNCER-2-ADDRESS>
        gitlab-pgbouncer-3:
          ansible_host: <PGBOUNCER-3-ADDRESS>
    postgres:
      children:
        postgres_primary:
          hosts:
            gitlab-postgres-1:
              ansible_host: <POSTGRES-1-ADDRESS>
        postgres_secondary:
          hosts:
            gitlab-postgres-2:
              ansible_host: <POSTGRES-2-ADDRESS>
            gitlab-postgres-3:
              ansible_host: <POSTGRES-3-ADDRESS>
    praefect:
      children:
        praefect_primary:
          hosts:
            gitlab-praefect-1:
              ansible_host: <PRAEFECT-1-ADDRESS>
        praefect_secondary:
          hosts:
            gitlab-praefect-2:
              ansible_host: <PRAEFECT-2-ADDRESS>
            gitlab-praefect-3:
              ansible_host: <PRAEFECT-3-ADDRESS>
    praefect_postgres:
      children:
        praefect_postgres_primary:
          hosts:
            gitlab-praefect-postgres-1:
              ansible_host: <PRAEFECT-POSTGRES-1-ADDRESS>
    redis_cache:
      children:
        redis_cache_primary:
          hosts:
            gitlab-redis-cache-1:
              ansible_host: <REDIS-CACHE-1-ADDRESS>
        redis_cache_secondary:
          hosts:
            gitlab-redis-cache-2:
              ansible_host: <REDIS-CACHE-2-ADDRESS>
            gitlab-redis-cache-3:
              ansible_host: <REDIS-CACHE-3-ADDRESS>
    redis_persistent:
      children:
        redis_persistent_primary:
          hosts:
            gitlab-redis-persistent-1:
              ansible_host: <REDIS-PERSISTENT-1-ADDRESS>
        redis_persistent_secondary:
          hosts:
            gitlab-redis-persistent-2:
              ansible_host: <REDIS-PERSISTENT-2-ADDRESS>
            gitlab-redis-persistent-3:
              ansible_host: <REDIS-PERSISTENT-3-ADDRESS>
    sidekiq:
      children:
        sidekiq_primary:
          hosts:
            gitlab-sidekiq-1:
              ansible_host: <SIDEKIQ-1-ADDRESS>
        sidekiq_secondary:
          hosts:
            gitlab-sidekiq-2:
              ansible_host: <SIDEKIQ-2-ADDRESS>
            gitlab-sidekiq-3:
              ansible_host: <SIDEKIQ-3-ADDRESS>
            gitlab-sidekiq-4:
              ansible_host: <SIDEKIQ-4-ADDRESS>
    ungrouped:
```

</details>

For smaller environments where Redis is combined it would look as follows:

<details><summary>Redis Static Inventory</summary>

```yml
all:
  children:
    redis:
      children:
        redis_primary:
          hosts:
            gitlab-redis-1:
              ansible_host: <REDIS-1-ADDRESS>
        redis_secondary:
          hosts:
            gitlab-redis-2:
              ansible_host: <REDIS-2-ADDRESS>
            gitlab-redis-3:
              ansible_host: <REDIS-3-ADDRESS>
```

</details>

For environments with OpenSearch nodes, the static inventory should have OpenSearch hosts information:

<details><summary>OpenSearch Static Inventory</summary>

```yml
all:
  children:
    opensearch:
      children:
        opensearch_primary:
          hosts:
            gitlab-opensearch-1:
              ansible_host: <OPENSEARCH-1-ADDRESS>
        opensearch_secondary:
          hosts:
            gitlab-opensearch-2:
              ansible_host: <OPENSEARCH-2-ADDRESS>
            gitlab-opensearch-3:
              ansible_host: <OPENSEARCH-3-ADDRESS>
```

</details>

For environments with Geo, the static inventory will need to follow the below example:

<details><summary>Geo Static Inventory</summary>

```yml
all:
  children:
    <GEO_(PRIMARY/SECONDARY)_SITE_NAME>:
      hosts:
        <PREFIX>-consul-1:
          ansible_host: <CONSUL-1-ADDRESS>
        <PREFIX>-consul-2:
          ansible_host: <CONSUL-2-ADDRESS>
        <PREFIX>-consul-3:
          ansible_host: <CONSUL-3-ADDRESS>
        <PREFIX>-gitaly-1:
          ansible_host: <GITALY-1-ADDRESS>
        <PREFIX>-gitaly-2:
          ansible_host: <GITALY-2-ADDRESS>
        <PREFIX>-gitaly-3:
          ansible_host: <GITALY-3-ADDRESS>
        <PREFIX>-gitlab-rails-1:
          ansible_host: <GITLAB-RAILS-1-ADDRESS>
        <PREFIX>-gitlab-rails-2:
          ansible_host: <GITLAB-RAILS-2-ADDRESS>
        <PREFIX>-gitlab-rails-3:
          ansible_host: <GITLAB-RAILS-3-ADDRESS>
        <PREFIX>-haproxy-external-1:
          ansible_host: <HAPROXY-EXTERNAL-1-ADDRESS>
        <PREFIX>-haproxy-internal-1:
          ansible_host: <HAPROXY-INTERNAL-1-ADDRESS>
        <PREFIX>-monitor-1:
          ansible_host: <MONITOR-1-ADDRESS>
        <PREFIX>-pgbouncer-1:
          ansible_host: <PGBOUNCER-1-ADDRESS>
        <PREFIX>-pgbouncer-2:
          ansible_host: <PGBOUNCER-2-ADDRESS>
        <PREFIX>-pgbouncer-3:
          ansible_host: <PGBOUNCER-3-ADDRESS>
        <PREFIX>-postgres-1:
          ansible_host: <POSTGRES-1-ADDRESS>
        <PREFIX>-postgres-2:
          ansible_host: <POSTGRES-2-ADDRESS>
        <PREFIX>-postgres-3:
          ansible_host: <POSTGRES-3-ADDRESS>
        <PREFIX>-praefect-1:
          ansible_host: <PRAEFECT-1-ADDRESS>
        <PREFIX>-praefect-2:
          ansible_host: <PRAEFECT-2-ADDRESS>
        <PREFIX>-praefect-3:
          ansible_host: <PRAEFECT-3-ADDRESS>
        <PREFIX>-praefect-postgres-1:
          ansible_host: <PRAEFECT-POSTGRES-1-ADDRESS>
        <PREFIX>-redis-1:
          ansible_host: <REDIS-1-ADDRESS>
        <PREFIX>-redis-2:
          ansible_host: <REDIS-2-ADDRESS>
        <PREFIX>-redis-3:
          ansible_host: <REDIS-3-ADDRESS>
        <PREFIX>-sidekiq-1:
          ansible_host: <SIDEKIQ-1-ADDRESS>
        <PREFIX>-sidekiq-2:
          ansible_host: <SIDEKIQ-2-ADDRESS>
        <PREFIX>-sidekiq-3:
          ansible_host: <SIDEKIQ-3-ADDRESS>
        <PREFIX>-sidekiq-4:
          ansible_host: <SIDEKIQ-4-ADDRESS>
    <GEO_(PRIMARY/SECONDARY)_SITE_NAME>_gitlab_rails_primary:
      hosts:
        <PREFIX>-gitlab-rails-1:
          ansible_host: <GITLAB-RAILS-1-ADDRESS>
    <GEO_(PRIMARY/SECONDARY)_SITE_NAME>_gitlab_rails_secondary:
      hosts:
        <PREFIX>-gitlab-rails-2:
          ansible_host: <GITLAB-RAILS-2-ADDRESS>
        <PREFIX>-gitlab-rails-3:
          ansible_host: <GITLAB-RAILS-3-ADDRESS>
    <GEO_(PRIMARY/SECONDARY)_SITE_NAME>_haproxy_internal_primary:
      hosts:
        <PREFIX>-haproxy-internal-1:
          ansible_host: <POSTGRES-1-ADDRESS>
    <GEO_(PRIMARY/SECONDARY)_SITE_NAME>_postgres_primary:
      hosts:
        <PREFIX>-postgres-1:
          ansible_host: <POSTGRES-1-ADDRESS>
    <GEO_(PRIMARY/SECONDARY)_SITE_NAME>_postgres_secondary:
      hosts:
        <PREFIX>-postgres-2:
          ansible_host: <POSTGRES-2-ADDRESS>
        <PREFIX>-postgres-3:
          ansible_host: <POSTGRES-3-ADDRESS>
    <GEO_(PRIMARY/SECONDARY)_SITE_NAME>_sidekiq_primary:
      hosts:
        <PREFIX>-sidekiq-1:
          ansible_host: <SIDEKIQ-1-ADDRESS>
    <GEO_(PRIMARY/SECONDARY)_SITE_NAME>_sidekiq_secondary:
      hosts:
        <PREFIX>-sidekiq-2:
          ansible_host: <SIDEKIQ-2-ADDRESS>
        <PREFIX>-sidekiq-3:
          ansible_host: <SIDEKIQ-3-ADDRESS>
        <PREFIX>-sidekiq-4:
          ansible_host: <SIDEKIQ-4-ADDRESS>
    consul:
      hosts:
        <PREFIX>-consul-1:
          ansible_host: <CONSUL-1-ADDRESS>
        <PREFIX>-consul-2:
          ansible_host: <CONSUL-2-ADDRESS>
        <PREFIX>-consul-3:
          ansible_host: <CONSUL-3-ADDRESS>
    gitaly:
      children:
        gitaly_primary:
          hosts:
            <PREFIX>-gitaly-1:
              ansible_host: <GITALY-1-ADDRESS>
        gitaly_secondary:
          hosts:
            <PREFIX>-gitaly-2:
              ansible_host: <GITALY-2-ADDRESS>
            <PREFIX>-gitaly-3:
              ansible_host: <GITALY-3-ADDRESS>
    gitlab_rails:
      children:
        gitlab_rails_primary:
          hosts:
            <PREFIX>-gitlab-rails-1:
              ansible_host: <GITLAB-RAILS-1-ADDRESS>
        gitlab_rails_secondary:
          hosts:
            <PREFIX>-gitlab-rails-2:
              ansible_host: <GITLAB-RAILS-2-ADDRESS>
            <PREFIX>-gitlab-rails-3:
              ansible_host: <GITLAB-RAILS-3-ADDRESS>
    haproxy_external:
      hosts:
        <PREFIX>-haproxy-external-1:
          ansible_host: <HAPROXY-EXTERNAL-1-ADDRESS>
    haproxy_internal:
      hosts:
        <PREFIX>-haproxy-internal-1:
          ansible_host: <HAPROXY-INTERNAL-1-ADDRESS>
    monitor:
      hosts:
        gitlab-monitor-1:
          ansible_host: <MONITOR-1-ADDRESS>
    pgbouncer:
      hosts:
        gitlab-pgbouncer-1:
          ansible_host: <PGBOUNCER-1-ADDRESS>
        gitlab-pgbouncer-2:
          ansible_host: <PGBOUNCER-2-ADDRESS>
        gitlab-pgbouncer-3:
          ansible_host: <PGBOUNCER-3-ADDRESS>
    postgres:
      children:
        postgres_primary:
          hosts:
            <PREFIX>-postgres-1:
              ansible_host: <POSTGRES-1-ADDRESS>
        postgres_secondary:
          hosts:
            <PREFIX>-postgres-2:
              ansible_host: <POSTGRES-2-ADDRESS>
            <PREFIX>-postgres-3:
              ansible_host: <POSTGRES-3-ADDRESS>
    praefect:
      children:
        praefect_primary:
          hosts:
            gitlab-praefect-1:
              ansible_host: <PRAEFECT-1-ADDRESS>
        praefect_secondary:
          hosts:
            gitlab-praefect-2:
              ansible_host: <PRAEFECT-2-ADDRESS>
            gitlab-praefect-3:
              ansible_host: <PRAEFECT-3-ADDRESS>
    praefect_postgres:
      children:
        praefect_postgres_primary:
          hosts:
            gitlab-praefect-postgres-1:
              ansible_host: <PRAEFECT-POSTGRES-1-ADDRESS>
    redis:
      children:
        redis_primary:
          hosts:
            <PREFIX>-redis-1:
              ansible_host: <REDIS-1-ADDRESS>
        redis_secondary:
          hosts:
            <PREFIX>-redis-2:
              ansible_host: <REDIS-2-ADDRESS>
            <PREFIX>-redis-3:
              ansible_host: <REDIS-3-ADDRESS>
    sidekiq:
      children:
        sidekiq_primary:
          hosts:
            <PREFIX>-sidekiq-1:
              ansible_host: <SIDEKIQ-1-ADDRESS>
        sidekiq_secondary:
          hosts:
            <PREFIX>-sidekiq-2:
              ansible_host: <SIDEKIQ-2-ADDRESS>
            <PREFIX>-sidekiq-3:
              ansible_host: <SIDEKIQ-3-ADDRESS>
            <PREFIX>-sidekiq-4:
              ansible_host: <SIDEKIQ-4-ADDRESS>
    ungrouped:
```

</details>

### Facts Cache (Optional)

When running select playbooks, e.g. running a playbook only for `haproxy` - `ansible-playbook -i <inventory> playbooks/haproxy.yml`, some additional preparation is required when using a Static Inventory.

Unlike Dynamic Inventories, in this scenario only facts for the HAProxy hosts and no others are collected. This will cause the play to fail as the Toolkit expects to be able to access facts for all hosts throughout.

:information_source:&nbsp; This _doesn't_ affect playbooks that run on all hosts, such as `all.yml`, as these will gather facts at runtime.

To work around this limitation a persistent [Fact Cache](https://docs.ansible.com/ansible/latest/plugins/cache.html#cache-plugins) is recommended where all host facts are saved and made available on subsequent runs.

An example would be the [`jsonfile`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/jsonfile_cache.html#ansible-collections-ansible-builtin-jsonfile-cache) cache where all facts are saved to disk. This would only need to be generated once initially and only run again if any of the hosts change.

Refer to the [Ansible docs](https://docs.ansible.com/ansible/latest/plugins/cache.html#cache-plugins) for more info.

## System Packages

The Toolkit will install system packages on every node it requires for setting up GitLab.

In addition to this it will configure automated security upgrades and can optionally go further and run full package upgrades if desired. Refer to each section below for more information.

### Automatic Security Upgrades

The Toolkit will set up automatic security upgrades as a convenience on the target OS as follows:

- Ubuntu / Debian - [Unattended Upgrades](https://help.ubuntu.com/community/AutomaticSecurityUpdates).
- RHEL 8 / Amazon Linux 2023 - [DNF Automatic](https://dnf.readthedocs.io/en/latest/automatic.html).
- Amazon Linux 2 - [Yum Cron](https://man7.org/linux/man-pages/man8/yum-cron.8.html)

The role(s) configure the following:

- Security updates will be installed at least once per day
- The Toolkit will also run the same updates directly whenever it's run
- Automatic reboots are disabled to ensure runtime

If this behaviour is not desired you can disable this by setting the `system_packages_auto_security_upgrade` variable to `false` (can also be set via environment variable `SYSTEM_PACKAGES_AUTO_SECURITY_UPGRADE`). Note if setting this after it was previously configured the `unattended-upgrades` or `dnf-automatic` package will still need to be purged manually on affected boxes.

### Optional Package Maintenance

The Toolkit can also optionally upgrade all packages and clean up unneeded packages on your nodes on each run. The following settings control this behaviour and can be set in your Ansible environment config file (`vars.yml`) if desired:

- `system_packages_upgrade`: Configures the Toolkit to upgrade all packages on nodes. Default is `false`. Can also be set as via the environment variable `SYSTEM_PACKAGES_UPGRADE`.
- `system_packages_autoremove`: Configures the Toolkit to autoremove any old or unneeded packages on nodes. Default is `false`. Can also be set as via the environment variable `SYSTEM_PACKAGES_AUTOREMOVE`.

## NFS for Object Data

You can optionally provision and configure a [NFS server if desired to handle Object Data](https://docs.gitlab.com/ee/administration/nfs.html). This is not recommended however with [Object Storage](https://docs.gitlab.com/ee/administration/object_storage.html) instead preferable in all cases. To configure this some steps are required in Terraform and Ansible.

In Terraform, you'll need to provision a `gitlab_nfs` node in your [`environment.tf`](environment_provision.md#configure-module-settings-environmenttf) file. For example in AWS:

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  [...]

  gitlab_nfs_node_count    = 1
  gitlab_nfs_instance_type = "c5.xlarge"
}
```

Then in Ansible you need to configure the `gitlab_object_storage_type` variable to `nfs` in your [`vars.yml`](environment_configure.md#environment-config-varsyml) file:

```yml
gitlab_object_storage_type: 'nfs'
```

## Custom IAM options (AWS)

The Toolkit provides several customization options for configuring AWS IAM.

### Custom IAM Instance Policies (AWS)

[In AWS, you can attach IAM Instance Profiles / Roles to EC2 Instances](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html). These Roles can then contain [Policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html) (AKA permissions) that are attached to the instance to allow it to perform actions against AWS APIs, e.g. accessing Object Storage.

The Toolkit uses this functionality in several places to ensure the needed permissions for GitLab are set on the right instances.

As a convenience, you can also pass in additional Policies to either all instances or specific component instances as required (AWS Managed or custom). The Toolkit will manage the Role and attach these policies for you.

Passing in your policies is done in Terraform via the following variables in your `environment.tf` file. Note that for individual component instances the same variable suffix is used throughout, for readability this is defined once only:

- `default_iam_instance_policy_arns` - List of IAM Policy [ARNs](https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html) to attach on all Instances, for example `["arn:aws:iam::aws:policy/AmazonS3FullAccess"]`. Defaults to `[]`.
- `*_iam_instance_policy_arns` - List of IAM Policy [ARNs](https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html) to attach on all Instances. For example if `gitaly_iam_instance_policy_arns` was set to `["arn:aws:iam::aws:policy/AmazonS3FullAccess"]` then this Policy would be applied to all Gitaly instances via a new Role. Defaults to `[]`.

### Custom IAM Permissions Boundary (AWS)

The Toolkit also allows for there to be a [Permissions Boundary](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html) to be set for all IAM Roles it creates.

:exclamation:&nbsp; **This is an advanced feature, and it must be used with caution**. Boundaries must allow for all Policies the Toolkit uses to be allowed, or your environment will become unstable. [The latest list of policies used by the Toolkit is shown here](https://gitlab.com/search?search=2012-10-17&nav_source=navbar&project_id=14292404&group_id=9970&search_code=true&repository_ref=main).

While the Toolkit will be designed in line with least privilege and ensuring all such IAM entities only have the access they require to do their role you may have a general policy to always apply a "global" permissions boundary as an additional security measure.

To do this you first create the boundary policy separately in AWS and take note of its ARN. Then you should pass the ARN to the Toolkit via the following variable in the Terraform [Environment config file](environment_provision.md#configure-module-settings-environmenttf):

- `default_iam_permissions_boundary_arn` - The IAM ARN of a [Permissions Boundary](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html) policy to be applied to all IAM Roles the Toolkit creates. Defaults to `null`.

The Toolkit will then apply this boundary on the next `terraform apply` run.

### Custom IAM Path (AWS)

:exclamation:&nbsp; This feature may be deprecated and removed in the future. It is specifically not known to work with AWS EKS at this time and as a result is not supported for Cloud Native Hybrid set-ups. For more information please refer to this [issue](https://gitlab.com/gitlab-org/gitlab-environment-toolkit/-/issues/746).

The Toolkit allows to configure a custom [Path](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html) for all IAM Roles and Policies it creates. As detailed in the AWS documentation, you can use a single path, or nest multiple paths as a folder structure. This allows to match your company organizational structure.

To configure custom Path add the following variable in the Terraform [Environment config file](environment_provision.md#configure-module-settings-environmenttf):

- `default_iam_identifier_path` - The IAM [Path](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html) to be applied to all IAM Policies and Roles the Toolkit creates. Defaults to `null` which in turn results in `/` default path in AWS.

The Toolkit will then apply the path on the next `terraform apply` run.
