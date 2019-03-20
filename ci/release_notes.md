# Release Changes

* Bumped Concourse to 4.2.3
* Bumped Garden RunC to 1.18.3
* Bumped Postgres to 31

# Upgrading (IMPORTANT)

Hey! If you're not careful, you can break your Concourse during this upgrade!
Read this: [GMP-CONCOURSE-0001](https://genesisproject.io/docs/migrations/gmp-concourse-0001/)

As additional notes, you'll likely need to run `genesis add secrets` before
deploying so that Genesis can generate a bcrypt of your existing password.

# Bug Fixes

In the last release, there was a regression where you couldn't directly
override properties of jobs in the manifest. It's fixed now.

# Core Components

| Release | Version | Release Date |
| ------- | ------- | ------------ | 
| Concourse | [4.2.3](https://github.com/concourse/concourse-bosh-release/releases/tag/v4.2.3) | Feb 25, 2019 |
| Garden RunC | [1.18.3](https://github.com/cloudfoundry/garden-runc-release/releases/tag/v1.18.3) | Feb 18, 2019 |
| Postgres | [31](https://github.com/cloudfoundry/postgres-release/releases/tag/v31) | Nov 19, 2018 |
| Slack Notification Resource | [9](https://github.com/cloudfoundry-community-attic/slack-notification-resource-boshrelease/releases/tag/v9) | Feb 19, 2016 |
| Shout | [0.1.0](https://github.com/jhunt/shout-boshrelease/releases/tag/v0.1.0) | Sep 3, 2018 |
| Locker | [0.2.1](https://github.com/cloudfoundry-community/locker-boshrelease/releases/tag/v0.2.1) | May 31, 2017 |
| HAProxy | [8.4.2](https://github.com/cloudfoundry-incubator/haproxy-boshrelease/releases/tag/v8.4.2) | Oct 29, 2017 |
