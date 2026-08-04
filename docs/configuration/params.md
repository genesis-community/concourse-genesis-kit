# Concourse Genesis Kit Parameters Reference

This document provides a comprehensive reference for all parameters available in the Concourse Genesis Kit v3.13.0.

- [Base Parameters](#base-parameters)
- [Sizing and Deployment Parameters](#sizing-and-deployment-parameters)
- [Network and URL Parameters](#network-and-url-parameters)
- [Authentication Parameters](#authentication-parameters)
- [External Database Parameters](#external-database-parameters)
- [HTTP(S) Proxy Parameters](#https-proxy-parameters)
- [Vault Integration Parameters](#vault-integration-parameters)
- [TLS Certificate Parameters](#tls-certificate-parameters)
- [Prometheus Parameters](#prometheus-parameters)
- [OCFP-Specific Parameters](#ocfp-specific-parameters)
- [Worker-specific Parameters](#worker-specific-parameters)
- [Container Runtime Parameters](#container-runtime-parameters)

## Base Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `volume_driver` | string | `detect` | The garden/runc volume driver to use. |
| `max_builds_to_retain` | integer | none | If set, jobs will only keep up to their last n logs, with older ones being reaped from the database. |
| `container_runtime` | string | `containerd` | The container backend to use on worker nodes. Other options: `guardian` or `houdini`. |
| `stemcell_os` | string | `ubuntu-bionic` | The operating system you want to deploy Concourse on. |
| `stemcell_version` | string | `latest` | The version of the stemcell to deploy. |

## Sizing and Deployment Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `concourse_network` | string | `concourse` | The name of the network you wish to use as specified in your cloud config. |
| `concourse_vm_type` | string | `small` | The name of the vm type to be used for all the non-worker vms. |
| `worker_vm_type` | string | `concourse-worker` | The name of the vm type to be used by workers. |
| `haproxy_vm_type` | string | value of `concourse_vm_type` | The name of the vm type to be used for the haproxy load balancer. |
| `num_web_nodes` | integer | 1 | How many web nodes to deploy. Can be scaled up to 5. |
| `web_vm_type` | string | value of `concourse_vm_type` | The name of the vm type to be used for the web nodes. |
| `db_vm_type` | string | value of `concourse_vm_type` | The name of the vm type to be used for the database node. |
| `concourse_disk_type` | string | `concourse` | What type of persistent disk to deploy for the database node. |
| `availability_zones` | array | `[z1, z2, z3]` | What BOSH HA availability zones to deploy Concourse across. |
| `workers` | integer | 3 | How many workers to deploy. |

## Network and URL Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `external_domain` | string | none | The fully-qualified domain name or IP address for Concourse. **Required** for full deployments. |
| `external_url` | string | constructed from `external_domain` | The full HTTP(S) URL for this Concourse. |
| `web_vm_extension` | string | `concourse-loadbalancer` | The name of the vm-extension for attaching web nodes to a loadbalancer (with `dynamic-web-ip` feature). |

## Authentication Parameters

### Basic Authentication

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `main_user` | string | none | Username of the default administrator account, which will belong to the `main` team. |

### GitHub OAuth

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `authz_allowed_orgs` | string | none | GitHub organization whose members may log in. Required unless `authz_allowed_teams` is set. |
| `authz_allowed_teams` | array | none | GitHub `org:team` slugs whose members may log in, e.g. `[ my-org:platform-team ]`. Required unless `authz_allowed_orgs` is set. |
| `github_host` | string | none | Domain of the Github Enterprise installation for enterprise GitHub OAuth. |

### CF OAuth

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `cf_api_uri` | string | none | The Cloud Foundry API URL. **Required** for CF OAuth. |
| `cf_spaces` | array | none | A list of Cloud Foundry spaces in the form `ORG:SPACE`. **Required** for CF OAuth. |
| `cf_ca_cert_vault_path` | string | none | The path in the Vault to the Cloud Foundry CA certificate. **Required** for CF OAuth. |

### Okta/SAML Authentication

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| Note: Okta parameters are stored in Vault under specified paths | | | |

## External Database Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `external_db_host` | string | none | The hostname of the database to connect to. **Required** for external DB. |
| `external_db_port` | integer | 5432 | The port that the database is listening on. |
| `external_db_name` | string | `atc` | The name of the database to connect to. |
| `external_db_user` | string | `atc` | The username used to connect to the database. |
| `external_db_sslmode` | string | `verify-ca` | The sslmode parameter to connect to the database with. |
| `external_db_ca` | string | none | The CA certificate to validate the DB TLS connection against (with `external-db-ca` feature). |

## HTTP(S) Proxy Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `http_proxy` | string | none | URL of an HTTP proxy to use for outbound HTTP (non-TLS) communication. |
| `https_proxy` | string | none | URL of an HTTP proxy to use for outbound HTTPS (TLS) communication. |
| `no_proxy` | array | none | A list of IPs, FQDNs, partial domains, etc. to skip the proxy. |

## Vault Integration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `vault_url` | string | none | The URL of the Vault API to contact. |
| `vault_path_prefix` | string | `/concourse` | The path prefix to look for paths under in Vault. |
| `vault_insecure_skip_verify` | boolean | `false` | Whether to skip validation of the cert presented by the Vault API. |
| `vault_token` | string | none | The token to present as authentication to the Vault API. |
| `vault_approle_role_id` | string | none | The role ID for the AppRole used to access Vault (with `vault-approle` feature). |
| `vault_approle_secret_id` | string | none | The secret ID of the AppRole (with `vault-approle` feature). |

## TLS Certificate Parameters

These parameters are specific to the `provided-cert` feature.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| Note: Certificate data is stored in Vault | | | |

## Prometheus Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prometheus_metrics_port` | integer | 9391 | The port to listen for metrics on when using the Prometheus addon. |

## OCFP-Specific Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ocfp_env_scale` | string | `dev` | Scale of the OCFP environment (`dev` or `prod`). |
| Note: Most OCFP parameters are read from Vault | | | |

## Worker-specific Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tsa_host_env` | string | none | The name of the Genesis environment to register this satellite Concourse to. **Required** for workers-only deployments. |
| `tags` | array | environment name | The list of tags to apply to the workers in this satellite Concourse. |

## Feature Flag Compatibility

This table shows which parameters are relevant based on which feature flags are enabled:

| Parameter | full | small-footprint | workers | external-db | vault | ocfp |
|-----------|:----:|:---------------:|:-------:|:-----------:|:-----:|:----:|
| `external_domain` | ✓ | ✓ | | | | ✓ |
| `tsa_host_env` | | | ✓ | | | |
| `external_db_host` | | | | ✓ | | ✓ |
| `vault_url` | | | | | ✓ | ✓ |
| `ocfp_env_scale` | | | | | | ✓ |