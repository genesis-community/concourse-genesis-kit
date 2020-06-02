# New Features

* `no-haproxy` - Don't deploy an haproxy node in front of the web nodes
* `dynamic-web-ip` - Don't deploy the web nodes to a static IP, and instead rely
  on a vm extension to map to a loadbalancer.
* `external-db` - Don't deploy a local PostgreSQL, and instead configure parameters
  to use an external PostgreSQL database.

# Core Components

| Release | Version | Release Date |
| ------- | ------- | ------------ | 
| Concourse | [6.1.0](https://github.com/concourse/concourse-bosh-release/releases/tag/v6.1.0) | May 12, 2020 |
| Postgres | [41](https://github.com/cloudfoundry/postgres-release/releases/tag/v41) | Feb 18, 2020 |
| bpm | [1.1.8](https://github.com/cloudfoundry/bpm-release/releases/tag/v1.1.8) | Mar 22, 2020 |
| Slack Notification Resource | [9](https://github.com/cloudfoundry-community-attic/slack-notification-resource-boshrelease/releases/tag/v9) | Feb 19, 2016 |
| Shout | [0.1.0](https://github.com/jhunt/shout-boshrelease/releases/tag/v0.1.0) | Sep 3, 2018 |
| Locker | [0.2.1](https://github.com/cloudfoundry-community/locker-boshrelease/releases/tag/v0.2.1) | May 31, 2017 |
| HAProxy | [10.1.0](https://github.com/cloudfoundry-incubator/haproxy-boshrelease/releases/tag/v10.1.0) | Apr 26, 2020 |