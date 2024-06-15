# Advanced: SSL

- [GitLab Environment Toolkit - Quick Start Guide](environment_quick_start_guide.md)
- [GitLab Environment Toolkit - Preparing the environment](environment_prep.md)
- [GitLab Environment Toolkit - Provisioning the environment with Terraform](environment_provision.md)
- [GitLab Environment Toolkit - Configuring the environment with Ansible](environment_configure.md)
- [GitLab Environment Toolkit - Advanced - Custom Config / Tasks / Files, Data Disks, Advanced Search, Container Registry and more](environment_advanced.md)
- [GitLab Environment Toolkit - Advanced - Cloud Native Hybrid](environment_advanced_hybrid.md)
- [GitLab Environment Toolkit - Advanced - Component Cloud Services / Custom (Load Balancers, PostgreSQL, Redis)](environment_advanced_services.md)
- [**GitLab Environment Toolkit - Advanced - SSL**](environment_advanced_ssl.md)
- [GitLab Environment Toolkit - Advanced - Network Setup](environment_advanced_network.md)
- [GitLab Environment Toolkit - Advanced - Monitoring](environment_advanced_monitoring.md)
- [GitLab Environment Toolkit - Upgrades (Toolkit, Environment)](environment_upgrades.md)
- [GitLab Environment Toolkit - Considerations After Deployment - Backups, Security](environment_post_considerations.md)
- [GitLab Environment Toolkit - Geo](geo/README.md)
  - [GitLab Environment Toolkit - Geo - Provisioning the environment with Terraform](geo/geo_provision.md)
  - [GitLab Environment Toolkit - Geo - Configuring the environment with Ansible](geo/geo_configure.md)
  - [GitLab Environment Toolkit - Geo - Advanced](geo/geo_advanced.md)
- [GitLab Environment Toolkit - Troubleshooting](environment_troubleshooting.md)

The Toolkit aims to enable you to configure SSL encryption for your GitLab environment.

Encryption is an complex area that can become complex with various ways to configure depending on your requirements. With GitLab there are two general areas of Encryption the Toolkit seeks to enable you to configure - External and Internal SSL:

- External SSL - Where external connections to the main URL are encrypted. Also called External SSL Termination.
- Internal SSL - Where internal connections between GitLab components are encrypted.

Except for the Let's Encrypt option for External SSL termination - User provided certificates are required to enable encryption with the recommendation that these are signed certificates.

On this page we'll detail how you can configure each type of encryption with the Toolkit. **It's worth noting this guide is supplementary to the rest of the docs, and it will assume this throughout. It also assumes a working level knowledge of SSL in general.**

:information_source:&nbsp; Recommendations about what specific encryption strategy to use is not within the scope of this guide. You should review GitLab independently to determine the strategy as per your security requirements.

[[_TOC_]]

## External SSL

