# Concourse Genesis Kit Feature Flags

The Concourse Genesis Kit uses feature flags to enable specific functionality in your deployment. This document provides details on all available feature flags.

## Core Feature Flags

These feature flags determine the fundamental deployment type:

| Feature Flag | Description | Notes |
|--------------|-------------|-------|
| `full` | Deploy a complete Concourse system | Includes web, database, and worker components |
| `small-footprint` | Deploy a smaller Concourse with web/DB on one VM | Reduces resource usage but limits scalability |
| `workers` | Deploy only worker nodes for a remote Concourse | Requires `tsa_host_env` parameter |

**Note**: You must choose exactly one of these core feature flags.

## Authentication Feature Flags

These feature flags determine the authentication method:

| Feature Flag | Description | Required Parameters | Vault Secret Paths |
|--------------|-------------|---------------------|-------------------|
| `github-oauth` | Enable GitHub OAuth authentication | `github_allowed_orgs` and/or `github_allowed_teams` | `secret/$env/concourse/oauth` |
| `github-enterprise-oauth` | Enable GitHub Enterprise OAuth authentication | `github_host` + GitHub OAuth params | `secret/$env/concourse/oauth` |
| `cf-oauth` | Enable Cloud Foundry UAA OAuth authentication | `cf_api_uri`, `cf_spaces`, `cf_ca_cert_vault_path` | `secret/$env/concourse/oauth` |
| `okta` | Enable SAML authentication via Okta | None | Various `secret/$env/concourse/okta:*` paths |

## TLS Feature Flags

These feature flags configure TLS for the web interface:

| Feature Flag | Description | Notes |
|--------------|-------------|-------|
| `self-signed-cert` | Generate and use a self-signed TLS certificate | Easiest option for testing |
| `provided-cert` | Use a provided TLS certificate | Uses `secret/$env/concourse/ssl/server` |
| `no-tls` | Don't use TLS locally | Not recommended for production |

**Note**: You should choose exactly one of these TLS feature flags.

## Network Feature Flags

These feature flags affect network configuration:

| Feature Flag | Description | Parameters |
|--------------|-------------|------------|
| `no-haproxy` | Deploy without using HAProxy | |
| `dynamic-web-ip` | Attach web nodes to an IaaS loadbalancer | `web_vm_extension` (defaults to `concourse-loadbalancer`) |

## Integration Feature Flags

These feature flags enable integration with external systems:

| Feature Flag | Description | Key Parameters |
|--------------|-------------|----------------|
| `vault` | Enable Vault integration for pipeline secrets | `vault_url`, `vault_path_prefix` |
| `vault-approle` | Use Vault AppRole instead of tokens | `vault_approle_role_id`, `vault_approle_secret_id` |
| `prometheus` | Enable Prometheus metrics endpoint | `prometheus_metrics_port` (defaults to 9391) |
| `prometheus-small-footprint` | Enable Prometheus for small footprint | Used with `small-footprint` |
| `shout` | Enable Shout! notification gateway | `shout_rules` |

## Database Feature Flags

These feature flags configure database options:

| Feature Flag | Description | Key Parameters |
|--------------|-------------|----------------|
| `external-db` | Use an external PostgreSQL database | `external_db_host` |
| `external-db-ca` | Provide CA cert for external database | `external_db_ca` |
| `external-db-small` | External DB for small footprint | Used with `small-footprint` |
| `maximum-builds-retention` | Limit number of build logs to retain | `max_builds_to_retain` |

## Platform Feature Flags

| Feature Flag | Description | Notes |
|--------------|-------------|-------|
| `ocfp` | Deploy as part of an OCFP architecture | Automatically includes multiple features |
| `azure` | Apply Azure-specific configuration | Mainly affects availability zones |

## Feature Flag Combinations

Some feature flags commonly work together:

1. **Standard Production Deployment**:
   ```yaml
   features:
     - full
     - self-signed-cert  # or provided-cert
     - vault
     - vault-approle
   ```

2. **Small Development Environment**:
   ```yaml
   features:
     - small-footprint
     - self-signed-cert
     - github-oauth
   ```

3. **Remote Workers**:
   ```yaml
   features:
     - workers
   ```

4. **OCFP Deployment**:
   ```yaml
   features:
     - ocfp
   ```

## Implicit Feature Flags

Some feature flags are automatically included based on other features:

| If you specify... | These are automatically included... |
|-------------------|-------------------------------------|
| `ocfp` | `full`, `no-haproxy`, `dynamic-web-ip`, `external-db`, `vault`, `vault-approle` |
| `external-db-small` | `external-db` |
| `prometheus-small-footprint` | `prometheus` |
| `vault-approle` | `vault` |
| `github-enterprise-oauth` | `github-oauth` |

## Feature Flag Conflicts

Some feature flags cannot be used together:

1. You cannot use multiple core feature flags (`full`, `small-footprint`, `workers`)
2. You cannot use multiple TLS feature flags (`self-signed-cert`, `provided-cert`, `no-tls`)
3. `vault-approle` requires `vault`
4. `external-db-ca` requires `external-db`
5. `prometheus-small-footprint` requires `small-footprint`

## Feature Documentation

For more detailed information on each feature, refer to the relevant documentation sections:

- [Authentication Methods](../authentication/)
- [Vault Integration](../integrations/vault.md)
- [External Database](../integrations/external-db.md)
- [Prometheus Integration](../integrations/prometheus.md)
- [OCFP Integration](../advanced/ocfp.md)