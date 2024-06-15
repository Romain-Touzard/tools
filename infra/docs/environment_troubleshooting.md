# Troubleshooting

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
- [GitLab Environment Toolkit - Considerations After Deployment - Backups, Security](environment_post_considerations.md)
- [GitLab Environment Toolkit - Geo](geo/README.md)
  - [GitLab Environment Toolkit - Geo - Provisioning the environment with Terraform](geo/geo_provision.md)
  - [GitLab Environment Toolkit - Geo - Configuring the environment with Ansible](geo/geo_configure.md)
  - [GitLab Environment Toolkit - Geo - Advanced](geo/geo_advanced.md)
- [**GitLab Environment Toolkit - Troubleshooting**](environment_troubleshooting.md)

On this page you'll find troubleshooting guidance for various areas when using the GitLab Environment Toolkit.

[[_TOC_]]

## Troubleshooting

The Toolkit has been designed to deploy GitLab following the same steps as Omnibus or the Helm Charts.

When working with the Toolkit, you might encounter some of the following issues.

1. Check your config - The most common issues seen with the Toolkit are Terraform or Ansible misconfiguration. In below sections some of the most common misconfigurations are called out and these should be checked first.
1. Check if Omnibus / Charts is the root cause of the issue - If the Toolkit configuration looks correct then check if there is an error being thrown by Omnibus or the Charts. This may be the case if the error is occurring in `reconfigure` or `deploy charts` steps. If that's the case you should connect to either the Omnibus VM or Kubernetes Cluster and examine the logs, just as you would a standard deployment, for further info.
1. Raise an issue - If the above checks out and none of the below specific scenarios apply then that suggests it's a Toolkit issue. In that case, reach out via a support ticket or issue on this tracker for further help.

## Terraform

### GCP Resource Creation Error: `Error 400: The resource '<subnetwork>' is not ready, resourceNotReady`

In select GCP setups you may see Terraform throw the following error on the first creation:

```sh
Error: Error creating instance: googleapi: Error 400: The resource 'projects/gitlab-test-123341/regions/us-east1/subnetworks/default' is not ready, resourceNotReady
```

This looks to be a race condition issue on Google's end and is [currently being investigated by them](https://github.com/hashicorp/terraform-provider-google/issues/10972).

This error only happens once and rerunning should succeed without issue.

### External IP not found errors due to region clash

When creating External IPs on Cloud Providers they will typically be set in a specific region.

As such, when creating an environment you should ensure that it's being deployed in the same region as the IP as failing to do so will result in IP not found errors.

### Object Storage Bucket name clashes

Depending on the Cloud Provider, Object Storage bucket names have various limitations.

One key limitation is that names need to be globally unique across the Cloud Provider. As such, depending on the `prefix` or `object_storage_prefix` you have set the generated bucket names may clash with others globally, and you may see an error saying the buckets already exists. If this occurs, change either of the settings to chose different names for the buckets to workaround.

### AWS: Allocation ID not specified for Static External IP

```plaintext
Error: creating EC2 EIP Association: InvalidAllocationID.NotFound: The allocation ID 'xxx.xxx.xxx.xxx' does not exist
```

