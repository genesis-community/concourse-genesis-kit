# Concourse Genesis Kit Manual

The *Concourse Genesis Kit* deploys a Concourse CI/CD system under BOSH using
Genesis v2.6.0 or later.  It supports the following features and parameteters:



## Features

### Full vs. Worker-only Deployments

Concourse can either be deployed as a full deployment (feature: `full`) or as a
worker-only (feature: `worker`) deploment as a satellite to another full host
deployment.

You will need at least one full deployment for a Concourse setup.  This will
provide the HAProxy load balancer in front of one or more web nodes that house
the web user interface and the API endpoint for the `fly` CLI as well as the
control system that schedules jobs to the workers.  It will also provide the
database for Concourse and one set of workers (typically 3, but this is
configurable.)

You may also need to have one or more worker-only deployments that tie into
the full deployment.  This allows you to have workers within a partitioned
network so that the workers can perform tasks that are only permitted within
that network, such as deployments.  These workers are allowed to call out to
the scheduler on the host web node to request jobs and submit results.  Jobs
are managed for these separate worker clusters by associating the pipeline and
the workers with tags to route the jobs to the required workers.

### Authentication

By default, the web user interface and the fly CLI command authenticate using
a single basic authentication username/password on the **main** team.  However
there are several other authentication features for the **main** team:

#### GitHub OAuth Integration

The `github-oauth` feature allows you to specify a GitHub.com organization for
which any member can log into Concourse.

#### GitHub Enterprise OAuth Integration

The `github-enterprise-oauth` feature provides the same functionality as the
GitHub OAuth integration, but for an on-prem GitHub Enterprise system.

#### CF UAA OAuth IntegrationL

The `cf-oauth` fature allows you to use your Cloud Foundry UAA as the authentication source for
accessing Concourse.


### Self-signed vs CA-signed SSL Certificates

Concourse web and `fly` urls run over HTTPS by default, and as such, uses an
SSL certificate and key. You can provide your own CA-signed certificate
(feature: `provide-cert`) or have Genesis generate a self-signed certificate
(feature: `self-signed-cert`).  If you chose the latter, you will need to
add an exception on your browser when asked, and use the --skip-ssl-validation
option when logging in with `fly` if you do this manually instead of using the
`login` addon (see below)



## Parameters

### Base Parameters

These parameters apply to the base configuration of Concourse.  With exception
of those directly asked for in the `new` wizard, they all have functional
defaults but can be modified in your environment YAML file.

- `concourse_network` - The name of the network you wish to use as specified
  in your cloud config.  Defaults to `concourse`.

- `concourse_vm_type` - The name of the vm type to be used for all the
  non-worker vms (web, haproxy, db).  Defaults to `small`.

- `worker_vm_type` - The name of the vm type to be used by the concourse
  worker.  This typically needs more memory and diskspace than the rest of the
  concourse vms, and is recommended that it provides at least 8GB of RAM and
  60GB of disk.

- `stemcell_os` - This is kit is tested with Ubuntu 14.04 "Trusty" stemcells
  and we recommend against changing this from the default value of
  'ubuntu-trusty', but if you do have special needs, you can change this here.

- `stemcell_version` - By default, this is set to `latest`, but if you need to
  lock to a specific version of the stemcell, set this value.

- `volume_driver` - Specify Concourse's volume driver, defaults to 'detect'.
  If you're planning to change this, you should already know what value you
  should use and why, otherwise, don't touch this.

- `workers` - This is the number of worker instances you want to have.
  Defaults to '3'

- `availability_zones` - List of availability zone names. By default, we
  recommend deploying across three availability zones [z1, z2 and z3]  for any
  instance groups that have multiple vms (workers, possibly web).  However
  some systems don't have multiple availability zones or you may want to
  restrict or expand your availabilty zones manually.

- `http_proxy` - The address for the HTTP traffic proxy.  By default, there is
  no proxy.

- `https_proxy` - The address for the HTTPS traffic proxy.  By default, there is
  no proxy.

- `no_proxy` - The list of addresses that are not proxied through the above
  proxies.  Each address must be specified; this does not accept CIDR
  representation.


### Full Deployment Parameters

- `external_domain` - The full domain (or IP address) of the Concourse haproxy
  vm.  This must be specified and is prompted for in the `genesis new` wizard.

- `external_url` - This is the full url, including schema, for the Concourse
  web user interface.  By default it is the external\_domain over https.

- `main_user` - The name of the user in the `main` team to log in as for the
  Web user interface and `fly`.  Defaults to `concourse`.

- `num_web_nodes` - Number of web nodes, typically 1, but can be up to 5.

- `haproxy_vm_type` - The `vm_type` to use for haproxy VMs, if you are
  deploying those.  Defaults to whatever `concourse_vm_type` has been set
  to.

- `web_vm_type` - The `vm_type` to use for web (TSA / ATC) nodes.  Defaults to
  whatever `concourse_vm_type` has been set to.

- `db_vm_type` - The `vm_type` to use for the database node.  Defaults to
  whatever `concourse_vm_type` has been set to.

- `concourse_disk_type` - Persistent disk type used by the Concourse DB VM.

