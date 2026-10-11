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
- [Ubuntu Resolute Stemcells](#ubuntu-resolute-stemcells)
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
| `resolute` | **Experimental.** Deploy on the ubuntu-resolute stemcell instead of ubuntu-noble. See [Ubuntu Resolute Stemcells](#ubuntu-resolute-stemcells) |

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
| `prometheus` | Enable Prometheus metrics endpoint, including under `ocfp` |
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

   - Set `github_allowed_orgs` to a list of GitHub organizations to admit
     every member of those organizations

   - Set `github_allowed_teams` to a list of GitHub `org:team` slugs to admit
     only the members of those teams — for example
     `[ my-org:platform-team ]`. Use the slugs GitHub generates, not the
     display names

   - Either parameter alone is sufficient, and both may be set together;
     setting neither is an error. Local basic authentication keeps working
     alongside GitHub OAuth

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

The metrics port defaults to 9391, and you can change it with the `prometheus_metrics_port` parameter. With the `full` feature, the kit adds an HAProxy listener on that port that forwards to the web nodes. The `prometheus` feature also works with the `ocfp` feature. Under `ocfp` there is no HAProxy, so there is no listener to add, and Prometheus scrapes the web VMs directly on the metrics port.

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

## Ubuntu Resolute Stemcells

The kit deploys Concourse on ubuntu-noble stemcells unless we ask for something else. Adding the `resolute` feature moves every instance group onto ubuntu-resolute.

```yaml
kit:
  features:
  - full
  - resolute

params:
  stemcell_version: "0.184"
```

The feature is experimental, so we recommend trying it on a canary Concourse before we point anything real at it. It sets the stemcell `os` to `ubuntu-resolute`, and `stemcell_version` still selects the version, which defaults to `latest`. We pin it to a resolute version such as `"0.184"`, so that the environment stays on a known resolute build when a newer stemcell is uploaded. The feature works the same with or without `ocfp`. Because the feature owns the stemcell os, an environment that sets `params.stemcell_os` to anything else is refused. An environment that sets `params.stemcell_os` to `ubuntu-resolute` without the feature is refused as well.

Before the first deploy we need to do two things on the director.

- Upload the resolute stemcell to the director that deploys Concourse, since both the compilation VMs and the instances need it.

- Make sure the director's runtime config carries bosh-dns 1.39.31 or later. Earlier bosh-dns releases do not run on resolute.

Resolute ships without runit, so the `chpst` command is missing. A job whose start script drops privileges with `chpst` hangs on resolute, and we have to switch it to `setpriv` or bpm before its release can run there. The Concourse worker uses start-stop-daemon and the other jobs run under bpm, so the releases this kit deploys are not affected, but we should check any job we add before we move it to resolute.

The bpm releases 1.4.20 and 1.4.22 fail to compile on resolute, because their bundled tini package needs an older CMake than resolute ships. The feature therefore pins bpm 1.4.41 in every deployment type that carries the bpm release, and noble deployments keep 1.4.20.

The haproxy releases before 16.13.0 bundle a socat that fails to compile on resolute. The default pin is haproxy 14.1.1, so a `full` deployment with the `resolute` feature switches to haproxy 16.13.0 with HAProxy 3.2.25 and leaves the pin alone for every other deployment. The kit only sets `ha_proxy.tcp` on that job, and the new release accepts it unchanged. The switch does not apply to `ocfp`, `small-footprint`, or `no-haproxy` deployments, because none of them deploys the haproxy release.

The postgres-release 54.0.0 and later compile postgres-16 with no `bin` directory on resolute, so the feature moves a deployment that runs the postgres job from release 52 to 57.0.0, which compiles there, and it sets `databases.version` to 16, the major that release 52 already runs by default, so the existing data directory stays on PostgreSQL 16 and no pg_upgrade runs during the stemcell change.

The locker release 0.2.1 calls `chpst`, so every deployment that carries the locker job needs `resolute_locker_release_version`, `resolute_locker_release_url`, and `resolute_locker_release_sha1` set to a locker release newer than 0.2.1, and the feature refuses to render until we do.

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
  github_allowed_orgs:
    - my-github-org
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