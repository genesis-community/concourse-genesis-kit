# Improvements

- The `availability_zones` param has a more intelligent default,
  so you no longer have to use the Spruce `(( replace ))` merge
  directive to overwrite it.  You still can, so your legacy
  z1-only environments should be fine.