-  `token_signing_key.public_key` and
-  `token_signing_key.private_key` - These are the keys used by the tca and atc.

### Worker-only Deployment Parameters

- `tsa_host_env` - The Genesis deployment environment name that will act as
  host to this worker-only deployment.  Note that this host environment must
  have been deployed by using Genesis v2.6 or later, and using v1.6.0 of this kit.

- `tags` - A list of tags to associate with this worker pool.  Tags are used
  to displatch tagged pipeline jobs to the appropriate pool of workers.  If
  you're using Genesis generated deployment pipelines, this should work
  without modification: By default, it will be a single tag matching the
  environment name.  If you want no tags, specify `tags` as an empty list.

  *Note*: tags cannot contain spaces in their name.

#### github-oauth Params

- `authz_allowed_orgs` - The name of the organization in Github authorized to
  use Concourse.  For legacy reasons, it retains a pluralization of its name,
  but only allows a single organization due to changes in Concourse.

#### github-enterprise-oauth Params

- `github_api_uri` - The API URL for the GitHub Enterprise server that is used
  for OAuth.  For example: `https://github.example.com/api/v3/`

- `github_token_uri` - The URL of the token API for the GitHub Enterprise server
  used for OAuth.  For example:  `https://github.example.com/login/oauth/access_token`

- `github_auth_url` - The URL of the Auth API for the GitHub Enterprise server
  used for OAuth.  For example:  `https://github.example.com/login/oauth/authorize`

- `authz_allowed_orgs` - The name of the organization in Github authorized to
  use Concourse.  For legacy reasons, it retains a pluralization of its name,
  but only allows a single organization due to changes in Concourse.

#### cf-oauth Params

- `cf_api_uri` - The API URL for the iCloud Foundry whose UAA will be used for
  authentication.  For example: https://api.system.bosh-lite.com

- `cf_token_uri` - The URL of the token API for the UAA used for OAuth.  For
  example: `https://login.system.bosh-lite.com/oauth/token`

- `github_auth_url` - The URL of the Auth API for the UAA used for OAuth.  For
  example: `https://login.system.bosh-lite.com/oauth/authorize`

- `cf_ca_cert_vault_path` - The Vault path that contains ca for the Cloud Foundry

- `cf_spaces` - A list of CF space GUIDs whose developers can access Concourse



## Cloud Config

By default, this kit uses the following VM types/networks/disk pools from your
Cloud Config. Feel free to override them in your environment, if you would
rather they use entities already existing in your Cloud Foundry:

```
params:
  concourse_network:   concourse
  concourse_disk_pool: concourse # should be at least 10GB (used for the concourse DB)
  concourse_vm_type:   small # VMs should have at least 2 CPUs, and 4GB of memory
  worker_vm_type:      concourse-worker # VMs should have 8GB of memory and 60GB of disk.
```



## Available Add-ons

* `visit` - Opens the Concourse Web user interface in your browser (requires
  macOS)

* `download-fly` - Downloads the version of the `fly` cli compatible with the
  deployed version of Concourse.  With no argumements will place the `fly`
  executable in your current directory.  Supports the following arguments:

  `<path>`: instead of placing the executable in the current directory, store
  it under the specified `<path>`.

  `--sync`: instead of placing the executable in the current directory, it
  replaces the `fly` command found in your path.  You must have write-access
  to that location for this to succeed.

  `-p <platform>`: explicitly state the platform to use instead of relying on
  the detected platform.  Expects `<platform>` to be one of `darwin`|`mac`,
  `cygwin`|`windows`|`win`, or `linux`.  **Note:** if you're using fly in the Bash
  Shell under Windows 10, specify `linux` as your platform.

* `login` - Authenticates your `fly` CLI to this Concourse deployment,
  creating the `fly` target if necessary, using the same name as this
  environment.  If you used a self-signed certificate, it will use the
  `--skip-ssl-validation` flag automatically.

* `logout` - Will recind the authentication token for this target.

* `fly <cmd> <args...>` - Issue a fly command to this Concourse without
  needing to specify the `-t <target>` argument.  It will even log you in if
  you're not logged in already.



### Examples

To deploy a host Concourse with self-signed certificate, with load-balanced
web nodes and two medium workers in a single availability zone.

```
---
kit:
  name:    concourse
  version: 1.6.0
  features:
  ⦙ - (( replace ))
  ⦙ - full
  ⦙ - self-signed-cert

params:
  env:   mycorp-proto
  vault: mycorp/proto/concourse
  external_domain: 10.200.193.16
  num_web_nodes: 2
  worker_count: 2

  availability_zones: [z1]
  worker_vm_type: medium
```

To deploy a worker pool for an isolated production environment that is hosted
by the above deployment, with bigger workers and more of them:

```
---
kit:
  name:    concourse
  version: 1.6.0
  features:
  ⦙ - (( replace ))
  ⦙ - workers

params:
  env:   mycorp-us-east-prod
  vault: mycorp/us/east/prod/concourse
  tsa_host_env: mycorp-proto
  worker_count: 6
  tags:
    - mycorp-us-east-prod
    - alternative-tag

  availability_zones: [z1]
  worker_vm_type: large
```



