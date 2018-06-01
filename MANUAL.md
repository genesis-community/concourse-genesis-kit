# Concourse Genesis Kit Manual

The *Concourse Genesis Kit* deploys a Concourse CI/CD system under BOSH using
Genesis v2.6.0 or later.  It supports the following features and parameteters:

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
  have been deployed by using Genesis v2.6 or later, and using v2.0 of this kit.


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
=======

