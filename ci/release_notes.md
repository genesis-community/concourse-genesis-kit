# Improvements

- New `github_authz` parameter allows you to set fine-grained
  access control on Github OAuth2 configuration (enterprise or
  github.com).  Fixes #21.

- Remove prompts for sizing (worker counts and web node counts).
  Fewer questions == more happy!

- New `no-tls` feature makes it possible to deploy Concourse with
  TLS terminated elsewhere (i.e. haproxy, a load balancer, etc.).


# Bug Fixes

- Remote `meta.vault` definitions from the kit.  Genesis now
  provides that key, so the kit doesn't have to.

- Fixed a typo in the `gargen` property (should have been `garden),
  which lead to a series of fun exchanges of "RELEASE THE GARGEN!"
  here in the engineering team, but was otherwise harmless.

- Remove errant trailing slashes in the `new` hook that made it
  impossible to properly select Github OAuth2 configurations
  during a `genesis new`.
