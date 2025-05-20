# Team and User Management in Concourse

Concourse supports a multi-team model with different authentication methods and role-based access control. This document outlines how to manage teams and users in your Concourse deployment.

## Overview

Concourse organizes access control around teams:

- **Teams** are the primary unit of security isolation
- Each team can have its own pipelines, resources, and jobs
- Users can be members of multiple teams
- The special `main` team has administrative privileges

## Team Roles

Concourse supports three team roles:

1. **Owner**: Full administrative control over the team
2. **Member**: Can configure pipelines and resources
3. **Viewer**: Read-only access to team resources

## Authentication Methods

The Concourse Genesis Kit supports several authentication methods that determine how users are identified and assigned to teams:

- **Basic Authentication**: Simple username/password (mainly for the `main` team)
- **GitHub OAuth**: Authentication via GitHub users and organizations
- **Cloud Foundry OAuth**: Authentication via CF UAA users and spaces
- **SAML/Okta**: Authentication via SAML identity providers like Okta

Each authentication method requires specific configuration in your deployment manifest.

## Main Team Configuration

### Basic Authentication (Default)

By default, the `main` team uses basic authentication:

```yaml
params:
  main_user: admin
```

The password is automatically generated and stored in Vault at `secret/$env/concourse/webui` during deployment.

### GitHub OAuth

When using GitHub OAuth, you can specify which GitHub organizations or teams have access to the `main` team:

```yaml
params:
  authz_allowed_orgs: my-github-org
```

For more granular control:

```yaml
params:
  github_authz:
    - organization: my-github-org
      teams: [platform-team, ci-admins]
    - user: specific-github-user
```

### CF OAuth

With CF OAuth, you specify which Cloud Foundry spaces have access to the `main` team:

```yaml
params:
  cf_api_uri: https://api.sys.example.com
  cf_spaces:
    - system:concourse-admins
    - platform:ci-team
```

### SAML/Okta

For SAML authentication (including Okta), specify which SAML groups have access to the `main` team in Vault:

```
secret/$env/concourse/okta:main_team_saml_groups = "ConcourseAdmins,PlatformTeam"
```

## Managing Other Teams

While the `main` team is configured through the deployment manifest, other teams are managed using the `fly` CLI.

### Creating Teams

To create a new team:

```bash
# Basic syntax
fly -t your-target set-team -n team-name --[auth-method]-user=username

# Examples
fly -t your-target set-team -n engineering --github-org=engineering-org
fly -t your-target set-team -n platform --github-team=engineering-org:platform
fly -t your-target set-team -n qa --cf-space=platform:qa-team
fly -t your-target set-team -n security --saml-group=SecurityTeam
```

### Using Team Configuration Files

For more complex team configurations, use configuration files:

```bash
fly -t your-target set-team -n team-name --config=team-config.yml
```

Example `team-config.yml`:

```yaml
roles:
  - name: owner
    github:
      teams: ["org:team-leads"]
    saml:
      groups: ["ConcourseAdmins"]
      
  - name: member
    github:
      teams: ["org:developers"]
    saml:
      groups: ["Engineers"]
      
  - name: viewer
    github:
      orgs: ["org"]
    saml:
      groups: ["Stakeholders"]
```

### Viewing Teams

To list all teams:

```bash
fly -t your-target teams
```

To see details about a specific team:

```bash
fly -t your-target get-team -n team-name
```

### Destroying Teams

To remove a team:

```bash
fly -t your-target destroy-team -n team-name
```

## Automating Team Management

For environments with many teams, managing teams manually can become cumbersome. Consider the following approaches:

### Script-based Approach

Create scripts to automate team creation and updates:

```bash
#!/bin/bash
# Example: create-teams.sh

teams=(
  "team1:github:org-name:team-name"
  "team2:cf:system:team2-space"
  "team3:saml:Team3Group"
)

for team_def in "${teams[@]}"; do
  IFS=':' read -r team_name auth_type auth_param1 auth_param2 <<< "$team_def"
  
  case $auth_type in
    github)
      fly -t concourse set-team -n "$team_name" --github-team="$auth_param1:$auth_param2"
      ;;
    cf)
      fly -t concourse set-team -n "$team_name" --cf-space="$auth_param1:$auth_param2"
      ;;
    saml)
      fly -t concourse set-team -n "$team_name" --saml-group="$auth_param1"
      ;;
  esac
done
```

### Configuration-as-Code

For more complex setups, consider a configuration-as-code approach:

1. Define team configurations in YAML files
2. Store these files in a Git repository
3. Create a pipeline that updates teams when configurations change

Example pipeline:

```yaml
resources:
  - name: team-configs
    type: git
    source:
      uri: https://github.com/example/concourse-teams.git
      branch: main

jobs:
  - name: update-teams
    plan:
      - get: team-configs
        trigger: true
      - task: apply-team-configs
        config:
          platform: linux
          image_resource:
            type: registry-image
            source: {repository: concourse/concourse}
          inputs:
            - name: team-configs
          run:
            path: /bin/sh
            args:
              - -c
              - |
                set -eu
                cd team-configs
                
                for config in *.yml; do
                  team_name=$(basename "$config" .yml)
                  echo "Updating team: $team_name"
                  fly -t self set-team -n "$team_name" --config="$config" --non-interactive
                done
```

## Best Practices

1. **Limit `main` Team Access**: Restrict access to the `main` team to administrators only
2. **Use Groups/Teams**: Prefer granting access to groups/teams rather than individual users
3. **Implement Least Privilege**: Grant only the necessary roles to each user/group
4. **Regularly Audit Team Membership**: Periodically review team access
5. **Document Team Ownership**: Maintain documentation about team ownership and users
6. **Use Role Separation**: Leverage the different role types (owner, member, viewer)
7. **Standardize Team Names**: Use consistent naming conventions for teams

## Future Enhancements

The Concourse Genesis Kit team is working on enhancing team management capabilities to allow:

- Team configuration through environment files
- Automatic team creation during deployment
- Idempotent team management through post-deploy hooks

These features will be available in future releases.

## Limitations

- Changes to team configuration require using the `fly` CLI or API
- There is no way to directly import all users from an identity provider
- Team management cannot be fully automated through the deployment manifest (as of v3.13.0)
- Team pipelines and resources must be managed separately from team membership