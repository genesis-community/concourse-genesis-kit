Concourse Genesis Kit
==================

This is a Genesis Kit for the [Concourse CI/CD System][1]. It will
deploy a fully functional Concourse environment for use pipelining
BOSH deployments managed by [Genesis][2], and any CI/CD tasks you
want to throw at it.

By default, this Concourse deployment includes the [locker API][3]
colocated along the Concourse database, so that the [locker-resource][4]
portions of the Genesis deployment pipelines will work. It is general
purpose enough to use as a locking system for any other Concourse jobs,
should you wish to make use of it.

Quick Start
-----------

To use it, you don't even need to clone this repository!  Just run
the following (using Genesis v2):

```
# create a concourse-deployments repo using the latest version of the concourse kit
genesis init --kit concourse

# create a concourse-deployments repo using v1.0.0 of the concourse kit
genesis init --kit concourse/1.0.0

# create a my-concourse-configs repo using the latest version of the concourse kit
genesis init --kit concourse -d my-concourse-configs
```

Subkits
-------

#### Authentication Backends

When deploying Concourse, this kit provides four options for configuring
how users authenticate to Concourses. One of these three must be specified:

- **github-oauth** - Sets up OAuth2 using `github.com` as the OAuth provider.
- **github-enterprise-oauth** - Sets up OAuth2 using a GitHub Enterprise installation
  as the OAuth provider.
- **cf-oauth** - Sets up Oauth2 using a user supplied [UAA][5] as the OAuth provider
- **HTTP Basic Auth** - Not actually a subkit, but if no other auth backends are provided,
  this will be used.

#### Shield

The SHIELD subit adds the SHIELD agent to the Concourse deployment, so that its data
can be backed up via SHIELD.

#### Azure

When deploying Concourse on azure, you may want to consider the `azure` subkit for
reconfiguring the availability zones in play. Since Azure uses availability sets,
rather than zones, there is typically only one zone in play for networks/VMs,
and the availability set would be defined by the Azure CPI automatically, or via
`cloud_properties` in your Cloud Config.

#### Workers-Only

This subkit lets you deploy a just the worker instances of a full
Concourse, provided that you have an upstream Concourse (the "main
Concourse") to hook them up to.  This is useful for disconnected
and sequestered environments, where a single Concourse would be
unable to contact all of your different BOSH directors or Cloud
Foundry instances.

Params
------

#### Base Params

- **params.external_url** - This is the external URL that users will use to access Concourse.
- **SSL PEM** - Concourse requires an SSL certificate to be accessed using https. This should
  be a PEM file containing the SSL certificate + Private Key. The data will be stored in Vault
  under `secret/path/to/env/concourse/ssl:combined`.

#### github-oauth Params

- **OAuth Client ID** - The `client_id` provided by GitHub when creating the OAuth integration
  for Concourse. This will be stored in Vault at `secret/path/to/env/concourse/oauth:provider_key`
- **OAuth Client Secret** - The `client_secret` provided by GitHub when creating the OAuth integration
  for concourse. This will be stored in Vault at `secret/path/to/env/concourse/oauth:provider_secret`
- **params.authz_allowed_orgs** - A list of GitHub orgs whose users will be granted access to Concourse.

#### github-enterprise-oauth Params

- **params.github_api_uri** - the API URL for the GitHub Enterprise server that is used for OAuth.
  For example: `https://github.example.com/api/v3/`
- **params.github_token_uri** - the URL of the token API for the GitHub Enterprise server used for OAuth.
  For example: `https://github.example.com/login/oauth/access_token`
- **params.github_auth_url** - the URL of the Auth API for the GitHub Enterprise server used for OAuth.
  For example: `https://github.example.com/login/oauth/authorize`
- **OAuth Client ID** - The `client_id` provided by GitHub when creating the OAuth integration
  for Concourse. This will be stored in Vault at `secret/path/to/env/concourse/oauth:provider_key`
- **OAuth Client Secret** - The `client_secret` provided by GitHub when creating the OAuth integration
  for concourse. This will be stored in Vault at `secret/path/to/env/concourse/oauth:provider_secret`
- **params.authz_allowed_orgs** - A list of GitHub orgs whose users will be granted access to Concourse.

#### cf-oauth Params

- **params.cf_api_uri** - the API URL for the iCloud Foundry whose UAA will be used for authentication.
  For example: https://api.system.bosh-lite.com
- **params.cf_token_uri** - the URL of the token API for the UAA used for OAuth.
  For example: `https://login.system.bosh-lite.com/oauth/token
- **params.github_auth_url** - the URL of the Auth API for the UAA used for OAuth.
  For example: `https://login.system.bosh-lite.com/oauth/authorize`
- **OAuth Client ID** - The `client_id` of the UAA client being used to connect Concourse to the UAA
  for token validation/verification, and group membership retrieval during OAuth. This will be stored
  in Vault at `secret/path/to/env/concourse/oauth:provider_key`.
- **OAuth Client Secret** - The `client_secret` of the UAA client being used to connect Concourse to the UAA
  for token validation/verification, and group membership retrieval during OAuth. This will be stored
  in Vault at `secret/path/to/env/concourse/oauth:provider_secret`.
- **params.authz_allowed_groups** - A list of UAA groups whose users will be granted access to Concourse.

#### Shield Params

- **params.shield_key_vault_path** - A Vault path to the SHIELD daemon's public SSH key
  This is used to authenticate the SHIELD daemon to the agent, when running tasks.

  For example: `secret/us/proto/shield/agent:public`

#### workers-only Params

Note that the workers-only subkit actively _removes_ parts of the
Concourse deployment topology from the manifest, so a lot of the
above subkits don't work with it, and a some of the base
parameters (like `params.external_domain`) are no longer required.

- **tsa_host** - The IP address of the main Concourse's TSA
  instance.  This parameter is **required**.
- **tsa_port** - The TCP port that the workers should contact the
  main Concourse TSA node on.  Defaults to _2222_, which should
  suffice for most deployments.
- **tsa_key_path** - Where in the Vault can Genesis find the TSA
  host key, to allow the worker to safely connect to the TSA.
  This path is specified without the leading "secret/" path.
  Usually, this is something like "my/env/concourse/tsa/host_key".
  This parameter is **required**.
- **worker_key_path** - Where in the Vault can Genesis find the
  Concourse Worker key that is already trusted by the TSA?
  This path is specified without the leading "secret/" path.
  Usually, this is something like "my/env/concourse/tsa/worker_key".
  This parameter is **required**.

Cloud Config
------------

By default, this kit uses the following VM types/networks/disk pools from your
Cloud Config. Feel free to override them in your environment, if you would
rather they use entities already existing in your Cloud Foundry:

```
params:
  concourse_network:   concourse
  concourse_disk_pool: concourse # should be at least 10GB (used for the concourse DB)
  concourse_vm_type:   small # VMs should have at least 2 CPUs, and 4GB of memory
```

[1]: https://concourse.ci
[2]: https://github.com/starkandwayne/genesis
[3]: https://github.com/cloudfoundry-community/locker
[4]: https://github.com/cloudfoundry-community/locker-resource
[5]: https://github.com/cloudfoundry/uaa