When [configuring the Terraform variables](environment_provision.md#configure-variables-variablestf-1)
`variable "external_ip_allocation"` in `variables.tf` should specify the Allocation ID, not the IP address.

## Ansible

### Omnibus Reconfigure Errors

On Omnibus environments the Toolkit will be deploying [Omnibus GitLab](https://docs.gitlab.com/omnibus/). The main part of that process is reconfigure (`gitlab-ctl reconfigure`), where Omnibus will set up the configured components. The reconfigure process can be doing a lot and, at times, you may see error(s) being thrown. You may also see Omnibus hang in some cases that in turn will cause Ansible to hang.

Debugging these errors would be the same as if you were setting up Omnibus directly, such as accessing the nodes directly and [examining the logs](https://docs.gitlab.com/omnibus/settings/logs.html). There is notable documentation available on troubleshooting Omnibus issues [here](https://docs.gitlab.com/omnibus/troubleshooting.html).

### Ansible Install Failure: `No matching distribution found`

Ansible `7.x` upwards requires Python `3.9` and higher. Attempting to install this version of Ansible via `pip` on a lower version of Python will fail with the following error:

```sh
ERROR: No matching distribution found for ansible==7.1.0
```

Upgrade your Python version to `3.9` or higher and try installing again to fix.

### Ansible unable to parse Inventory

You may see an error appear when running Ansible that it couldn't parse the passed Inventory source, for example `Failed to parse environments/<env_name>/files as an inventory source`.

1. This can happen when the wrong path is given, if there's a misconfiguration in the Inventory files, or if the inventory contains extra files that should be stored in a different location e.g. [custom config files](https://gitlab.com/gitlab-org/gitlab-environment-toolkit/-/blob/main/docs/environment_advanced.md#custom-config).

   When using the Toolkit, [an Inventory will consist of several files](environment_configure.md#2-set-up-the-environments-inventory-and-config) that detail both node details and config for Ansible to use. When Ansible is passed a folder it takes all files present and combines them accordingly.

   If the above error is showing, check that you're passing the Inventory folder (note not any specific file) and that there are no mistakes in any of the files present.

1. Missing credentials can also cause this error, with an additional error `Failed to parse <path>/<configuration>.yml with auto plugin: Failed to describe instances: Unable to locate credentials`. This will be generated if you need to set the variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` [for AWS](environment_prep.md#1-setup-provider-authentication-environment-variables), for example.

### Ansible can't find any hosts

Ansible uses a dynamic inventory, which allows it to discover hosts by
matching their names with your environment's prefix. If your Ansible
scripts are unable to find any matching hosts, check that `prefix` is
set properly across all YAML files. For example, for the 10K AWS
example, check:

1. `all.vars.prefix` in `vars.yml`
1. `gitlab_node_prefix` in `10k.aws_ec2.yml`

Also check that your cloud access credentials are correctly specified
in the environment. You can use `ansible-inventory` to see which
hosts Ansible has found:

```shell
ansible-inventory -i environments/10k/inventory --graph
```

Sample output:

```plaintext
@all:
  |--@aws_ec2:
  |  |--mytest-consul-1
  |  |--mytest-consul-2
  |  |--mytest-consul-3
  |  |--mytest-gitaly-1
  |  |--mytest-gitlab-nfs-1
  |  |--mytest-monitor-1
  |  |--mytest-praefect-1
  |--@consul:
  |  |--mytest-consul-1
  |  |--mytest-consul-2
  |  |--mytest-consul-3
  |--@gitaly:
  |  |--mytest-gitaly-1
  |--@gitaly_primary:
  |  |--mytest-gitaly-1
  |--@gitlab:
  |--@gitlab_nfs:
  |  |--mytest-gitlab-nfs-1
  |--@global:
  |--@monitor:
  |  |--mytest-monitor-1
  |--@nginx-ingress:
  |--@praefect:
  |  |--mytest-praefect-1
  |--@praefect_primary:
  |  |--mytest-praefect-1
  |--@ungrouped:
```

You can also troubleshoot Ansible issues by using `ansible-inventory` to
show the configuration for specific hosts from. For example, suppose in
the above example you wanted to display what Ansible has loaded for
`mytest-gitaly-1`. The following command would show JSON data for many
of the variables used in the playbooks:

```shell
ansible-inventory -i environments/10k/inventory --graph --host mytest-gitaly-1
```

### OS Package repository issues

A subtle issue that can occur is when the OS repository script the [Toolkit is configured to use](environment_configure.md#repository) for setting up the repo is not correct for the target OS. When this occurs you may see a message such as `Package gitlab-ee cannot be found`.

Examples of this include the GitLab repo not having packages for the specific OS version or CPU architecture type.

To fix this the "bad" repository should be removed as per the OS instructions and then the correct one configured via Ansible in a subsequent run.

### Postgres Upgrade Error: `PostgreSQL did not respond before service checks were exhausted`

The following error can show when running the Toolkit on PostgreSQL nodes:

```sh
ruby_block[wait for postgresql to start] (patroni::enable line 105) had an error: RuntimeError: PostgreSQL did not respond before service checks were exhausted
```

This is due to a [rare application issue](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/5969) where the specific Secondary Postgres server has become corrupted and unable to sync replication with the Primary server, causing it to enter a restart loop.

If you examine the specific Postgres server's logs (`/var/log/gitlab/patroni/current`) you'll likely see the real error as follows:

```sh
LOG:  invalid resource manager ID in primary checkpoint record
PANIC:  could not locate a valid checkpoint record
/var/opt/gitlab/postgresql:5432 - rejecting connections
FATAL:  the database system is starting up
/var/opt/gitlab/postgresql:5432 - rejecting connections
FATAL:  the database system is starting up
LOG:  startup process (PID 3711) was terminated by signal 6: Aborted
LOG:  aborting startup due to startup process failure
```

To fix this you need to reset the WAL log on the specific server as follows:

```sh
sudo su - gitlab-psql -c '/opt/gitlab/embedded/bin/pg_resetwal -f /var/opt/gitlab/postgresql/data'
```

:exclamation:&nbsp; This command deletes the current record and as such may lead to data loss. It should only be run on the specific server with the corrupted log.

This wipes the records from the specific server and will unblock it to start replicating again. This should **only** be run on the specific Secondary server that is failing and no others as this would lead to data loss.

### External Postgres Connection Error from Ansible: `unable to connect to database: FATAL: <reason>`

As a convenience, the Toolkit attempts to prep any external database it's given for GitLab such as creating users or enabling extensions. It does this directly before setting up GitLab.

There may be times though, depending on the database setup, where Ansible is unable to connect to the database such as when mutual 2-way SSL authentication is enabled due to limitations.

When this is the case external database preparation needs to be completed manually before running Ansible. [Head to this section for more info](environment_advanced_services.md#database-preparation).

### Rails or Sidekiq fails to deploy due to Redis `URI::InvalidURIError` error

As part of the Omnibus reconfigure step you may see the following error occurring for Rails or Sidekiq nodes:

```sh
URI::InvalidURIError: bad URI(is not URI?): "redis://<password>@gitlab-redis-cache"
```

This can happen as the password for the Redis cluster is required to be part of the URL for clients. As a result, if the password contains forbidden characters for http URLs the above error may show.

To fix, adjust the Redis password to not contain any URL forbidden characters and rerun Ansible.

### Worker thread was found in dead state

[This is due to an issue with certain Python plugins](https://github.com/ansible/ansible/issues/32554#issuecomment-642896861) on your system. You can work around this by running `export no_proxy="*"` before running the `ansible-playbook` commands.

### Amazon Linux 2 install issue due to repository change after 2022-08-22

[Dedicated Omnibus GitLab packages were made available for Amazon Linux 2](https://about.gitlab.com/blog/2022/05/02/amazon-linux-2-support-and-distro-specific-packages/) from version `14.9.0`. To support this the official package repositories were further changed from `15.3.0` onwards.

As a result, for existing setups before the release of `15.3.0` (August 22, 2022) the package repository on the machines will be changed over.

This changeover will cause failures until the repository cache is reset as a one off as detailed in the above linked blog post:

```sh
if yum list installed gitlab-runner; then yum clean all ; yum makecache; fi
```

After the cache is reset the setup should work again as normal.

### Unable to execute ssh command line on a controller due to: [Errno 24] Too many open files

[This can occur for some people if Ansible is trying run multiple tasks at once](https://github.com/ansible/ansible/issues/12259). The safest way to resolve this is to lower the `forks` setting in your `ansible.cfg` file to `20`. The `ansible.cfg` file can be found at `./ansible/ansible.cfg` within your toolkit checkout.

### GitHub Rate Limit exceeded error by Node Exporter role

The Toolkit makes use of the `geerlingguy.node_exporter` Ansible role to install the Prometheus Node Exporter on several nodes where the GitLab Linux package isn't used (such as HAProxy or OpenSearch). This role checks for the latest version of Node Exporter via the GitHub API by default.

However in some cases you may find this check may fail as GitHub has a [rate limit of 60 per hour for unauthenticated requests](https://docs.github.com/en/rest/overview/resources-in-the-rest-api?apiVersion=2022-11-28#rate-limits-for-requests-from-personal-accounts). This may happen in situations such as running the install multiple times in succession or if the nodes access the internet via the same point such as a NAT. If this happens you would see an error similar to the following:

```sh
FAILED - RETRYING: [REDACTED_HOSTNAME -> localhost]: Determine latest GitHub release (local) (1 retries left).
TASK [geerlingguy.node_exporter : Determine latest GitHub release (local)] *****
...
fatal: [REDACTED_HOSTNAME -> localhost]: FAILED! => changed=false
    documentation_url: https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting
    message: 'API rate limit exceeded for [REDACTED_IP]. (But here''s the good news: Authenticated requests get a higher rate limit. Check out the documentation for more details.)'
  msg: 'Status code was 403 and not [200]: HTTP Error 403: rate limit exceeded
```

If this error is happening you can work around this by pinning the Node Exporter version, which in turn will disable this check. This is done by setting the version in your Ansible environment config file [`vars.yml`](environment_configure.md#environment-config-varsyml) with the `node_exporter_version` variable. Here is an example to pin the version to `1.6.1`:

```sh
node_exporter_version: "1.6.1"
```

## Cloud Native Hybrid

In this section are troubleshooting steps for some common Cloud Native Hybrid environment issues.

For these setups, it's worth noting that they have quite a few moving parts, all of which could cause a failure. For example, Ansible doesn't configure the Kubernetes components directly, instead deploying the [Helm Charts](https://docs.gitlab.com/charts/) that in turn instruct Kubernetes on what to set up. The Charts contain various checks and pre-actions that can subsequently fail internally. Additionally, some setup happens at the Cloud Provider level that can also fail internally.

With that context, some of the more common failures are listed below with troubleshooting steps.

### Environment not resolvable on URL

If, after the Charts have been deployed, the environment isn't resolving on its URL as expected you may see the following error later in the Toolkit run:

```sh
TASK [post_configure : Wait for GitLab to be available] *********************************************************************************************************************************
fatal: [localhost]: FAILED! => changed=false
  attempts: 20
  cache_control: no-cache
  connection: close
  content_length: '107'
  content_type: text/html
  elapsed: 0
  msg: 'Status code was 503 and not [200]: HTTP Error 503: Service Unavailable'
```

This error is due to the Toolkit doing a sanity check to see if the setup has been successful after deploying the Helm Charts. When this error is thrown, it means that the deployment failed to complete for some reason.

Some common reasons for this may be:

- Double check that `cloud_native_hybrid_environment` and `kubeconfig_setup` are enabled to instruct the Toolkit to deploy the Charts
- AWS EKS has failed to configure the AWS Load Balancer (which it manages directly) due to not enough Elastic IPs being given via the [`aws_allocation_ids` setting](environment_advanced_hybrid.md#amazon-web-services-aws-1) - There should be one for every Subnet.
- Webservice / Sidekiq pods have failed to deploy due to one of their pre-actions or checks failing. [See the below Webservice / Sidekiq Pods not deploying section for more info](#webservice-or-sidekiq-pods-not-deploying).

### Webservice or Sidekiq Pods not deploying

There may be times when the Webservice / Sidekiq pods may not deploy on the target Kubernetes cluster even though the Toolkit has completed "successfully". While Ansible has been successful in giving the _instruction_ via the Helm Charts to deploy said pods, something such as any pre-actions or additional checks that happen in Kubernetes have failed to complete.

The pod's pre-actions or additional checks, done via [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/), act as a sanity check for the whole environment and if anything is wrong they will fail to deploy. These include running checks such as if the backends can be connected to or performing configuration. When this is the case, you may see the `Init:CrashLoopBackOff` error being thrown in Kubernetes when you run commands such as `kubectl get pods`.

Typically, this is due to a misconfiguration, specifically that the pods have failed to connect to the backends. To debug further, the following steps are recommended:

- Double check that the [configuration](environment_advanced_hybrid.md#4-configuring-the-helm-charts-deployment-with-ansible) is correct. Some examples:
  - If using any external services ([RDS](environment_advanced_services.md#configuring-with-ansible-1) / [ElastiCache](https://gitlab.com/gitlab-org/gitlab-environment-toolkit/-/blob/main/docs/environment_advanced_services.md#configuring-with-ansible-2) / [Internal LB](environment_advanced_services.md#configuring-with-ansible)) that the config for each has been added for the environment to use them.
- [Debug the Init Containers](https://kubernetes.io/docs/tasks/debug/debug-application/debug-init-containers/). In particular checking the logs of each Init Container may prove to be very useful as errors thrown by these containers aren't typically surfaced. An example of how this can be done as follows:
  - Get the name of any `webservice` pods - `kubectl get pods -l app=webservice`
  - Using that name, retrieve the list of its Init Container names - `kubectl get pod <WEBSERVICE_POD_NAME> -o jsonpath={.spec.initContainers[*].name}`
  - Look through the logs of each container for any errors - `kubectl logs <WEBSERVICE_POD_NAME> -c <INIT_CONTAINER_NAME>`

If the issue is still not found after the above steps, [further debugging guidance can be found in the Charts documentation](https://docs.gitlab.com/charts/troubleshooting/index.html#application-containers-constantly-initializin).

### `Could not match supplied host pattern, ignoring: gitlab_*_node_pool` Warning

Depending on the Toolkit version you may see the following warning being thrown by Ansible at the beginning of its run:

```sh
[WARNING]: Could not match supplied host pattern, ignoring: gitlab_*_node_pool
```

[This warning is due to an Ansible quirk](https://github.com/ansible/ansible/issues/40030) and can be ignored.

For some background, GKE / EKS will set up VMs to be the Nodes in the Kubernetes cluster. These VMs show up in normal lists and can appear in Ansible Inventories as a result. Ansible can't configure these nodes directly that are instead managed by GKE / EKS, which Ansible configures later via Helm. As such, depending on cloud provider, Ansible is configured to ignore these machines directly and this can sometimes result in the above warning.

### Data missing in environment after successful deploy

After deployment if there appears to be data missing, such as missing Users, this is likely due to [Database Migrations](https://docs.gitlab.com/charts/charts/gitlab/migrations/) not completing successfully.

In the Charts this is done via a specific Job named `migrations`. If it's failing it's likely due to it not being able to access the database correctly.

[The debugging steps in this section of the Chart's documentation](https://docs.gitlab.com/charts/troubleshooting/#application-containers-constantly-initializing) can be followed to debug further.

### AWS EKS

#### Load Balancer not deploying due to Elastic IP and Subnet counts mismatch

Due to limitations around [AWS EKS networking](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html) a cluster requires at least two subnets and each of those subnets requires their own Elastic IP when deploying a load balancer.

As such, when deploying the Charts if you've not provided a number of Elastic Allocation IDs (via `aws_allocation_ids`) that match the number of subnets **exactly** the NGinx load balancer controller will fail to deploy and GitLab will not be accessible.

This can be fixed by adjusting the number of allocation IDs and redeploying the GitLab Helm chart.

#### Cluster Autoscaler not scaling down nodes due to pod blocks

At times when using Cluster Autoscaler with AWS EKS, you may see it failing to scale down nodes.

When this is happening this is likely due to some EKS Addons deploying pods that are preventing eviction, specifically [CoreDNS and EBS CSI](https://github.com/aws/containers-roadmap/issues/1679) that both use local storage.

This is unfortunately a limitation on AWS's side and, at this time, isn't directly addressable on the service.

As a workaround however you can directly mark the offending pods as evictable with the following commands:

```sh
kubectl annotate pod -n kube-system -l eks.amazonaws.com/component=coredns "cluster-autoscaler.kubernetes.io/safe-to-evict=true"
kubectl annotate pod -n kube-system -l app.kubernetes.io/component=ebs-csi-controller "cluster-autoscaler.kubernetes.io/safe-to-evict=true"
```

After running the above commands you should see Autoscaler correctly scaling down nodes soon after.

#### Pods not deploying due to Cluster Autoscaler and EBS Persistent Volume zone mismatch

[Due to a limitation with AWS EKS and Cluster Autoscaler](https://github.com/kubernetes/autoscaler/issues/4772), deployments across multiple availability zones may sometimes result in a pod deployment clash if it's attached to an EBS backed Persistent Volume (PV).

In AWS EKS, EBS backed Persistent Volumes are deployed in a specific zone. Due to this if the future nodes available for the pod are not in the specific zone given the pod will fail to deploy.

It's worth noting the risk of this is low as Cluster Autoscaler itself shouldn't remove a node when this pod is deployed, but it can occur in other situations such as a manual Node Pool upgrade.

When this occurs the easiest solution is to [scale up the node pool manually](https://docs.aws.amazon.com/eks/latest/userguide/update-managed-node-group.html#mng-edit) to the same number as zones (subnets) and then back down again. The pod will deploy on the new node in the correct zone in this scenario and then Cluster Autoscaler will correctly evict and remove the others.

Another solution suggested is to deploy [Karpenter](https://karpenter.sh/) manually instead of Cluster Autoscaler as [it has more permissions to handle this solution directly](https://karpenter.sh/preview/concepts/scheduling/#persistent-volume-topology).

#### Unable to adjust Node Pool sizes due to Minimum / Desired Size limitations after deployment

[Due to limitations with AWS EKS](https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1568) there are times when attempting to adjust Node Pool sizes may fail due to limitations with Desired Size. Specifically if the adjustment has the Minimum Size higher than the current Desired Size it will fail as follows:

```tf
Error: error updating EKS Node Group (<REDACTED>:gitlab_supporting_pool_20220721011642956500000011) config: InvalidParameterException: Minimum capacity 3 can't be greater than desired size 2
```

As Desired Size is likely to be adjusted outside of Terraform, either manually or via autoscaling, there's no solution that can be done automatically to address this.

As such, if this issue is occurring you would need to first [adjust the Desired Size manually](https://docs.aws.amazon.com/eks/latest/userguide/update-managed-node-group.html#mng-edit) to be equal to or greater than the target Minimum Size and then run Terraform again.

## GitLab

### `422` Error on Login due to Redis misconfiguration

If you are seeing a 422 error when trying to log into the deployed GitLab environment. This is a general HTTP error code and can mean many things but one potential reason for this is Redis setup misconfiguration.

In particular, this can happen when you have configured a separated Redis setup, as recommended for the [10k Reference Architecture](https://docs.gitlab.com/ee/administration/reference_architectures/10k_users.html) and up, but not set up both the Redis Persistent and Cache clusters accordingly, i.e. only one of these have been set. The Toolkit requires either a combined single Redis cluster or both Redis Persistent and Cache clusters to be configured. Anything other that this may result in this error.

If this issue is occurring, switch to either a combined Redis or separated Redis clusters as recommended and go through set up again. Note that after setup you may also need to clear browser caches to clear out the old issue on clients.

## Other

### macOS: Python package install failure `fatal error: 'openssl/opensslv.h' file not found`

For macOS users, installation of Python packages via `pip3 install` may fail with an error:

```plaintext
fatal error: 'openssl/opensslv.h' file not found
```

You may first need to set up compiler flags to point to OpenSSL:

```shell
brew install openssl@1.1 rust
export LDFLAGS="-L$(brew --prefix openssl@1.1)/lib"
export CFLAGS="-I$(brew --prefix openssl@1.1)/include"
```

For more details, see:

1. [Documentation on installing the cryptography Python package](https://cryptography.io/en/latest/installation/#building-cryptography-on-macos)
1. [Discussion in GitHub issue](https://github.com/pyca/cryptography/issues/3489#issuecomment-318070912)

### Postgres' logs are missing (Omnibus HA)

Postgres processes in Omnibus when configured are run under Patroni processes, which manages Postgres replication and failover for HA.

As a result Postgres logs are typically found under `/var/log/gitlab/patroni` and not `/var/log/gitlab/postgres`.

### HAProxy / OpenSearch logs are missing

HAProxy / OpenSearch are run as Docker Containers. You can view their logs via the standard [Docker command](https://docs.docker.com/engine/reference/commandline/logs/).