With [External SSL termination](https://docs.gitlab.com/ee/administration/load_balancer.html#load-balancers-terminate-ssl-without-backend-ssl), the external entry point for the environment will encrypt connections to and from all users.

The Toolkit supports two sources of certificates for External SSL termination: **User provided** or automated via [**Let's Encrypt**](https://letsencrypt.org/). Below are the details on how to set this up with either source.

### User provided certificates

For users who already have certificates for their intended GitLab environment the Toolkit can use these as given to set up External SSL termination.

At a high level the Toolkit will simply take the certificate and key files and use them to configure HAProxy (Standard) or NGINX Ingress (Cloud Native Hybrid) respectively to use them. Below are the steps to configure this.

#### Setup user provided certificates for Toolkit use

The first step is to provide the certificates themselves for the Toolkit to use. By default, the certificates should meet the following conditions:

- Certificate and key files are named in the formats `<hostname>.pem` and `<hostname>.key` respectively
- Certificates must contain [Subject Alternative Name(s) (SAN)](https://support.dnsimple.com/articles/what-is-ssl-san) as Common Name (CN) use only is deprecated.
  - SAN entries should cover any additional hostnames that are expected to be used with the environment. This includes additional features such as the [Container Registry](environment_advanced.md#container-registry-gcp-aws) (`registry.<external_host>`).
- Certificate and key files are located in the `ansible/environments/<env_name>/files/certificates` folder
- Certificate file contains the [full chain](https://www.digicert.com/kb/ssl-support/pem-ssl-creation.htm).

You can optionally store your SSL files in a different location as well as use different names if desired with additional configuration. This will be detailed further in the next section.

Once the SSL certificate and key files are in the desired location you can proceed to the next step.

#### Configure Variables for user provided certificates

After the SSL certificate and key are in place you then need to configure the Toolkit to use them. This is done as normal in Ansible via the Inventory Variables.

There are two main variables to set in the Inventory Variables [`vars.yml`](environment_configure.md#environment-config-varsyml) file that configures the Toolkit to use External SSL termination with user provided certificates:

- `external_url` - Set [previously](environment_configure.md) this is the main URL the environment is expected to be reached on. For External SSL termination this should be changed to a URL that starts with `https://`.
- `external_ssl_source` - Sets what source is being used for the External SSL certificates. In this setup it should be set to `user`.

When the certificates are configured as the Toolkit expects then, as detailed in the previous section, an example of how the config would look is as follows:

```yml
all:
  vars:
    [...]
    external_url: "https://<hostname>"
    external_ssl_source: "user"
```

If the files are stored in another location or have a different name, the following variables are available to customize where the Toolkit will look for the files:

- `external_ssl_files_host_certificate_file` - Set to the full file path of the certificate on the host machine running Ansible. Note that with this setting you can also pass in a path to a `.crt` file if desired as the contents are the same as a `.pem` file.
- `external_ssl_files_host_key_file` - Set to the full file path of the key on the host machine running Ansible.

Once the config is in place you're ready to [configure the environment](#configure-the-environment).

### Let's Encrypt generated certificates

[Let's Encrypt](https://letsencrypt.org/) allows users to generate signed SSL certificates for free. The Toolkit allows for these generated certificates to be used for External SSL termination instead of user provided ones.

At a high level the Toolkit will either directly use [`acme.sh`](https://github.com/acmesh-official/acme.sh) to generate the files then configure HAProxy (Linux Package (Omnibus)) or configure Helm to use its `certmanager` and configure NGINX Ingress (Cloud Native Hybrid) instead. Below are the steps to configure this.

#### Configure Variables

As the certificates are generated automatically via Let's Encrypt the Toolkit only needs to be configured to use them.

There are three main variables to set in the Inventory Variables [`vars.yml`](environment_configure.md#environment-config-varsyml) file that configures the Toolkit to use External SSL termination with Let's Encrypt certificate:

- `external_url` - Set [previously](environment_configure.md) this is the main URL the environment is expected to be reached on. For External SSL termination this should be changed to a URL that starts with `https://`.
- `external_ssl_source` - Sets what source is being used for the External SSL certificates. In this setup it should be set to `letsencrypt`.
- `external_ssl_letsencrypt_issuer_email` - Email to use with Let's Encrypt for renewal and recovery of certificates. This should be set to an email of an administrator of the GitLab environment.

An example of how the config would look is as follows:

```yml
all:
  vars:
    [...]
    external_url: "https://<hostname>"
    external_ssl_source: "letsencrypt"
    external_ssl_letsencrypt_issuer_email: "admin@example.com"
```

Once the config is in place you're ready to [configure the environment](#configure-the-environment).

### Configure the environment

With the files and config in place all that's left is to update the environment. This can be done [the same as a normal environment update](environment_configure.md#4-configure).

As an alternative you can also just reconfigure the specific nodes, depending on the type of environment, that will avoid doing a version update of GitLab as follows:

- Standard - `ansible-playbook -i environments/10k/inventory playbooks/haproxy.yml playbooks/gitaly.yml playbooks/gitlab_rails.yml -t reconfigure`
- Cloud Native Hybrid - `ansible-playbook -i environments/10k/inventory playbooks/gitaly.yml playbooks/gitlab_charts.yml -t reconfigure`

## Internal SSL

Unlike External SSL, Internal SSL is typically more complex. This is due to both servers and clients needing to be configured as well as each GitLab component, some being third party, each having their own implementations and options.

Due to this, how the Toolkit approaches Internal SSL varies depending on the component, and it's implementation as follows:

- [Custom Files](environment_advanced.md#custom-files) / [Secrets](environment_advanced_hybrid.md#custom-kubernetes-secrets-via-custom-tasks) and [Custom Config](environment_advanced.md#custom-config) (Cloud Native Hybrid) - Where setup is best handled with full control via Custom Files and Custom Config to ensure the encryption meets your requirements. This applies to most components.
- Direct - Where the Toolkit handles setup directly for components that have one approach to encryption and / or if it needs to manage additional configuration in areas such as network setup. At the time of writing this only applies to Gitaly / Gitaly Cluster.

In this section we'll go through the process for each.

:information_source:&nbsp; It's also worth noting that the Cloud Providers have default encryption options that may be suitable to your needs but as stated above this should be reviewed independently to verify. Refer to the [Cloud Provider default encryption](#cloud-provider-default-encryption) section below for more details.

### Preparing Certificates

The first step is to prepare your certificates via whatever your chosen method is.

When preparing the certificates the following conditions should be met:

- Certificates are in the `.pem` format and Keys in the `.pem` or `.key` format.
- Certificates must contain a Subject Alternative Name (SAN) as Common Name (CN) use only is deprecated.
- The files will be copied to each component node group. As such the SAN entries should either match each node group machine's specific hostname or be an appropriate wildcard.
  - :information_source:&nbsp; The Toolkit by default uses IPs for internal connections. [However, this can be switched to use internal hostnames as discovered by Ansible](environment_advanced_network.md#configuring-internal-connection-type-ips-and-hostnames) which is generally preferred for Internal SSL.
  - :information_source:&nbsp; Terraform output contains the Hostnames / IPs for you to configure your certificates with.
- For GitLab components to verify each certificate you will need either the CA file for your certificates or to upload the certificate itself to client components. Further guidance on this is given later.

Once the certificates are prepared you should place them in a location that's accessible to Ansible. We recommend placing these in a folder for each component under the `ansible/environments/<env_name>/files/certificates` folder, e.g. for Postgres that would be `ansible/environments/<env_name>/files/certificates/postgres`.

Once you have the certificates ready proceed to the relevant sections below to configure.

### Configuring Internal SSL via Custom Files and Custom Config

For most components it's best to configure Internal SSL for each via [Custom Files](environment_advanced.md#custom-files) (or [Custom Secrets](environment_advanced_hybrid.md#custom-kubernetes-secrets-via-custom-tasks) for Cloud Native Hybrids) and [Custom Config](environment_advanced.md#custom-config) to allow for full control over the various options each can have depending on your requirements. This applies to all components in the GitLab setup except for those specifically noted in the below [Configuring Internal SSL directly for select components](#configuring-internal-ssl-directly-for-select-components) section.

Some of the most common components to set up encryption for can be found in the below non-exhaustive table:

|  | Client(s) | Documentation |
|---|---|---|
| Postgres | PgBouncer or Rails / Sidekiq / Praefect | [Link](https://docs.gitlab.com/omnibus/settings/database.html#configuring-ssl) |
| Patroni | Patroni | [Link](https://docs.gitlab.com/ee/administration/postgresql/replication_and_failover.html#enable-tls-support-for-the-patroni-api) |
| PgBouncer | Rails / Sidekiq / Praefect | N/A |
| Redis | Rails, Sidekiq | [Link](https://docs.gitlab.com/omnibus/settings/redis.html#ssl-certificates) |
| Consul | Patroni, Prometheus* | Coming Soon |

For each component the general steps to configure Internal SSL encryption is as follows, depending on your setup:

- **For Omnibus Components** - Upload your certificates to the component node groups via [Custom Files](environment_advanced.md#custom-files), including any CA files to client nodes.
  - Certificates and Keys should be uploaded to `/etc/gitlab/ssl` and CA files to `/etc/gitlab/trusted-certs` in mode `644` on every client. The Toolkit will create these folders as a convenience.
  - Set the desired config for each component and client node groups via [Custom Config](environment_advanced.md#omnibus).
- **For Cloud Native Hybrid components** - Upload your certificates as [Custom Secrets](environment_advanced_hybrid.md#custom-kubernetes-secrets-via-custom-tasks).
  - Typically, in this setup all that will be required is to upload [CA files](https://docs.gitlab.com/charts/charts/globals.html#custom-certificate-authorities) as [Kubernetes secrets](https://kubernetes.io/docs/concepts/configuration/secret/). These can be with any name, but then these must match in the config. You can also choose to do this directly via `kubectl` if desired after initial deployment.
  - Set the desired [config](https://docs.gitlab.com/charts/charts/globals.html#custom-certificate-authorities
) via [Custom Config](environment_advanced.md#helm).
- Run Ansible as normal to configure.

### Configuring Internal SSL directly for select components

As mentioned above, the Toolkit needs to handle encryption directly for select components that require additional setup such as networking. At the time of writing this applies only to Gitaly / Gitaly Cluster, but this may expand in the future.

Refer to the relevant section below on how to configure encryption directly for the component.

#### Gitaly / Gitaly Cluster

The Toolkit handles Internal SSL setup for Gitaly / Gitaly Cluster as it needs to manage the networking between the component and its clients / load balancer.

Certificates still need to be prepared but once ready follow the below to configure.

##### Configure Variables

Configuring Internal SSL for Gitaly / Gitaly Cluster is similar to other components in the Toolkit. Ansible will copy over the files and then configure them accordingly.

The variables that need to be set in the Inventory Variables [`vars.yml`](environment_configure.md#environment-config-varsyml) file if you are setting up just Gitaly (Sharded) or Gitaly Cluster. For both you set up Gitaly certificates and for the latter you also set up Praefect certificates as follows:

Gitaly (for both Sharded or Cluster):

- `gitaly_ssl_cert_file` - Path to the Gitaly Certificate file to upload. Default is `''`.
- `gitaly_ssl_key_file` - Path to the Gitaly Key file to upload. Default is `''`.
- `gitaly_ssl_ca_file` - Path to the Gitaly CA file to upload. Default is `''`.
- `gitaly_ssl_port` - The port Gitaly will use for SSL connections. This shouldn't need to be changed in most circumstances. Default is `9999`.

Praefect (for Cluster):

- `praefect_ssl_cert_file` - Path to the Praefect Certificate file to upload. Default is `''`.
- `praefect_ssl_key_file` - Path to the Praefect Key file to upload. Default is `''`.
- `praefect_ssl_ca_file` - Path to the Praefect CA file to upload. Default is `''`.
- `praefect_ssl_port` - The port Praefect will use for SSL connections. This shouldn't need to be changed in most circumstances. Default is `3035`.

In addition to the above there are some other settings you may need to set depending on your setup as follows:

###### ELB Port Config (AWS)

If the environment is on AWS and [using ELB (NLB) for its internal load balancer](environment_advanced_services.md#internal-nlb) one additional piece of configuration is required when switching to use Internal SSL for Gitaly Cluster to set the correct port for load balancing as this is managed by Terraform.

In this scenario you must set the `elb_internal_praefect_port` variable to the same port being used by Praefect for SSL connections in the Terraform [Environment config file](environment_provision.md#configure-module-settings-environmenttf). This would be `3035` in most cases and would look as follows:

```tf
module "gitlab_ref_arch_aws" {
  source = "../../modules/gitlab_ref_arch_aws"

  [...]

  elb_internal_create = true
  elb_internal_praefect_port = 3035
}
```

###### Cloud Native Hybrid Custom CA config

Due to the way Custom Config on Cloud Native Hybrids works, if you're setting the `global.certificates.customCAs` variable to pass in your CA files this will need to be adjusted slightly for Gitaly / Gitaly Cluster due to the nature of config overriding.

In this scenario you should add either `gitaly-ca` (Sharded) or `praefect-ca` (Cluster) to your `customCAs` list so that the correct CA file for either of those components is picked up along with your own.

For example if you had a Postgres CA set in your config named `postgres-ca` on a Gitaly Cluster environment you would only need to adjust it as follows:

```yml
global:
  certificates:
    customCAs:
      - secret: postgres-ca
      - secret: praefect-ca
```

### Cloud Provider default encryption

Cloud Providers do also offer various encryption options, by default in some cases:

- Encryption at Rest - The Toolkit was always looks to enable any standard Encryption at Rest that's available from the Cloud Providers. Although as stated above it's recommend that you review this independently to ensure it meets your requirements.
- Encryption in Transit - The Cloud Providers offer Encryption in Transit by default. Details for each can be found below:
  - [AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/data-protection.html#encryption-transit)
  - [GCP](https://cloud.google.com/docs/security/encryption-in-transit#encryption-all-regions)
  - [Azure](https://docs.microsoft.com/en-us/azure/security/fundamentals/encryption-overview#data-link-layer-encryption-in-azure)

You may consider this enough for your needs, but this should be reviewed independently.
