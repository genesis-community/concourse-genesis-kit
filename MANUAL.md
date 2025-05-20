# Concourse Genesis Kit Manual

The **Concourse Genesis Kit** deploys a Concourse CI/CD system. It supports _full_ Concourses, which contain all of the components (web, database, and workers), as well as _workers-only_ Concourses, for remote satellite sites.

This manual serves as an overview of the kit functionality with links to more detailed documentation.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Deployment Types](#deployment-types)
- [Feature Flags](#feature-flags)
- [Authentication Options](#authentication-options)
- [Integration Options](#integration-options)
- [Advanced Configuration](#advanced-configuration)
- [Available Addons](#available-addons)
- [Detailed Documentation](#detailed-documentation)
- [Example Deployments](#example-deployments)

## Quick Reference

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `external_domain` | FQDN for Concourse web UI | Required for full deployments |
| `workers` | Number of worker VMs to deploy | 3 |
| `container_runtime` | Container backend (`containerd`, `guardian`, `houdini`) | `containerd` |
| `stemcell_os` | The OS to deploy Concourse on | `ubuntu-bionic` |
| `tsa_host_env` | Target environment for worker-only deployments | Required for workers-only |

For a complete list of parameters, see the [Parameters Reference](docs/configuration/params.md).

## Deployment Types

The Concourse Genesis Kit supports three primary deployment types:

1. **Full Deployment**: All components (web UI, API, database, and workers)
   - Enable with the `full` feature flag
   - Requires `external_domain` parameter

2. **Small Footprint**: Reduced resource requirements (web/DB combined)
   - Enable with the `small-footprint` feature flag
   - Still requires `external_domain` parameter

3. **Workers-Only**: Remote workers that connect to a separate Concourse
   - Enable with the `workers` feature flag
   - Requires `tsa_host_env` parameter

For details, see the [Deployment Types Documentation](docs/configuration/deployment-types.md).

## Feature Flags

### Core Feature Flags

| Feature Flag | Description |
|--------------|-------------|
| `full` | Deploy a complete Concourse system |
| `small-footprint` | Deploy a smaller Concourse with web/DB on one VM |
| `workers` | Deploy only worker nodes for a remote Concourse |

### Authentication Feature Flags

| Feature Flag | Description |
|--------------|-------------|
| `github-oauth` | Enable GitHub OAuth authentication |
| `github-enterprise-oauth` | Enable GitHub Enterprise OAuth authentication |
| `cf-oauth` | Enable Cloud Foundry UAA OAuth authentication |
| `okta` | Enable SAML authentication via Okta |

### TLS Feature Flags

| Feature Flag | Description |
|--------------|-------------|
| `self-signed-cert` | Generate and use a self-signed TLS certificate |
| `provided-cert` | Use a provided TLS certificate |
| `no-tls` | Don't use TLS (not recommended for production) |

### Integration Feature Flags

| Feature Flag | Description |
|--------------|-------------|
| `vault` | Enable Vault integration for pipeline secrets |
| `vault-approle` | Use Vault AppRole instead of tokens |
| `prometheus` | Enable Prometheus metrics endpoint |
| `external-db` | Use an external PostgreSQL database |
| `ocfp` | Deploy as part of an OCFP architecture |

For a complete list of feature flags, see the [Features Reference](docs/configuration/features.md).

## Authentication Options

The Concourse Genesis Kit supports multiple authentication methods:

1. **Basic Authentication** (default)
   - Simple username/password for the `main` team
   - Password stored in Vault at `secret/$env/concourse/webui`

2. **GitHub OAuth**
   - Enable with `github-oauth` feature
   - Set `authz_allowed_orgs` or `github_authz` parameters

3. **CF OAuth**
   - Enable with `cf-oauth` feature
   - Set `cf_api_uri` and `cf_spaces` parameters

4. **SAML/Okta**
   - Enable with `okta` feature
   - Configure via Vault settings

For details, see the [Authentication Documentation](docs/authentication/).

## Integration Options

### Vault Integration

Enable Vault integration for pipeline secrets:

```yaml
features:
  - vault
```

For details, see the [Vault Integration Documentation](docs/integrations/vault.md).

### Prometheus Integration

Enable Prometheus metrics:

```yaml
features:
  - prometheus
```

For details, see the [Prometheus Integration Documentation](docs/integrations/prometheus.md).

### External Database

Use an external PostgreSQL database:

```yaml
features:
  - external-db
params:
  external_db_host: postgres.example.com
```

For details, see the [External Database Documentation](docs/integrations/external-db.md).

## Advanced Configuration

### Team Management

Concourse uses a team-based security model. The `main` team is configured through the deployment manifest, while other teams are managed using the `fly` CLI.

For details, see the [Team Management Documentation](docs/advanced/team-management.md).

### Container Runtimes

Configure the container runtime used by worker nodes:

```yaml
params:
  container_runtime: containerd  # Options: containerd, guardian, houdini
```

For details, see the [Container Runtime Documentation](docs/configuration/container-runtimes.md).

### OCFP Integration

Deploy Concourse as part of an OCFP architecture:

```yaml
features:
  - ocfp
```

For details, see the [OCFP Documentation](docs/advanced/ocfp.md).

## Available Addons

The Concourse Genesis Kit provides several helpful addons:

- `visit` - Opens the Concourse web UI in your browser
- `download-fly` - Downloads the matching `fly` CLI
- `login` - Authenticates your `fly` CLI
- `logout` - Logs out from Concourse
- `fly` - Runs fly commands against your Concourse
- `setup-approle` - Configures Vault AppRole for Concourse

Example usage:
```bash
genesis do my-env -- login
genesis do my-env -- fly pipelines
```

For details, see the [Addons Documentation](docs/addons/).

## Detailed Documentation

For more detailed documentation, see:

- [Parameters Reference](docs/configuration/params.md)
- [Features Reference](docs/configuration/features.md)
- [Authentication Methods](docs/authentication/)
- [Integrations](docs/integrations/)
- [IaaS-Specific Guides](docs/iaas/)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Upgrade Guide](docs/upgrade.md)

## Example Deployments

### Basic Deployment

```yaml
---
kit:
  name: concourse
  version: 3.13.0
  features:
    - full
    - self-signed-cert

params:
  env: prod
  external_domain: concourse.example.com
  workers: 3
```

### Small Footprint with GitHub Auth

```yaml
---
kit:
  name: concourse
  version: 3.13.0
  features:
    - small-footprint
    - self-signed-cert
    - github-oauth

params:
  env: dev
  external_domain: concourse-dev.example.com
  authz_allowed_orgs: my-github-org
```

### Workers-Only Deployment

```yaml
---
kit:
  name: concourse
  version: 3.13.0
  features:
    - workers

params:
  env: workers
  tsa_host_env: prod
  workers: 5
  tags: [remote, high-cpu]
```

For more examples, see the [Example Deployments](docs/examples/).