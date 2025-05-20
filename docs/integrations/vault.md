# Vault Integration with Concourse

The Concourse Genesis Kit allows your Concourse deployment to integrate with HashiCorp Vault for securely storing and accessing pipeline credentials. This document outlines how to set up and configure this integration.

## Overview

Concourse can be configured to pull credentials for pipeline configurations from Vault. The pipelines can specify properties wrapped in double parentheses to pull these credentials dynamically from Vault. For example, a pipeline might contain:

```yaml
resources:
  - name: my-repo
    type: git
    source:
      uri: https://github.com/example/repo.git
      username: ((github.username))
      password: ((github.password))
```

In this example, `((github.username))` and `((github.password))` will be replaced at runtime with values fetched from Vault.

## Setup Options

The Concourse Genesis Kit provides two main methods for authenticating with Vault:

1. **Token-based authentication** - Simpler but less secure for long-term use
2. **AppRole authentication** - More secure and recommended for production

## Enabling Vault Integration

To enable Vault integration, add the `vault` feature to your environment's manifest:

```yaml
kit:
  name: concourse
  version: 3.13.0
  features:
    - vault
```

## Token-Based Authentication

This is the simpler approach but has drawbacks for long-term use as tokens may expire.

### Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vault_url` | The URL of the Vault API to contact | *Required* |
| `vault_path_prefix` | The path prefix to look for secrets under | `/concourse` |
| `vault_insecure_skip_verify` | Whether to skip validation of the Vault API cert | `false` |
| `vault_token` | The token to present as authentication | *Required* |

### Example Configuration

```yaml
params:
  vault_url: https://vault.example.com:8200
  vault_path_prefix: /concourse
  vault_token: s.AbCdEfGhIjKlMnOpQrStUv
```

### Limitations

- Tokens have expiration times
- Token renewal can be complex to manage
- Less secure for production environments

## AppRole Authentication (Recommended)

AppRole authentication is more secure and better suited for production environments. It uses a Role ID and Secret ID pair instead of a single token.

### Enabling AppRole Authentication

Add both the `vault` and `vault-approle` features to your environment:

```yaml
kit:
  name: concourse
  version: 3.13.0
  features:
    - vault
    - vault-approle
```

### Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vault_url` | The URL of the Vault API to contact | *Required* |
| `vault_path_prefix` | The path prefix to look for secrets under | `/concourse` |
| `vault_insecure_skip_verify` | Whether to skip validation of the Vault API cert | `false` |
| `vault_approle_role_id` | The role ID for the AppRole | *Required* |
| `vault_approle_secret_id` | The secret ID of the AppRole | *Required* |

### Example Configuration

```yaml
params:
  vault_url: https://vault.example.com:8200
  vault_path_prefix: /concourse
  vault_approle_role_id: 9876a1b2-3c4d-5e6f-789g-0h1i2j3k4l5m
  vault_approle_secret_id: 1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p
```

## Setting Up AppRole with the setup-approle Addon

The Concourse Genesis Kit includes a helpful addon for setting up the necessary Vault AppRole:

```bash
genesis do my-env -- setup-approle
```

This interactive addon will:

1. Enable the AppRole auth method in Vault if not already enabled
2. Create a `concourse` policy with appropriate permissions
3. Create and configure the `concourse` AppRole
4. Store the Role ID and Secret ID in Vault for safekeeping
5. Optionally create a `genesis-pipelines` AppRole for use with Genesis pipelines

### AppRole Permissions

The `concourse` AppRole created by the addon will have the following permissions:

```hcl
# For KV v1 store
path "/concourse/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# For KV v2 store
path "/concourse/data/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "/concourse/metadata/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
```

**Note**: This AppRole has both read and write permissions. For production environments, you may want to create a more restricted policy with read-only access.

## Manual AppRole Setup

If you prefer to set up the AppRole manually, follow these steps:

1. Create a policy for Concourse:

```bash
vault policy write concourse - <<EOF
# For KV v1 store
path "/concourse/*" {
  capabilities = ["read", "list"]
}

# For KV v2 store
path "/concourse/data/*" {
  capabilities = ["read", "list"]
}
path "/concourse/metadata/*" {
  capabilities = ["read", "list"]
}
EOF
```

2. Create the AppRole:

```bash
# Enable AppRole auth method if not already enabled
vault auth enable approle

# Create the AppRole with appropriate settings
vault write auth/approle/role/concourse \
  secret_id_ttl=0 \
  token_num_uses=0 \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_num_uses=0 \
  policies=concourse
```

3. Get the Role ID and Secret ID:

```bash
# Get the Role ID
ROLE_ID=$(vault read -field=role_id auth/approle/role/concourse/role-id)

# Generate a Secret ID
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/concourse/secret-id)

echo "Role ID: $ROLE_ID"
echo "Secret ID: $SECRET_ID"
```

4. Configure your Concourse environment to use these credentials.

## Using Vault in Pipelines

Once Vault integration is configured, you can refer to Vault paths in your pipelines using the double-parentheses syntax:

```yaml
jobs:
- name: do-something
  plan:
  - task: use-vault-creds
    config:
      platform: linux
      image_resource:
        type: registry-image
        source: {repository: busybox}
      run:
        path: /bin/sh
        args:
        - -c
        - |
          echo "Using credentials from Vault: ((secret-path))"
```

### Path Resolution

Vault paths are resolved as follows:

1. For a variable `((foo))`:
   - With KV v1: Concourse will look at `<vault_path_prefix>/foo`
   - With KV v2: Concourse will look at `<vault_path_prefix>/data/foo`

2. For a variable with a leading slash `((/foo))`:
   - With KV v1: Concourse will look at `/foo`
   - With KV v2: Concourse will look at `/data/foo`

## Troubleshooting

### Common Issues

1. **Authentication failures**: 
   - Check that your AppRole credentials are correct
   - Verify the token or AppRole hasn't expired
   - Ensure network connectivity to Vault

2. **Permission denied**: 
   - Check that your policy includes the necessary paths
   - Verify read/list capabilities are assigned

3. **Secret not found**: 
   - Verify the secret exists at the expected path
   - Check if you're using the correct KV version paths

### Checking Vault Integration

To verify Concourse can connect to Vault:

```bash
# SSH to the Concourse web node
bosh -d my-concourse-deployment ssh web/0

# Check ATC logs for Vault connection issues
sudo cat /var/vcap/sys/log/web/web.stdout.log | grep vault
```

## Best Practices

1. **Use AppRole over token authentication** for production environments
2. **Rotate Secret IDs** periodically
3. **Use least privilege policies** - limit to read-only access when possible
4. **Monitor token usage and expirations**
5. **Use separate Vault paths** for different environments
6. **Backup Role ID and Secret ID** securely