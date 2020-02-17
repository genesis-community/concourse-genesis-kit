# Concourse Genesis Kit Manual

The **Concourse Genesis Kit** deploys a Concourse CI/CD system.
It supports _full_ Concourses, which contain all of the components (web,
database, and workers), as well as _workers-only_ Concourses, for remote
satellite sites.

# Base Parameters

- `volume_driver` - The garden/runc volume driver to use.  Defaults to
  `detect`, which is usually what you want, unless you know otherwise.

## Sizing and Deployment Parameters

- `concourse_network` - The name of the network you wish to use as specified
  in your cloud config.  Defaults to `concourse`.

- `concourse_vm_type` - The name of the vm type to be used for all the
  non-worker vms (web, haproxy, db).  Defaults to `small`.

- `worker_vm_type` - The name of the vm type to be used by workers.  This
  typically needs more memory and disk than other VMs; we recommend at least
  8GB of RAM and 60GB of disk.  Defaults to `concourse-worker`.

- `haproxy_vm_type` - The name of the vm type to be used for the haproxy
  load balancer that sits in front of the web nodes.  Defaults to the value
  of `concourse_vm_type`.

- `num_web_nodes` - How many web nodes to deploy.  Defaults to 1, but can be
  scaled up to 5.

- `web_vm_type` - The name of the vm type to be used for the web (ATC)
  nodes. Defaults to the value of `concourse_vm_type`.

- `db_vm_type` - The name of the vm type to be used for the database node.
  Defaults to the value of `concourse_vm_type`.

- `concourse_disk_type` - What type of persistent disk (per cloud config) to
  deploy for the database node.  Defaults to `concourse`.

- `availability_zones` - What BOSH HA availability zones to deploy Concourse
  across.  The chosen network must have at least one subnet in each of the
  listed zones, and the zones themselves must be defined in your cloud
  config.  Defaults to `z1`, `z2`, and `z3`.

- `stemcell_os` - The operating system you want to deploy Concourse on.
  This defaults to `ubuntu-xenial`.

- `stemcell_version` - The version of the stemcell to deploy.
  Defaults to `latest`, which is usually what you want.

- `workers` - How many workers to deploy.  Defaults to `3`

## HTTP(S) Proxy Parameters

- `http_proxy` - (Optional) URL of an HTTP proxy to use for any
  outbound HTTP (non-TLS) communication.

- `https_proxy` - (Optional) URL of an HTTP proxy to use for any
  outbound HTTPS (TLS) communication.

- `no_proxy` - A list of IPs, FQDNs, partial domains, etc. to
  skip the proxy and connect to directly.  This has no effect if
  the `http_proxy` and `https_proxy` are not set.

# Deploying A Full Concourse

A _full_ Concourse includes all of the components of the Concourse CI/CD
system, including workers, the database, the TSA worker coordination
node(s), and frontend web UI / API node(s).  You generally need exactly one
of these.

To deploy a full Concourse, specify the `full` feature, and provide
the following configuration parameters:

- `external_domain` - The fully-qualified domain name, or IP address, for
  Concourse.  This is used for redirection, and is **required**.

- `external_url` - The full HTTP(S) URL for this Concourse.  By default,
  this will be constructed from the chosen `external_domain`.

## Shout! A Programmable Notification Gateway

If you want to handle notification with some style, enable the
`shout` addon, and specify your Shout! rules in the `shout_rules`
parameter.

For details on why and how to do this, see the [Shout!][shout]
documentation.

[shout]: https://github.com/jhunt/shout/blob/master/README.md

The Shout! server will be accessible to your Concourse pipelines,
on port 7109, at the first web node.

## Prometheus Integration

To expose a Prometheus exporter endpoint in Concourse, enable
the `prometheus` addon. This only works if you're deploying a
`full` Concourse.

Parameters:

- `prometheus_metrics_port`: The port to listen for metrics on. Defaults to
	9391.

## HTTP Basic Authentication (Default)

