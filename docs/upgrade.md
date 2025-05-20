# Upgrading Concourse Deployments

This guide provides instructions for upgrading your Concourse deployments to newer versions of the Concourse Genesis Kit.

## Version Compatibility Matrix

| Genesis Kit Version | Concourse Version | Minimum Genesis Version | Notes |
|---------------------|-------------------|-------------------------|-------|
| 3.13.0              | 7.13.0            | 2.7.6                   | STACKIT support, Perl module refactoring |
| 3.12.0              | 7.12.1            | 2.7.6                   | Bug fixes |
| 3.11.0              | 7.12.0            | 2.7.6                   | Feature enhancements |
| 2.0.0               | ~3.14.1           | 2.6.0                   | First version with Genesis 2.6 hooks |

## General Upgrade Process

The general process for upgrading a Concourse deployment is:

1. **Backup** - Create backups of your current deployment
2. **Update Genesis Kit Version** - Specify the new version in your deployment manifest
3. **Review Changes** - Check for breaking changes or new requirements
4. **Deploy** - Deploy the updated environment
5. **Verification** - Verify that the upgraded deployment works correctly

## Step-by-Step Upgrade Instructions

### 1. Backup Your Current Deployment

Before upgrading, create backups of your deployment:

```bash
# Export your deployment manifest
genesis manifest my-env > my-env-manifest-backup.yml

# Back up Concourse database (if using internal database)
bosh -d my-concourse-deployment ssh db/0 "sudo -i bash -c '/var/vcap/packages/postgres/bin/pg_dump -U vcap atc > /tmp/atc_db_backup.sql'"
bosh -d my-concourse-deployment scp db/0:/tmp/atc_db_backup.sql atc_db_backup.sql
```

### 2. Update Genesis Kit Version

Edit your environment's `.yml` file to specify the new kit version:

```yaml
---
kit:
  name: concourse
  version: 3.13.0  # Update to the desired version
```

### 3. Review Required Changes

Check the release notes for the target version to identify any breaking changes or new requirements. Pay special attention to:

- Parameter name changes
- Feature flag changes
- New required secrets
- Changes in default behavior

### 4. Deploy the Updated Environment

Deploy your updated environment:

```bash
# Check what changes will be made
genesis manifest my-env

# Deploy the changes
genesis deploy my-env
```

### 5. Verify the Upgrade

After deployment completes, verify that Concourse is functioning correctly:

```bash
# Check BOSH deployment status
bosh -d my-concourse-deployment instances

# Try logging in with the fly CLI
genesis do my-env -- login

# Run a simple fly command to verify functionality
fly -t my-env pipelines
```

## Specific Version Upgrade Paths

### Upgrading from 2.x to 3.x

When upgrading from version 2.x to 3.x, be aware of these significant changes:

1. **Genesis 2.7.6+ Required**: Upgrade Genesis to at least version 2.7.6 before upgrading the kit
2. **Renamed Parameters**: Some parameters have been renamed for clarity
3. **Container Runtime Options**: New container_runtime parameter with default of containerd
4. **Authentication Changes**: Enhanced authentication options, including SAML/Okta support

#### Migration Steps:

1. Update your Genesis version:
   ```bash
   genesis update 2.7.6
   ```

2. Update parameter names in your environment files:
   ```yaml
   # Example: Update renamed parameters
   params:
     # Before: worker_instances: 3
     workers: 3  # New parameter name
   ```

3. Deploy with the new version:
   ```bash
   genesis deploy my-env
   ```

### Upgrading from 3.0-3.9 to 3.10+

When upgrading from early 3.x versions to 3.10+, note these changes:

1. **Perl Module Refactoring**: Hooks were refactored to Perl modules for better maintainability
2. **Concourse 7.x Support**: Now supports Concourse 7.x with new features
3. **OCFP Improvements**: Enhanced OCFP integration

#### Migration Steps:

1. Deploy with the new version (no special steps required):
   ```bash
   genesis deploy my-env
   ```

### Upgrading from 3.12 to 3.13

Version 3.13 introduced STACKIT IaaS provider support. If you're deploying on STACKIT infrastructure:

1. Enable STACKIT support in your environment:
   ```yaml
   kit:
     name: concourse
     version: 3.13.0
     
   params:
     # Add any STACKIT-specific parameters as needed
   ```

## Upgrading Concourse Release Version

The Concourse Genesis Kit includes a specific version of the Concourse BOSH release. To upgrade to a different Concourse version:

1. Override the release in your environment file:
   ```yaml
   releases:
     concourse:
       version: "7.14.0"  # Specify desired version
   ```

2. Deploy with the custom release version:
   ```bash
   genesis deploy my-env
   ```

**Note**: Not all Concourse versions are compatible with all Genesis Kit versions. Test thoroughly when using a non-default Concourse version.

## Downgrade Procedure

If you need to downgrade to a previous version:

1. Update your environment file to specify the previous version:
   ```yaml
   kit:
     name: concourse
     version: 3.12.0  # Previous version
   ```

2. Deploy with the previous version:
   ```bash
   genesis deploy my-env
   ```

**Note**: Downgrades might not work cleanly if database migrations cannot be reversed. Always test in a non-production environment first.

## Troubleshooting Upgrades

### Common Upgrade Issues

1. **Schema Migration Failures**:
   - **Symptom**: Deployment fails during database migrations
   - **Solution**: Check Concourse web logs for specific errors
   ```bash
   bosh -d my-concourse-deployment logs web/0 --agent | grep migration
   ```

2. **Incompatible Secrets Format**:
   - **Symptom**: Deployment fails with credential or certificate errors
   - **Solution**: Regenerate secrets or credentials in the expected format
   ```bash
   genesis add-secrets my-env
   ```

3. **Worker Compatibility Issues**:
   - **Symptom**: Workers fail to register after upgrade
   - **Solution**: Ensure worker and web nodes are using compatible versions
   ```bash
   # Force recreation of workers
   bosh -d my-concourse-deployment recreate worker
   ```

4. **Genesis Hook Errors**:
   - **Symptom**: Genesis commands fail with hook errors
   - **Solution**: Ensure you're using the required Genesis version
   ```bash
   genesis -v
   genesis update
   ```

## Getting Help

If you encounter issues during the upgrade process:

1. Check the [GitHub Issues](https://github.com/genesis-community/concourse-genesis-kit/issues) for known problems
2. Consult the [troubleshooting guide](troubleshooting.md) for common solutions
3. Open a new issue with detailed information about your upgrade attempt