# Improvements

- The `availability_zones` param has a more intelligent default,
  so you no longer have to use the Spruce `(( replace ))` merge
  directive to overwrite it.  You still can, so your legacy
  z1-only environments should be fine.

- The new `worker_nodes` property allows operators to scale out
  the size of the Concourse by spinning up additional workers.

- This kit now supports setting HTTP/HTTPS proxy settings for each
  of the Garden containers that Concourse spins, via these new
  parameters:

    - `http_proxy` - URL of the proxy to use for HTTP requests.
    - `https_proxy` - URL of the proxy to use for HTTPS requests.
    - `no_proxy` - A list of IP addresses and names to skip
      proxying for

- Garden and Baggage Claim now forward their registration
  endpoints via their respective `forward_agent` properties, to
  make remote workers easier to implement.
