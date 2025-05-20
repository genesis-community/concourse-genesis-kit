# Concourse Genesis Kit

[![Version](https://img.shields.io/badge/version-3.13.0-blue)](https://github.com/genesis-community/concourse-genesis-kit/releases/tag/v3.13.0)
[![Genesis Version](https://img.shields.io/badge/genesis-2.7.6%2B-brightgreen)](https://github.com/genesis-community/genesis)
[![Concourse Version](https://img.shields.io/badge/concourse-7.13.0-brightgreen)](https://github.com/concourse/concourse-bosh-release/releases/tag/v7.13.0)

The Concourse Genesis Kit provides a streamlined way to deploy a full [Concourse CI/CD system](https://concourse-ci.org/). It supports:

- **Full deployments** with web UI, API, database, and workers
- **Small footprint deployments** with reduced resource requirements
- **Workers-only deployments** for satellite sites
- **Various authentication methods** (Basic, GitHub, CF, SAML/Okta)
- **Integration with Vault** for secure credential storage
- **Metrics with Prometheus** for monitoring

## Quick Start

To use this kit, you don't even need to clone the repository! Just run the following (using Genesis v2.7.6 or later):

```bash
# Create a concourse-deployments repo using the latest version of the concourse kit
genesis init --kit concourse

# Create a concourse-deployments repo using v3.13.0 of the concourse kit
genesis init --kit concourse/3.13.0

# Create a my-concourse-configs repo using the latest version of the concourse kit
genesis init --kit concourse -d my-concourse-configs
```

## Feature Highlights

- **Multiple Deployment Types**: Full, small-footprint, or workers-only
- **Authentication Options**: Basic auth, GitHub OAuth, CF UAA, Okta/SAML
- **TLS Options**: Self-signed certificates, provided certificates, or no TLS
- **External Database Support**: Use your own PostgreSQL database
- **Prometheus Integration**: Export metrics for monitoring
- **Vault Integration**: Use Vault for pipeline credential management
- **IaaS Support**: Deploy on AWS, Azure, or STACKIT
- **OCFP Integration**: Deploy as part of an OCFP architecture

## Documentation

For detailed documentation, see:

- [Complete Manual](MANUAL.md) - Full documentation
- [Configuration Reference](docs/configuration/params.md) - All available parameters
- [Features Reference](docs/configuration/features.md) - Available feature flags
- [Authentication Methods](docs/authentication) - Setting up authentication
- [Integrations](docs/integrations) - Third-party integrations (Vault, Prometheus)
- [IaaS Guides](docs/iaas) - IaaS-specific deployment guides
- [Examples](docs/examples) - Example deployment configurations
- [Upgrade Guide](docs/upgrade.md) - How to upgrade between versions
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## Requirements

- Genesis 2.7.6+
- BOSH Director with stemcell support
- Network and cloud config set up for the Concourse VMs

## Releases

| Version | Release Date | Concourse Version | Notes |
|---------|-------------|-------------------|-------|
| 3.13.0  | 2023        | 7.13.0            | STACKIT IaaS support, refactored hooks to Perl modules |
| 3.12.0  | 2023        | 7.12.1            | Various bug fixes |
| 3.11.0  | 2023        | 7.12.0            | New features |
| 2.0.0   | 2019        | ~3.14.1           | First version to support Genesis 2.6 hooks |

## License

This Genesis Kit is released under the MIT License.