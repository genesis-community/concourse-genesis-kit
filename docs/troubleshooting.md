# Troubleshooting Concourse Deployments

This guide covers common issues encountered when deploying and operating Concourse using the Concourse Genesis Kit, along with their solutions.

## Deployment Issues

### Failed Genesis Deploy

#### Symptoms
- `genesis deploy` fails with BOSH errors
- Deployment shows partial success but specific instances fail

#### Common Causes and Solutions

1. **Cloud Config Mismatch**
   - **Issue**: VM types, networks, or disk types referenced in the deployment don't exist in the cloud config
   - **Solution**: Update your cloud config to include the required elements or modify your deployment to use existing ones
   ```bash
   # Check available cloud config elements
   bosh cloud-config
   
   # Update the cloud config if necessary
   bosh update-cloud-config cloud-config.yml
   ```

2. **Missing Secrets in Vault**
   - **Issue**: Required credentials are missing from Vault
   - **Solution**: Ensure all required secrets are in place
   ```bash
   # For a new environment, run
   genesis do my-env -- add-secrets
   
   # To check existing secrets
   safe get secret/my-env/concourse
   ```

3. **Network Connectivity Issues**
   - **Issue**: VMs cannot communicate with each other or external services
   - **Solution**: Verify network setup and security groups
   ```bash
   # SSH to a VM to test connectivity
   bosh -d my-concourse-deployment ssh web/0
   ping database
   curl -v https://vault.example.com:8200
   ```

4. **Resource Constraints**
   - **Issue**: Not enough resources (CPU, memory, disk) to deploy
   - **Solution**: Increase resource allocation or reduce deployment size
   ```yaml
   # Example of reducing resource usage
   params:
     workers: 2  # Reduce from default of 3
     concourse_vm_type: small
   ```

## Web UI/Access Issues

### Cannot Access Web UI

#### Symptoms
- Browser cannot connect to Concourse URL
- SSL/TLS errors when accessing the web interface

#### Common Causes and Solutions

1. **DNS Resolution**
   - **Issue**: Domain name not resolving to the correct IP
   - **Solution**: Verify DNS settings or use direct IP access temporarily
   ```bash
   # Find the web node IP
   bosh -d my-concourse-deployment vms
   
   # Test DNS resolution
   dig concourse.example.com
   ```

2. **Certificate Issues**
   - **Issue**: Invalid or expired certificates
   - **Solution**: Verify or regenerate certificates
   ```bash
   # For self-signed certificates, regenerate with
   genesis rotate-secrets my-env -f ssl
   
   # For provided certificates, update them in Vault
   safe set secret/my-env/concourse/ssl/server certificate@new-cert.pem key@new-key.pem
   ```

3. **Load Balancer Misconfiguration**
   - **Issue**: Load balancer not correctly routing traffic to web nodes
   - **Solution**: Check load balancer health checks and backend configuration
   ```bash
   # Verify web node is listening on the correct port
   bosh -d my-concourse-deployment ssh web/0 -c "netstat -tulpn | grep atc"
   ```

### Authentication Issues

#### Symptoms
- Cannot log in despite correct credentials
- OAuth authentication fails
- SAML/Okta login redirects but fails to complete

#### Common Causes and Solutions

1. **Basic Auth Issues**
   - **Issue**: Incorrect username or password
   - **Solution**: Verify credentials in Vault
   ```bash
   # Get the current admin password
   safe get secret/my-env/concourse/webui:password
   
   # Reset the password if needed
   genesis rotate-secrets my-env -f webui
   ```

2. **OAuth Configuration**
   - **Issue**: Misconfigured OAuth settings
   - **Solution**: Verify OAuth client and callback URLs
   ```bash
   # For GitHub OAuth, check settings
   safe get secret/my-env/concourse/oauth
   
   # Ensure Concourse external_url matches the OAuth callback URL
   ```

3. **SAML/Okta Issues**
   - **Issue**: SAML configuration errors
   - **Solution**: Verify SAML settings in Vault and identity provider
   ```bash
   # Check SAML settings
   safe get secret/my-env/concourse/okta
   
   # Verify CA certificate
   safe get secret/my-env/concourse/okta:ca_cert | openssl x509 -text
   ```

