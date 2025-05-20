# Deploying Concourse in an OCFP Architecture

The Concourse Genesis Kit provides dedicated support for deploying Concourse CI as part of an Open Certified Foundational Platform (OCFP) architecture, following the opinionated design patterns and conventions established for OCFP deployments.

## Overview

In an OCFP architecture, the Concourse deployment follows specific conventions:

1. A **full** Concourse cluster is deployed (with no HAProxy)
2. Web nodes are attached to a Load Balancer via VM extensions
3. An external database is used (typically RDS in AWS)
4. Vault is integrated for pipeline secret management with AppRole authentication

This guide explains how to configure and deploy Concourse within an OCFP context.

## Enabling OCFP Mode

To deploy Concourse in OCFP mode, add the `ocfp` feature to your environment's manifest:

```yaml
kit:
  name: concourse
  version: 3.13.0
  features:
    - ocfp
```

Adding the `ocfp` feature automatically includes several other features:
- `full` - Deploys a complete Concourse system
- `no-haproxy` - Omits HAProxy from the deployment
- `dynamic-web-ip` - Attaches web nodes to a load balancer
- `external-db` - Configures an external database
- `vault` - Integrates with Vault for secrets
- `vault-approle` - Uses Vault AppRole for authentication

## Prerequisites

Before deploying Concourse in OCFP mode, ensure the following prerequisites are met:

1. **Infrastructure Setup**:
   - The necessary infrastructure should be provisioned using [Codex Terraform](https://github.com/starkandwayne/codex/tree/master/terraform)
   - A load balancer should be available for the Concourse web nodes

2. **External Database**:
   - An externally-managed PostgreSQL database (typically RDS in AWS)
   - The `concourse` database should be initialized using `ocfp init-pg` (see [OCFP Ops Scripts](https://github.com/starkandwayne/ocfp-ops-scripts))

3. **Vault Configuration**:
   - Vault should be set up and accessible
   - An AppRole should be configured for Concourse with appropriate permissions
   - Required secrets should be stored in Vault (see Required Vault Configuration below)

## Required Vault Configuration

Before deploying Concourse in OCFP mode, you must configure the following secrets in Vault:

| Vault Path | Description |
|------------|-------------|
| `secret/<mount-prefix>/<env-slug>/concourse/vault:url` | The Vault URL |
| `secret/<mount-prefix>/<env-slug>/concourse/vault:approle_role_id` | The role ID for the Vault AppRole |
| `secret/<mount-prefix>/<env-slug>/concourse/vault:approle_secret_id` | The secret ID for the Vault AppRole |
| `secret/<mount-prefix>/<env-slug>/concourse/database/external:password` | The password for the external database user |

Additionally, the following Vault paths are used by the OCFP configuration:

| Vault Path | Description |
|------------|-------------|
| `<secrets-mount>/certs/org:ca` | Organization CA certificate (if it exists) |
| `<secrets-mount>/certs/dbs:ca` | External Databases CA certificate |
| `<tf-mount>/rds/instance_address` | The RDS instance address from Terraform |
| `<tf-mount>/rds/instance_port` | The RDS instance port from Terraform |

## Configuration Parameters

When using the `ocfp` feature, the following parameters are available:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ocfp_env_scale` | The scale of the environment (`dev` or `prod`) | `dev` |
| `web_vm_extension` | The VM extension for web nodes | `concourse-lb` |

## Environment Scale

The `ocfp_env_scale` parameter determines the size and configuration of your Concourse deployment:

- `dev` (default): Smaller footprint for development/testing environments
  - Fewer web nodes and workers
  - Smaller VM types
  
- `prod`: Larger footprint for production environments
  - More web nodes and workers
  - Larger VM types with more resources
  - Additional availability zones for HA

## IaaS-Specific Configuration

The OCFP feature includes support for different IaaS providers. The kit automatically detects and applies the appropriate configuration based on the IaaS variables in your deployment.

### AWS Configuration

When deploying on AWS, the kit uses AWS-specific configurations for:
- VM types and extensions
- Cloud IDs
- RDS database connection

See `ocfp/iaas/aws.yml` for detailed AWS-specific configurations.

### STACKIT Configuration

As of version 3.13.0, the kit includes support for STACKIT infrastructure:
- VM types optimized for STACKIT
- Network configurations specific to STACKIT

See `ocfp/iaas/stackit.yml` for detailed STACKIT-specific configurations.

## Deployment Process

The deployment process for an OCFP Concourse follows these steps:

1. **Prepare Vault Configuration**:
   ```bash
   # Set Vault URL
   safe set secret/<mount-prefix>/<env-slug>/concourse/vault url="https://vault.example.com:8200"
   
   # Set AppRole credentials (see Vault integration docs for setup)
   safe set secret/<mount-prefix>/<env-slug>/concourse/vault approle_role_id="role-id-value"
   safe set secret/<mount-prefix>/<env-slug>/concourse/vault approle_secret_id="secret-id-value"
   
   # Set database password
   safe set secret/<mount-prefix>/<env-slug>/concourse/database/external password="secure-db-password"
   ```

2. **Create Deployment Manifest**:
   ```yaml
   ---
   kit:
     name: concourse
     version: 3.13.0
     features:
       - ocfp
   
   params:
     env: prod
     ocfp_env_scale: prod
     external_domain: concourse.example.com
   ```

3. **Deploy Concourse**:
   ```bash
   genesis deploy my-env
   ```

## Integration with Other OCFP Components

The OCFP Concourse deployment is designed to integrate with other OCFP components:

1. **BOSH Director**: Uses the BOSH Director deployed as part of the OCFP platform
2. **RDS Database**: Connects to the shared RDS instance provisioned for the platform
3. **Vault**: Integrates with the platform's Vault instance for secure credential storage
4. **Load Balancer**: Web nodes are attached to the platform load balancer

## Troubleshooting

### Common Issues

1. **Database Connection Failures**:
   - Verify that the database exists and has been initialized
   - Check that the database password is correctly set in Vault
   - Ensure the database is accessible from the Concourse web nodes

2. **Vault Integration Issues**:
   - Verify that the Vault URL is correct
   - Check that the AppRole credentials are valid
   - Ensure the AppRole has the necessary permissions

3. **Load Balancer Issues**:
   - Verify that the `concourse-lb` VM extension exists in your cloud config
   - Check that the load balancer is properly configured
   - Ensure the security groups allow traffic to the web nodes

## Example Configuration

Here's a complete example of an OCFP Concourse deployment:

```yaml
---
kit:
  name: concourse
  version: 3.13.0
  features:
    - ocfp

params:
  env: prod
  ocfp_env_scale: prod
  external_domain: concourse.example.com
  
  # These values are for reference - they are derived from Vault
  # secret/prod/concourse/vault:url = "https://vault.example.com:8200"
  # secret/prod/concourse/vault:approle_role_id = "role-id-value"
  # secret/prod/concourse/vault:approle_secret_id = "secret-id-value"
  # secret/prod/concourse/database/external:password = "secure-db-password"
```

## References

- [Codex Terraform](https://github.com/starkandwayne/codex/tree/master/terraform) - Infrastructure provisioning for OCFP
- [OCFP Ops Scripts](https://github.com/starkandwayne/ocfp-ops-scripts) - Operations scripts for OCFP platforms