# Improve setup-approle addon

* Add pre-emptive removal of previous `genesis-pipelines` app role
* Add notification updates as app role generation progresses
* Fix errors and debugging code left in `safe_kv_mounts`
* Fix errors occurring on newer versions of Vault when
  `auth/approle/role/genesis-pipelines` gets written to a second time.