## Database Issues

### Database Connection Failures

#### Symptoms
- Web nodes fail to start with database connection errors
- Intermittent database connectivity issues

#### Common Causes and Solutions

1. **Internal Database Issues**
   - **Issue**: PostgreSQL process not running or corrupt database
   - **Solution**: Restart or repair the database
   ```bash
   # SSH to the database VM
   bosh -d my-concourse-deployment ssh db/0
   
   # Check PostgreSQL process
   sudo monit summary
   
   # Restart if needed
   sudo monit restart postgres
   ```

2. **External Database Connectivity**
   - **Issue**: Cannot connect to external database
   - **Solution**: Verify connectivity and credentials
   ```bash
   # Test connection from web node
   bosh -d my-concourse-deployment ssh web/0
   psql -h <db_host> -p <db_port> -U <db_user> -d <db_name>
   
   # Check external DB credentials
   safe get secret/my-env/concourse/database/external:password
   ```

3. **Database Migration Issues**
   - **Issue**: Failed schema migrations after Concourse upgrade
   - **Solution**: Check migration logs and potentially restore from backup
   ```bash
   # Check ATC logs for migration errors
   bosh -d my-concourse-deployment logs web/0 --agent | grep migration
   ```

## Worker Issues

### Workers Not Registering

#### Symptoms
- Workers show as stalled or not registering
- Jobs pending indefinitely with no available workers

#### Common Causes and Solutions

1. **TSA Communication Issues**
   - **Issue**: Workers cannot communicate with the TSA
   - **Solution**: Verify network connectivity and certificates
   ```bash
   # Check worker logs
   bosh -d my-concourse-deployment logs worker/0 --agent | grep tsa
   
   # Test connectivity from worker to web
   bosh -d my-concourse-deployment ssh worker/0 -c "netstat -tulpn | grep beacon"
   bosh -d my-concourse-deployment ssh worker/0 -c "nc -zv web.concourse.service.cf.internal 2222"
   ```

2. **Garden/Containerd Issues**
   - **Issue**: Container runtime not starting properly
   - **Solution**: Verify garden/containerd configuration and status
   ```bash
   # Check container runtime logs
   bosh -d my-concourse-deployment logs worker/0 --agent | grep containerd
   
   # Restart the worker
   bosh -d my-concourse-deployment restart worker/0
   ```

3. **Worker Resource Exhaustion**
   - **Issue**: Worker running out of disk, memory, or other resources
   - **Solution**: Increase resources or add more workers
   ```bash
   # Check worker resource usage
   bosh -d my-concourse-deployment ssh worker/0 -c "df -h && free -m && top -bn1"
   
   # Increase resources in your deployment
   params:
     worker_vm_type: large  # Use a larger VM type
   ```

## Pipeline Issues

### Pipeline Credential Issues

#### Symptoms
- Pipelines fail with credential errors
- ((vault-path)) interpolation not working

#### Common Causes and Solutions

1. **Vault Integration Issues**
   - **Issue**: Concourse cannot authenticate to Vault or find secrets
   - **Solution**: Verify Vault configuration and credentials
   ```bash
   # Check Vault config on the web node
   bosh -d my-concourse-deployment ssh web/0 -c "grep -r vault /var/vcap/jobs/web/config/"
   
   # Test Vault connectivity and authentication
   bosh -d my-concourse-deployment ssh web/0
   curl -v https://vault.example.com:8200/v1/sys/health
   ```

2. **Secret Path Issues**
   - **Issue**: Secrets not found at expected paths
   - **Solution**: Verify secret paths and Vault mount configuration
   ```bash
   # Check if secret exists at expected path
   safe get /concourse/my-team/my-secret
   
   # For nested paths, ensure all parent paths exist
   safe set /concourse/my-team/my-secret value="secret-value"
   ```