Out of the box, Concourse uses HTTP Basic Authentication, assigning a single
user to the `main` team.

The following parameters apply to this authentication method:

- `main_user` - Username of the default administrator account, which will
  belong to the `main` team.

The following secrets will be pulled from the vault:

- **Basic Authentication Pasword** - The password used in basic
  authentication, for the user interface and the `fly` command.
  Genesis generates this (randomized) password.  It is stored in
  the vault, at `secret/$env/concourse/webui`

## Github OAuth2-based Authentication

Concourse can authenticate against a Github OAuth2 application, either on
public Github (github.com) or an enterprise, on-premise Github installation.

To hook up to public Github, enable the `github-oauth` feature flag, and
provide the following parameters:

  - `authz_allowed_orgs` - What Github organization to authenticate.
    For legacy reasons, it retains a pluralization of its name, but only
    allows a single organization.  This parameter is **required**.

  - `github_authz` - A list of authorizations to determine who is
    allowed to authenticate. This supersedes `authz_allowed_orgs`,
    and lets you grant individual teams and users access,
    regardless of their org memberships.

The following secrets will be pulled from the vault:

  - **Oauth2 Client ID and Secret** - The Client ID and secret of the Github
    OAuth2 application to use.
    This is stored in the vault, at `secret/$env/concourse/oauth`

To hook up to an Enterprise Github installation, enable the
`github-enterprise-oauth` feature flag, and provide the following
parameters (above and beyond those required by `github-oauth`):

  - `github_host` - Domain of the Github Enterprise installation; something like
    `github.example.com`. No scheme, no trailing slash. This parameter is
    **required**.

## Cloud Foundry UAA OAuth2-based Authentication

To use your Cloud Foundry UAA server to authenticate Concourse users, enable
the `cf-oauth` feature flag, and provide the following parameters:

  - `cf_api_uri` - The Cloud Foundry API URL.  This will be used for
    enumerating org / space memberships, inside of Cloud Foundry.
    For example: `https://api.sys.your-cf.com`.
    This parameter is **required**.

  - `cf_spaces` - A list of Cloud Foundry spaces in the form `ORG:SPACE`.
    Developers in those spaces will be given access to Concourse. This
    parameter is **required**.

  - `cf_ca_cert_vault_path` - The path, in the Vault, to the Cloud Foundry
    CA certificate. This is usually something like
    `secret/path/to/keys/for/haproxy/ssl:certificate`
    This parameter is **required**.

The following secrets will be pulled from the vault:

  - **Oauth2 Client ID and Secret** - The Client ID and secret of the Cloud
    Foundry UAA Client to authenticate with.
    This is stored in the vault, at `secret/$env/concourse/oauth`


## X.509 Certificates

Normally, Concourse is configured with an X.509 Certificate, and forces all
traffic over HTTPS, for security reasons.

If you don't have a certificate, but still want to run TLS, activate the
`self-signed-cert` feature flag, and Genesis will generate an appropriate
certificate for you.

If you want to provide your own certificate, enable the `provided-cert`
flag, and store the certificate in the vault, at the following locations:

  - `secret/$env/concourse/ssl/server:certificate` - The public certificate,
    PEM-encoded.
  - `secret/$env/concourse/ssl/server:key` - The private RSA key,
    PEM-encoded.

If you don't want to run TLS locally (i.e. if you have a reverse proxy out
in front) you can activate the `no-tls` feature flag.

# Deploying a Satellite Concourse

A _satellite_ Concourse consists solely of remote workers, which connect
into the TSA on a full Concourse.  These workers will be tagged so that
pipelines can run specific tasks on them.

To deploy a satellite Concourse, specify the `workers` feature, and provide
the following configuration parameters:

  - `tsa_host_env` - The name of the Genesis environment to register this
    satellite Concourse to.

  - `tags` - The list of tags to apply to the workers in this satellite
    Concourse.  By default, the environment name is applied as the sole tag.
    Tags cannot contain interior whitespace.


