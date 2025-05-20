# Concourse Genesis Kit Addons

The Concourse Genesis Kit provides several addon commands that make it easier to interact with and manage your Concourse deployment. This document provides details on all available addons and examples of their usage.

## Available Addons

- [`visit`](#visit) - Open the Concourse web UI in your browser
- [`download-fly`](#download-fly) - Download the Concourse CLI
- [`login`](#login) - Authenticate to your Concourse deployment
- [`logout`](#logout) - Log out from your Concourse deployment
- [`fly`](#fly) - Run fly commands against your Concourse deployment
- [`setup-approle`](#setup-approle) - Configure Vault AppRole for Concourse

## Addon Usage

All addons are invoked using the `genesis do` command:

```bash
genesis do my-env -- addon-name [arguments...]
```

## Addon Details

### `visit`

This addon opens the Concourse Web user interface in your browser.

**Usage:**
```bash
genesis do my-env -- visit
```

**Notes:**
- Only works on macOS systems
- Uses the `open` command to launch the default browser
- Automatically uses the correct protocol (HTTP or HTTPS) based on your deployment configuration

**Example:**
```bash
# Open the Web UI for the 'prod' environment
genesis do prod -- visit
```

### `download-fly`

This addon downloads the correct version of the `fly` CLI compatible with your Concourse deployment.

**Usage:**
```bash
genesis do my-env -- download-fly [path] [--sync] [-p platform]
```

**Arguments:**
- `path`: Optional path where the `fly` executable should be stored (defaults to current directory)
- `--sync`: Instead of placing the executable in the current directory or specified path, replace the `fly` command found in your PATH
- `-p platform`: Explicitly specify the platform to use instead of auto-detection. Valid options are `darwin`/`mac`, `cygwin`/`windows`/`win`, or `linux`

**Examples:**
```bash
# Download fly to the current directory
genesis do prod -- download-fly

# Download fly to a specific location
genesis do prod -- download-fly /usr/local/bin/fly

# Replace the existing fly in your PATH
genesis do prod -- download-fly --sync

# Download the Windows version explicitly
genesis do prod -- download-fly -p windows
```

**Notes:**
- For Windows users working in the Bash Shell under Windows 10, specify `linux` as your platform
- The downloaded version will match the Concourse server version

### `login`

This addon authenticates your `fly` CLI to the Concourse deployment.

**Usage:**
```bash
genesis do my-env -- login
```

**Features:**
- Creates a `fly` target with the same name as the environment
- Automatically uses `--skip-ssl-validation` for self-signed certificates
- Handles the authentication process for you

**Example:**
```bash
# Log in to the 'prod' environment
genesis do prod -- login
```

**Notes:**
- If you're not already logged in, it will prompt for credentials
- For OAuth-based authentication, it will open a browser window
- After successful authentication, a token is stored in your `~/.flyrc` file

### `logout`

This addon logs out from your Concourse deployment, revoking the authentication token.

**Usage:**
```bash
genesis do my-env -- logout
```

**Example:**
```bash
# Log out from the 'prod' environment
genesis do prod -- logout
```

**Notes:**
- This removes the authentication token from your `~/.flyrc` file
- You'll need to log in again to run `fly` commands

### `fly`

This addon lets you run any `fly` command against your Concourse deployment without needing to specify the target.

**Usage:**
```bash
genesis do my-env -- fly <command> [arguments...]
```

**Features:**
- Automatically specifies the correct target
- Logs you in if you're not already authenticated
- Passes all arguments directly to the `fly` command

**Examples:**
```bash
# List pipelines in the 'prod' environment
genesis do prod -- fly pipelines

# Set a pipeline
genesis do prod -- fly set-pipeline -p my-pipeline -c pipeline.yml

# Trigger a job
genesis do prod -- fly trigger-job -j my-pipeline/my-job
```

**Notes:**
- This is a convenient wrapper around the standard `fly` CLI
- All standard `fly` commands and arguments are supported
- The target is automatically set to the environment name

### `setup-approle`

This addon creates the necessary Vault AppRole and policy for Concourse integrations.

**Usage:**
```bash
genesis do my-env -- setup-approle
```

**Features:**
- Interactive setup process
- Creates a Vault AppRole specifically for Concourse
- Configures appropriate policies for pipeline secret access
- Optionally creates a `genesis-pipelines` AppRole for Genesis CI/CD integration

**Example:**
```bash
# Set up AppRole for the 'prod' environment
genesis do prod -- setup-approle
```

**What It Does:**
1. Ensures the AppRole auth method is enabled in Vault
2. Creates a `concourse` policy with appropriate permissions
3. Creates and configures the `concourse` AppRole
4. Generates and stores the Role ID and Secret ID
5. Optionally creates a `genesis-pipelines` AppRole for Genesis integrations

**Notes:**
- Unlike other addons, this can and should be run before deployment
- Created AppRoles can both read and write secrets
- For production, consider creating more restrictive policies with read-only access

## Common Addon Usage Patterns

### Initial Deployment Setup

After deploying a new Concourse environment:

```bash
# Download the fly CLI
genesis do my-env -- download-fly --sync

# Log in to Concourse
genesis do my-env -- login

# Open the Web UI
genesis do my-env -- visit
```

### Pipeline Management Workflow

When working with pipelines:

```bash
# Log in if not already authenticated
genesis do my-env -- login

# Set or update a pipeline
genesis do my-env -- fly set-pipeline -p my-pipeline -c pipeline.yml

# Unpause the pipeline
genesis do my-env -- fly unpause-pipeline -p my-pipeline

# Check pipeline status
genesis do my-env -- fly pipelines
```

### Vault Integration Setup

When setting up Vault integration:

```bash
# Set up the AppRole
genesis do my-env -- setup-approle

# Deploy with Vault integration
genesis deploy my-env

# Verify Vault integration is working
genesis do my-env -- fly set-pipeline -p test -c vault-test-pipeline.yml
```

## Troubleshooting Addons

### Common Issues and Solutions

1. **Addon command not found:**
   - Ensure you're using the correct syntax with `genesis do`
   - Check that you've included the double-dash before the addon name

2. **Visit addon doesn't open browser:**
   - The visit addon only works on macOS
   - Try manually opening the URL displayed in the output

3. **Download-fly permissions issues:**
   - When using `--sync`, ensure you have write permissions to the target location
   - You may need to use `sudo` if replacing a system-wide fly binary

4. **Login addon authentication failures:**
   - For basic auth, verify credentials in Vault
   - For OAuth/SAML, ensure your browser can complete the authentication flow
   - Check for any network issues preventing access to the Concourse server

5. **Fly addon command failures:**
   - Check the specific error message from the fly command
   - Ensure your Concourse deployment is healthy
   - Try running `login` addon first to refresh authentication

6. **Setup-approle errors:**
   - Ensure you have appropriate permissions in Vault
   - Check network connectivity to the Vault server
   - Verify Vault is properly configured