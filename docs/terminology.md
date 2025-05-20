# Concourse Genesis Kit Terminology Guide

This document establishes a consistent set of terminology used throughout the Concourse Genesis Kit documentation. Following these conventions ensures clarity and reduces confusion when working with the kit.

## Core Concepts

### Deployment Components

| Term | Definition |
|------|------------|
| **Concourse** | An open-source continuous integration/continuous delivery (CI/CD) system that operates using pipelines defined in YAML. |
| **Genesis Kit** | A template package used by Genesis to deploy complex systems like Concourse. |
| **Environment** | A specific deployment of Concourse, typically corresponding to a particular purpose (dev, test, prod) or location. |
| **Feature** | A configuration flag that enables specific functionality in a Concourse deployment. |
| **Addon** | A command that extends Genesis functionality for working with Concourse deployments. |

### Architectural Components

| Term | Definition |
|------|------------|
| **Web Node** | A VM that runs the Concourse web UI and API components (ATC). |
| **Worker Node** | A VM that executes Concourse pipeline tasks in isolated containers. |
| **Database Node** | A VM that runs the PostgreSQL database used by Concourse. |
| **TSA (Team-Specific Authentication)** | The component that handles worker registration and authentication. |
| **ATC (Air Traffic Controller)** | The component that serves the web UI and API. |

### Deployment Types

| Term | Definition |
|------|------------|
| **Full Deployment** | A complete Concourse deployment with web, database, and worker components. |
| **Small Footprint Deployment** | A Concourse deployment with reduced resource usage, placing web and database on a single VM. |
| **Workers-Only Deployment** | A deployment that consists solely of worker nodes connecting to a separate Concourse deployment. |
| **OCFP Deployment** | A Concourse deployment following the Open Certified Foundational Platform architecture. |

## Authentication Methods

| Term | Definition |
|------|------------|
| **Basic Authentication** | Username/password authentication for Concourse. |
| **OAuth Authentication** | Authentication using an OAuth provider like GitHub or Cloud Foundry UAA. |
| **SAML Authentication** | Authentication using SAML identity providers like Okta. |
| **Team** | A security boundary in Concourse that groups pipelines and access controls. |
| **Main Team** | The special administrative team in Concourse with enhanced privileges. |

## Integration Components

| Term | Definition |
|------|------------|
| **Vault** | HashiCorp's secret management tool that can be integrated with Concourse for secure credential storage. |
| **Vault AppRole** | An authentication method for Vault that uses a Role ID and Secret ID pair. |
| **Locker** | A simple API for locking resources, included with Concourse deployments. |
| **Prometheus** | A monitoring system that can collect metrics from Concourse. |
| **External Database** | A PostgreSQL database managed outside the Concourse deployment. |

## Container Concepts

| Term | Definition |
|------|------------|
| **Container Runtime** | The software that manages containers on worker nodes. |
| **Containerd** | The default container runtime for Concourse 7.0+. |
| **Guardian** | The legacy container runtime used in older Concourse versions. |
| **Houdini** | A "fake" container runtime that doesn't provide actual isolation. |
| **Volume Driver** | The component that manages persistent volumes for containers. |

## Operational Components

| Term | Definition |
|------|------------|
| **fly CLI** | The command-line tool for interacting with Concourse. |
| **Pipeline** | A configuration of resources and jobs that represent a workflow in Concourse. |
| **Resource** | A source of data or a destination for data in a Concourse pipeline. |
| **Job** | A unit of execution in a Concourse pipeline. |
| **Task** | A step within a job that performs a specific action. |

## Genesis Concepts

| Term | Definition |
|------|------------|
| **Manifest** | The complete YAML configuration generated for a BOSH deployment. |
| **Environment File** | A YAML file containing deployment-specific configurations. |
| **Kit** | A package of templates and scripts for deploying a specific system (like Concourse). |
| **Hook** | A script that extends Genesis functionality at specific points in the deployment lifecycle. |
| **Exodus Data** | Information exported from a deployment for use by other systems. |

## IaaS Terminology

| Term | Definition |
|------|------------|
| **VM Type** | A BOSH cloud config definition specifying the size and capabilities of a VM. |
| **Disk Type** | A BOSH cloud config definition specifying the size and type of a persistent disk. |
| **Network** | A BOSH cloud config definition specifying the networking configuration. |
| **Availability Zone** | A BOSH cloud config definition specifying a failure domain. |
| **VM Extension** | A BOSH cloud config definition adding IaaS-specific properties to VMs. |

## Consistent Usage Patterns

### Feature Flags

Feature flags should always be referenced using code formatting and without the leading dash:

- **Correct**: `full`, `small-footprint`, `workers`, `vault`
- **Incorrect**: -full, Small Footprint, workers feature, "vault"

### Parameters

Parameters should always be referenced using code formatting:

- **Correct**: `external_domain`, `num_web_nodes`, `worker_vm_type`
- **Incorrect**: external_domain, Num Web Nodes, worker VM type

### Addons

Addon names should always be referenced in backticks:

- **Correct**: `visit`, `login`, `download-fly`, `setup-approle`
- **Incorrect**: visit addon, Login, download-fly addon, Setup AppRole

### IaaS Names

IaaS names should follow their official capitalization:

- **Correct**: AWS, Azure, STACKIT, vSphere, OpenStack, GCP
- **Incorrect**: aws, AZURE, Stackit, VSphere, openstack, Gcp

### Authentication Methods

Authentication methods should be capitalized consistently:

- **Correct**: Basic Authentication, GitHub OAuth, CF UAA, Okta SAML
- **Incorrect**: basic auth, Github OAuth, cf-uaa, OKTA

## Examples in Documentation

When writing examples, follow these conventions:

### YAML Examples

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
```

### Command Examples

```bash
# With leading command prompt
$ genesis deploy my-env

# Without leading command prompt (preferred)
genesis deploy my-env
```

### Placeholders

Use angle brackets for placeholders:

- **Correct**: `<environment-name>`, `<password>`, `<version>`
- **Incorrect**: [environment-name], {password}, VERSION

## Version References

When referring to version numbers:

- **Full version references**: Include all components (e.g., "version 3.13.0")
- **Major version references**: Use "vX" format (e.g., "v3")
- **Range references**: Use "vX.Y - vX.Z" format (e.g., "v3.0 - v3.10")

## File Path Conventions

When referring to file paths:

- **Absolute paths**: Use full paths (e.g., `/var/vcap/jobs/web/config/config.yml`)
- **Relative paths**: Specify relative to what context (e.g., "relative to the deployment directory")
- **Directory paths**: Include trailing slash (e.g., `hooks/`)
- **File paths**: No trailing slash (e.g., `kit.yml`)

## Best Practices

- Maintain consistent terminology throughout all documentation
- When introducing a new term, provide a clear definition
- Avoid jargon and acronyms without explanation
- Use technical terms precisely and consistently
- When in doubt, refer to this guide for the preferred terminology