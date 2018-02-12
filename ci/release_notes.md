# Improvements

- The `availability_zones` param has a more intelligent default,
  so you no longer have to use the Spruce `(( replace ))` merge
  directive to overwrite it.  You still can, so your legacy
  z1-only environments should be fine.

- The new `worker_nodes` property allows operators to scale out
  the size of the Concourse by spinning up additional workers.
