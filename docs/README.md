# Concourse Genesis Kit Documentation

This directory contains detailed documentation for the Concourse Genesis Kit.

## Directory Structure

- **configuration/** - Core configuration reference
  - [params.md](configuration/params.md) - Complete parameters reference
  - [features.md](configuration/features.md) - Feature flags reference
  - [container-runtimes.md](configuration/container-runtimes.md) - Container runtime options

- **authentication/** - Authentication method guides
  - [okta.md](authentication/okta.md) - Okta/SAML authentication

- **integrations/** - Third-party integrations
  - [vault.md](integrations/vault.md) - Vault integration for secrets

- **advanced/** - Advanced topics
  - [ocfp.md](advanced/ocfp.md) - OCFP deployment architecture
  - [team-management.md](advanced/team-management.md) - Team and user management

- **iaas/** - IaaS-specific guides
  - [index.md](iaas/index.md) - AWS, Azure, STACKIT, etc.

- **addons/** - Addon command documentation
  - [index.md](addons/index.md) - Addon command reference

- **Root level files**
  - [terminology.md](terminology.md) - Terminology guide
  - [troubleshooting.md](troubleshooting.md) - Troubleshooting guide
  - [upgrade.md](upgrade.md) - Upgrade instructions

## Overview

The Concourse Genesis Kit documentation is organized to help you:

1. **Understand the basics** - Core concepts and terminology
2. **Configure deployments** - Parameters and feature flags
3. **Integrate with other systems** - Vault, Prometheus, etc.
4. **Authentication options** - Basic, GitHub, CF, SAML/Okta
5. **Troubleshoot issues** - Common problems and solutions
6. **Upgrade deployments** - Version-specific upgrade instructions

## Getting Started

Start with the main [MANUAL.md](../MANUAL.md) file in the root directory, which provides an overview of the kit and links to detailed documentation for specific topics.

For specific use cases, refer to the appropriate sections in this documentation.