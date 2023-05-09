Concourse Genesis Kit
=====================

This is a Genesis Kit for the [Concourse CI/CD System][1]. It will
deploy a fully functional Concourse environment for use pipelining
BOSH deployments managed by [Genesis][2], and any CI/CD tasks you
want to throw at it.

By default, this Concourse deployment includes the [locker API][3]
colocated along the Concourse database, so that the [locker-resource][4]
portions of the Genesis deployment pipelines will work. It is general
purpose enough to use as a locking system for any other Concourse jobs,
should you wish to make use of it.

Quick Start
-----------

To use it, you don't even need to clone this repository!  Just run
the following (using Genesis v2.6 or later):

```
# create a concourse-deployments repo using the latest version of the concourse kit
genesis init --kit concourse

# create a concourse-deployments repo using v1.0.0 of the concourse kit
genesis init --kit concourse/1.0.0

# create a my-concourse-configs repo using the latest version of the concourse kit
genesis init --kit concourse -d my-concourse-configs
```

Learn More
----------

For more in-depth documentation, check out the [manual][5].

[1]: https://concourse.ci
[2]: https://github.com/genesis-community/genesis
[3]: https://github.com/cloudfoundry-community/locker
[4]: https://github.com/cloudfoundry-community/locker-resource
[5]: MANUAL.md
