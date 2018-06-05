# Improvements

This release is a substantial rewrite and re-envision, based on the kit
authoring improvements in Genesis v2.6.0.  While the base functionality
remains mostly unchanged, there are the following advancements:

## Add-ons

Genesis v2.6 adds Add-ons to make life easier when working with deployments.
For Concourse, this adds the following convenience commands:

* `genesis do $env -- visit` - Shows the login credentials needed for
  accessing the web user interface, then opens the site on your default
  browser (macOS only)

* `genesis do $env -- download-fly <opts>` - Downloads the `fly` cli
  executable for your platform to your current directory, or use `--sync`
  option to have it replace your current `fly` executable in your path.  See
  MANUAL.md for further options.

* `genesis do $env -- login` - Logs you into Concourse using fly, creating a
  fly target named the same as your environment if it doesn't exist.

* `genesis do $env -- logout` - Logs you out of Concourse using fly.

* `genesis do $env -- fly` - The penultimate addon for concourse.
  Automatically creates the fly target and logs you into fly if you're not
  already logged in, then runs the fly command against this Concourse.

If your `$env` is a worker-only deployment, automatically targets that
deployments host Concourse for a seamless integration.

## Info

Genesis v2.6 aslo adds an info command, which shows the credentials for full
deployments, and worker tags for worker-only deployments.

## Adds new, blueprint, check and post-deploy hooks

Better control over creation and deployment processes using the new Genesis
v2.6 hooks.

## Improved Documentation:

The new MANUAL.md file contains all the features and parameters used by this
kit, as well as all the add-ons and example environment files.

# BREAKING CHANGE

There is one minor breaking change moving to 2.0.0.  You need to specify that
the environment is a full deploy (feature: full) or a worker-only deploy
(feature: workers).