3. **AppRole Authentication Expired**
   - **Issue**: Vault AppRole credentials expired
   - **Solution**: Rotate AppRole credentials
   ```bash
   # Generate new Secret ID
   vault write -f auth/approle/role/concourse/secret-id
   
   # Update in Vault
   safe set secret/my-env/concourse/vault approle_secret_id="new-secret-id"
   
   # Redeploy Concourse
   genesis deploy my-env
   ```

## Add-on Issues

### Fly CLI Issues

#### Symptoms
- `fly` commands fail to connect
- `fly` version mismatch errors

#### Common Causes and Solutions

1. **Version Mismatch**
   - **Issue**: `fly` CLI version doesn't match server version
   - **Solution**: Use the `download-fly` add-on to get the correct version
   ```bash
   # Download matching fly version
   genesis do my-env -- download-fly
   
   # Or sync existing fly
   genesis do my-env -- download-fly --sync
   ```

2. **Authentication Issues**
   - **Issue**: `fly` not authenticated or token expired
   - **Solution**: Use the `login` add-on to authenticate
   ```bash
   # Login using the add-on
   genesis do my-env -- login
   
   # Check status of targets
   fly targets
   ```

### Prometheus Integration Issues

#### Symptoms
- Metrics not appearing in Prometheus
- Web nodes not exposing metrics endpoint

#### Common Causes and Solutions

1. **Metrics Port Not Exposed**
   - **Issue**: Prometheus metrics endpoint not accessible
   - **Solution**: Verify configuration and network access
   ```bash
   # Check if metrics endpoint is listening
   bosh -d my-concourse-deployment ssh web/0 -c "netstat -tulpn | grep 9391"
   
   # Test metrics endpoint locally
   bosh -d my-concourse-deployment ssh web/0 -c "curl -s localhost:9391/metrics | head"
   ```

2. **Prometheus Configuration**
   - **Issue**: Prometheus not configured to scrape Concourse metrics
   - **Solution**: Update Prometheus scrape configuration
   ```yaml
   # Example Prometheus scrape config
   scrape_configs:
     - job_name: 'concourse'
       static_configs:
         - targets: ['concourse-web.example.com:9391']
   ```

## BOSH Troubleshooting

### Advanced BOSH Troubleshooting

When standard troubleshooting doesn't resolve the issue, use these BOSH commands for deeper investigation:

```bash
# View detailed instance information
bosh -d my-concourse-deployment instances --details

# Check instance logs
bosh -d my-concourse-deployment logs web/0 --agent

# SSH to an instance for debugging
bosh -d my-concourse-deployment ssh web/0

# View recent tasks
bosh tasks --recent=25

# Get task debug output
bosh task 123 --debug

# Recreate problematic instances
bosh -d my-concourse-deployment recreate web/0

# Restart jobs on an instance
bosh -d my-concourse-deployment restart web/0 --jobs web
```

## Genesis Kit Specific Troubleshooting

### Genesis Hooks Issues

#### Symptoms
- Genesis hooks failing with errors
- Issues with blueprint generation or add-ons

#### Common Causes and Solutions

1. **Genesis Version Compatibility**
   - **Issue**: Using an incompatible Genesis version
   - **Solution**: Update Genesis to the required version
   ```bash
   # Check Genesis version
   genesis -v
   
   # Update Genesis if needed
   genesis update
   ```

2. **Hook Permission Issues**
   - **Issue**: Hook scripts don't have execute permissions
   - **Solution**: Ensure hooks are executable
   ```bash
   # Fix hook permissions
   chmod +x /path/to/concourse-genesis-kit/hooks/*
   ```

3. **Perl Module Issues**
   - **Issue**: Missing or incompatible Perl modules
   - **Solution**: Ensure Genesis Perl environment is set up correctly
   ```bash
   # Check Perl module setup
   perl -c /path/to/concourse-genesis-kit/hooks/blueprint.pm
   ```

## Getting Additional Help

If you're still experiencing issues after trying these troubleshooting steps, you can:

1. Check the [GitHub Issues](https://github.com/genesis-community/concourse-genesis-kit/issues) for known problems
2. Open a new issue with detailed information about your deployment and the problem
3. Reach out to the community for assistance