# Deploying a Smaller Footprint Concourse

A _small footprint_ Concourse consists of placing all non-worker software into
a single VM. This is useful for low-traffic, low-concurrent-tasks deployments
and operators wish to save on resources. Workers still remain as separate VMs.

To enable this feature, specify the `small-footprint` feature instead of `full`

A `small-footprint` deployment cannot be scaled up to a full-size deployment,
or vice-versa. Any feature flags that work on the `full` deployment will work
on `small-footprint` deployment.

# Setting Up Vault Integration For Pipelines

The ATC can be configured to pull credentials for pipeline configurations using
Vault. The pipelines can specify properties wrapped in double parentheses to
pull these credentials dynamically from that Vault. For more information, see
https://concourse-ci.org/creds.html.

To add this functionality, specify the `vault` feature and provide the
following configuration parameters.

  - `vault_url` - The URL of the Vault api to contact

  - `vault_path_prefix` - The path prefix to look for paths
  under. For example, if `((example))` is given in a pipeline
  definition, it would look at `<vault_path_prefix>/example`
  in the vault. Defaults to `/concourse`.

  - `vault_insecure_skip_verify` - Whether to skip validation of
  the cert presented by the Vault API. Defaults to `false`

  - `vault_token` - The token to present as authentication to the Vault API.

# Cloud Configuration

By default, Concourse uses the following VM types/networks from your cloud
config.  Feel free to override them in your environment, if you would rather
they use entities already existing in your cloud config:

```
params:
  concourse_network:   concourse
  concourse_vm_type:   concourse          # at least 2 CPUs / 4GB RAM
  concourse_disk_type: concourse          # at least 10GB (for the db)
  worker_vm_type:      concourse-worker   # at least 8GB RAM / 60GB disk
```


# Available Add-ons

- `visit` - Opens the Concourse Web user interface in your browser (requires
  macOS)

- `download-fly` - Downloads the version of the `fly` cli compatible with the
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

- `login` - Authenticates your `fly` CLI to this Concourse deployment,
  creating the `fly` target if necessary, using the same name as this
  environment.  If you used a self-signed certificate, it will use the
  `--skip-ssl-validation` flag automatically.

- `logout` - Will recind the authentication token for this target.

- `fly <cmd> <args...>` - Issue a fly command to this Concourse without
  needing to specify the `-t <target>` argument.  It will even log you in if
  you're not logged in already.


# Examples

To deploy a host Concourse with self-signed certificate, with load-balanced
web nodes and two medium workers in a single availability zone.

```
---
kit:
  name:    concourse
  version: 2.0.0
  features:
    - full
    - self-signed-cert

params:
  env: us-east1-prod

  external_domain: ci.example.com
  num_web_nodes:   2

  worker_vm_type:  medium
  worker_count:    2

  availability_zones: [z1]
```

To deploy a worker pool for an isolated production environment that is hosted
by the above deployment, with bigger workers and more of them:

```
---
kit:
  name:    concourse
  version: 2.0.0
  features:
    - workers

params:
  env: us-west1-prod

  tsa_host_env: us-east1-prod

  worker_vm_type: large
  worker_count:   6

  tags:
    - us-west1-prod
    - alternative-tag

  availability_zones: [z1]
```


## History

2.0.0 was the first version to support Genesis 2.6 hooks and exodus data
for addon scripts and `genesis info`.

2.1.0 added parameters for fine-grain control of GitHub OAuth2 config, added
`no-tls` feature to disable HTTPS, and some bug fixes.

2.2.0 upgraded Concourse to 3.14.1 and Garden to 1.14.0, as well as adding
Vault feature, which can hook up an externally deployed Vault to the ATC
for credential storage.

2.3.0 added an addon command to setup an AppRole and policy for Genesis
Concourse deployments. Also added Shout! support.

2.3.1 added a `small-footprint` feature to place all non-worker software
on a single VM.
