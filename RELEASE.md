# v6.0.0

This release fixes a critical security advisory in Concourse and bumps the concourse boshrelease from **8.2.2 to 8.3.4**. It is a major release because two changes since v5.1.0 break existing environments on upgrade, so please read the operator actions below before you deploy.

## Security fix

- **GHSA-9x27-gfq9-5qx8 (critical).** Concourse 8.3.3 and earlier derived the default OAuth client secrets for the web login flow and the worker gateway from public key data, so an attacker could work them out. Concourse 8.3.4 fixes the derivation upstream.

- The kit now also generates both client secrets itself as random 64-character values in Vault (`atc/client:secret` and `tsa/client:secret`) and passes them to the `web` job. With the secrets set explicitly, Concourse never falls back to a derived value.

## Concourse 8.2.2 to 8.3.4

- The 8.3.x line also carries the fixes for GHSA-fcx6-pj3r-frxv and GHSA-r298-g5jj-c9w4, along with Go, containerd, gRPC, go-jose, and golang.org/x/net security updates. Version 8.3.2 rebuilt every artifact without the compromised eMudhra CA certificates.

- The `web` job's pre-start script now runs the database migrations before the ATC starts.

- Concourse now chowns bind-mounted volumes when a task runs as a non-root user (8.3.0).

- go-jose now rejects RSA keys larger than 4096 bits, so OIDC logins fail when any key in the provider's key set is larger than that (8.3.3). Large hosted providers use 2048-bit keys, but self-hosted providers such as Keycloak deserve a check before you upgrade.

- A negative `concurrent_request_limits` value now stops the web node from starting, where it used to return 503 on that endpoint (8.3.3). Use `0` to disable an endpoint instead.

- The release adds new optional `web` properties such as `custom_http_headers`, `destroy_archived_pipelines_after`, `stalled_worker_timeout`, and `credhub.shared_path`, as well as a per-worker `max_active_tasks`. The kit does not set any of them.

## Breaking changes

- **The default stemcell is now `ubuntu-noble`.** It used to be `ubuntu-jammy`. An environment that does not set `stemcell_os` recreates every VM on noble at its next deploy, so upload the noble stemcell first, or set `stemcell_os: ubuntu-jammy` to stay where you are.

- **`authz_allowed_orgs` has been renamed to `github_allowed_orgs`, and it now takes a list.** The old name stops the deploy with an error that explains the rename. The `github_authz` parameter has been removed, because it never took effect in v5.1.0 and admitted the whole organization anyway. The kit no longer reads `params.github.orgs` either.

- **Genesis 3.1.0 or later is required.** The kit used to accept Genesis 2.7.6.

## New features

- **Proxmox VE support for OCFP.** The `ocfp` feature now runs on PVE, and it takes networks, disk types, and VM types from the OCFP vault config. PVE deployments always use the internal database.

- **Team-scoped GitHub OAuth.** Set `github_allowed_teams` to a list of `org:team` slugs, `github_allowed_orgs` to a list of organizations, or both. Local basic auth keeps working alongside GitHub.

- **An opt-in `resolute` feature.** The feature is for ubuntu-resolute stemcells, and it pins bpm 1.4.41, postgres-release 57.0.0 with PostgreSQL 16, locker 0.2.3, and haproxy 16.13.0+3.2.25. The feature is experimental. The manual explains the PostgreSQL collation refresh that a noble deployment needs when it moves to resolute with its data kept.

- **The `prometheus` feature now works under `ocfp`.** It uses a web-only addon with no HAProxy listener.

- **The `setup-approle` addon accepts `--yes`.** The flag skips its confirmation prompts, and the addon also detects an existing concourse mount and writes the AppRole roles natively.

## Fixes

- Workers now read the web deployment's TSA data from the configured exodus mount instead of a hard-coded `secret/exodus/` path, so a custom `secrets_mount` or `exodus_mount` works.

- The OCFP `full` overlays for AWS and STACKIT now set `workers` correctly. Those deployments used to ignore the worker count and get the default, and they now get 3 workers.

- The hooks resolve their Genesis library fallback path correctly.

## Operator actions

1. Run `genesis <env> add-secrets` on every existing environment before you deploy, which creates `atc/client` and `tsa/client`. The manifest cannot be built while those two secrets are missing.

2. Rename `authz_allowed_orgs` to `github_allowed_orgs` as a list, and remove `github_authz`.

3. Upload the ubuntu-noble stemcell, or pin `stemcell_os: ubuntu-jammy`.

4. Upgrade the Genesis CLI to 3.1.0 or later.

5. If you use OIDC with a self-hosted provider, check that none of its signing keys is larger than 4096 bits.
