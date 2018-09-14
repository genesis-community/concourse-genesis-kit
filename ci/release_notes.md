# Improvements

- New `shout` feature for enabling a centralized notifications
  gateway for pipelines.

- Added a `setup-approle` addon that allows operators to 
  easily generate a new AppRole and policy for use with the 
  Concourse pipelines Genesis can generate.

# Bug Fixes

- The `check` hook for this kit now takes into account things like
  "this is not Vault" and "satellite concourses don't need
  cloud-config for a full concourse".

- The `post-deploy` hook was not correctly detecting the `workers`
  feature and was subsequently messaging that a Full Concourse had
  been deployed.  This has been fixed.
