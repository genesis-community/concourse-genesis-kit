# Okta/SAML Authentication for Concourse

The Concourse Genesis Kit supports SAML-based authentication through Okta, allowing users to authenticate using their Okta credentials and granting team access based on Okta group memberships.

## Overview

Okta is a popular identity provider that implements the SAML (Security Assertion Markup Language) protocol for single sign-on. This integration allows:

- Users to log in to Concourse using their Okta credentials
- Access control to Concourse teams based on Okta group memberships
- Centralized user management through Okta

## Enabling Okta Authentication

To enable Okta authentication, add the `okta` feature to your environment's manifest:

```yaml
kit:
  name: concourse
  version: 3.13.0
  features:
    - full  # or small-footprint
    - okta
```

## Required Vault Configuration

The Okta integration requires several configuration values to be stored in Vault. These need to be set up before deploying Concourse.

| Vault Path | Description |
|------------|-------------|
| `secret/$env/concourse/okta:display_name` | The display name for the Okta auth button (defaults to "Okta" if not specified) |
| `secret/$env/concourse/okta:main_team_saml_groups` | SAML group(s) whose members should have access to the main team |
| `secret/$env/concourse/okta:sso_issuer` | The SAML issuer, typically your Okta tenant URL |
| `secret/$env/concourse/okta:sso_url` | The SAML SSO URL provided by Okta |
| `secret/$env/concourse/okta:ca_cert` | The CA certificate for validating SAML responses |

## Setting Up Okta for Concourse

### 1. Create a SAML Application in Okta

1. Log in to your Okta admin dashboard
2. Navigate to Applications > Applications
3. Click "Add Application" and select "Create New App"
4. Choose "SAML 2.0" as the platform
5. Name the application (e.g., "Concourse CI")
6. Configure the SAML settings:
   - Single Sign-On URL: https://your-concourse-domain/sky/issuer/callback
   - Audience URI (SP Entity ID): https://your-concourse-domain/sky/issuer/callback
   - Name ID format: EmailAddress
   - Application username: Email
7. Add attribute statements (optional but recommended):
   - `groups` -> user.groups (for group-based access control)
   - `email` -> user.email
   - `name` -> user.fullName

### 2. Get SAML Configuration Values

After creating the application, you'll need to gather the following information:

1. **Identity Provider Issuer (Entity ID)**: Often your Okta tenant URL (e.g., `https://company.okta.com`)
2. **Identity Provider Single Sign-On URL**: The SSO URL provided by Okta
3. **X.509 Certificate**: The certificate Okta will use to sign SAML assertions

### 3. Store Configuration in Vault

Use `safe` or other Vault tools to store the configuration:

```bash
# Store the Okta display name
safe set secret/$env/concourse/okta display_name="Okta SSO"

# Store the main team SAML groups
safe set secret/$env/concourse/okta main_team_saml_groups="OktaAdmin,ConcourseAdmins"

# Store the SSO issuer
safe set secret/$env/concourse/okta sso_issuer="https://company.okta.com"

# Store the SSO URL
safe set secret/$env/concourse/okta sso_url="https://company.okta.com/app/app_name/exampleAppId/sso/saml"

# Store the CA certificate
safe set secret/$env/concourse/okta ca_cert@/path/to/okta/certificate.pem
```

## Team Management with Okta Groups

### Main Team Access

The `main_team_saml_groups` Vault value determines which Okta groups have access to the main team. Users who are members of any of these groups will be granted access to the main team.

Example:
```yaml
main_team_saml_groups: "OktaAdmin,ConcourseAdmins"
```

### Other Teams

To grant Okta groups access to other teams, you can use the Concourse fly CLI:

```bash
fly -t your-concourse set-team -n team-name --saml-group=OktaGroupName
```

Or manage it through a configuration file:

```bash
fly -t your-concourse set-team -n team-name --config=team-config.yml
```

Where `team-config.yml` contains:

```yaml
roles:
  - name: member
    saml:
      groups: ["OktaGroupName"]
  - name: owner
    saml:
      groups: ["OktaAdminGroup"]
```

## User Login Process

1. User navigates to the Concourse login page
2. User clicks the Okta login button
3. User is redirected to Okta for authentication
4. After successful authentication, user is redirected back to Concourse
5. Concourse assigns team memberships based on the user's Okta groups

## Troubleshooting

### Common Issues

1. **SAML Response Validation Errors**:
   - Ensure the CA certificate is correctly stored in Vault
   - Verify the `sso_issuer` matches the Okta Entity ID
   - Check certificate expiration dates

2. **Group Membership Issues**:
   - Ensure the Okta application is configured to send group attributes
   - Verify group names match exactly between Okta and Concourse configuration
   - Check if groups are being correctly assigned to users in Okta

3. **Redirect Issues**:
   - Verify that the external URL configured for Concourse is correct
   - Ensure the callback URL in Okta matches the Concourse URL

### Checking SAML Configuration

To verify your SAML configuration:

```bash
# SSH to the Concourse web node
bosh -d my-concourse-deployment ssh web/0

# Check ATC logs for SAML-related messages
sudo cat /var/vcap/sys/log/web/web.stdout.log | grep -i saml
```

## Example Configuration

Here's a complete example of a Concourse deployment with Okta authentication:

```yaml
---
kit:
  name: concourse
  version: 3.13.0
  features:
    - full
    - self-signed-cert
    - okta

params:
  env: prod
  external_domain: concourse.example.com
  num_web_nodes: 2
  worker_vm_type: large
  workers: 5
  
  # These values are for reference - they must be stored in Vault
  # secret/prod/concourse/okta:display_name = "Company Okta"
  # secret/prod/concourse/okta:main_team_saml_groups = "ConcourseAdmins,PlatformTeam"
  # secret/prod/concourse/okta:sso_issuer = "https://company.okta.com"
  # secret/prod/concourse/okta:sso_url = "https://company.okta.com/app/concourse/xyz123/sso/saml"
  # secret/prod/concourse/okta:ca_cert = "-----BEGIN CERTIFICATE-----\n..."
```

## Limitations

- The current implementation only supports a single SAML identity provider
- Changes to team access require using the fly CLI or API, as they cannot be managed through the Genesis deployment
- User role management within teams is limited to the capabilities provided by Concourse