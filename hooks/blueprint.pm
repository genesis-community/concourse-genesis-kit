#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Blueprint::Concourse v2.7.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{files} = [];
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Base files that are always included
  $self->add_files(
    "manifests/concourse/base.yml",
    "manifests/releases/concourse.yml",
    "manifests/releases/slack-notifications.yml",
    "manifests/concourse/jobs.yml"
  );

  # Track operations files separately for OCFP feature
  my @opsfiles = ();

  # Check for custom ops files in the deployment
  for my $feature ($self->features) {
    if ($feature =~ /^(azure|shield|workers|full|small-footprint|no-tls|provided-cert|self-signed-cert|github-oauth|github-enterprise-oauth|cf-oauth|vault|vault-approle|shout|prometheus|no-haproxy|dynamic-web-ip|external-db|external-db-ca|ocfp|okta|aws|\+internal-db|\+locker|\+vault-token-default|\+vault-approle-default)$/) {
      # These are standard features handled below
    } elsif (-f $self->env->path("ops/$feature.yml")) {
      if ($self->want_feature('ocfp')) {
        push @opsfiles, $self->env->path("ops/$feature.yml");
      } else {
        $self->add_files($self->env->path("ops/$feature.yml"));
      }
    } else {
      bail("The #c{%s} feature is invalid. See MANUAL.md for list of valid features.", $feature);
    }
  }

  # Handle CPI-specific features
  if ($self->bosh_cpi() eq "azure") {
    $self->add_files("manifests/addons/azure.yml");
  }

  # Make sure only one of the major feature flags is set
  my $maj_feat = 0;
  $maj_feat++ if $self->want_feature("ocfp");
  $maj_feat++ if $self->want_feature("full");
  $maj_feat++ if $self->want_feature("workers");
  $maj_feat++ if $self->want_feature("small-footprint");

  if ($maj_feat != 1) {
    bail("Can only have one of 'ocfp', 'full', workers', or 'small-footprint' as a feature.");
  }

  if ($self->want_feature("ocfp")) {
    # Enforce the 'full' feature, using OCFP vars
    $self->add_files(
      "manifests/concourse/full.yml",
      "manifests/releases/postgres.yml",
      "manifests/releases/locker.yml",
      "manifests/releases/haproxy.yml",
      "manifests/releases/bpm.yml"
    );

    $self->_handle_tls_features();
    $self->_handle_okta_feature();

    # OCFP enforces the 'no-haproxy' feature
    $self->add_files("manifests/addons/no-haproxy.yml");

    # OCFP vars overrides
    $self->add_files("ocfp/full-concourse-vars-override.yml");

    # 'vault' feature, using OCFP vars
    $self->add_files(
      "manifests/addons/vault.yml",
      "manifests/addons/vault-approle.yml",
      "ocfp/vault-vars-override.yml"
    );

    # 'external-db' & 'external-db-ca' features, using OCFP vars
    $self->add_files(
      "manifests/addons/external-db.yml",
      "manifests/addons/external-db-ca.yml",
      "ocfp/external-db-vars-override.yml"
    );

    $self->add_files("ocfp/ocfp.yml");

    if ($self->want_feature("aws")) {
      $self->add_files("ocfp/iaas/aws.yml");
    } elsif ($self->want_feature("azure") || $self->want_feature("gcp") || $self->want_feature("vsphere")) {
      bail("#R{[ERROR]} The #c{azure}, #c{gcp} or #c{vsphere} features are not supported.");
    }
  } elsif ($self->want_feature("full") || $self->want_feature("small-footprint")) {
    if ($self->want_feature("full")) {
      $self->add_files(
        "manifests/concourse/full.yml",
        "manifests/releases/postgres.yml",
        "manifests/releases/locker.yml",
        "manifests/releases/haproxy.yml",
        "manifests/releases/bpm.yml"
      );
    }

    if ($self->want_feature("small-footprint")) {
      $self->add_files(
        "manifests/concourse/small-footprint.yml",
        "manifests/releases/postgres.yml",
        "manifests/releases/locker.yml",
        "manifests/releases/bpm.yml"
      );
    }

    # Handle OAuth options
    for my $oauth ("github-oauth", "cf-oauth") {
      if ($self->want_feature($oauth)) {
        $self->add_files("manifests/oauth/$oauth.yml");
      }
    }

    if ($self->want_feature("github-enterprise-oauth")) {
      # github enterprise oauth just adds the host param to github oauth
      if (!$self->want_feature("github-oauth")) {
        $self->add_files("manifests/oauth/github-oauth.yml");
      }
      $self->add_files("manifests/oauth/github-enterprise-oauth.yml");
    }

    $self->_handle_tls_features();
    $self->_handle_okta_feature();

    if ($self->want_feature("external-db")) {
      $self->add_files("manifests/addons/external-db.yml");

      if ($self->want_feature("external-db-ca")) {
        $self->add_files("manifests/addons/external-db-ca.yml");
      }

      if ($self->want_feature("small-footprint")) {
        $self->add_files("manifests/addons/external-db-small.yml");
      }
    }

    if ($self->want_feature("vault")) {
      $self->add_files("manifests/addons/vault.yml");
    }

    if ($self->want_feature("vault-approle")) {
      if (!$self->want_feature("vault")) {
        bail("Cannot use 'vault-approle' feature without 'vault' feature");
      }
      $self->add_files("manifests/addons/vault-approle.yml");
    }

    if ($self->want_feature("shout")) {
      $self->add_files(
        "manifests/addons/shout.yml",
        "manifests/releases/shout.yml"
      );
    }

    if ($self->want_feature("prometheus")) {
      if ($self->want_feature("small-footprint")) {
        $self->add_files("manifests/addons/prometheus-small-footprint.yml");
      } else {
        $self->add_files("manifests/addons/prometheus.yml");
      }
    }

    if ($self->want_feature("no-haproxy") && !$self->want_feature("small-footprint")) {
      $self->add_files("manifests/addons/no-haproxy.yml");

      if ($self->want_feature("dynamic-web-ip")) {
        $self->add_files("manifests/addons/dynamic-web.yml");
      }
    }

    my $max_builds = $self->env->lookup("params.max_builds_to_retain", "0");
    if ($max_builds =~ /^\d+$/ && $max_builds > 0) {
      $self->add_files("manifests/addons/maximum-builds-retention.yml");
    }
  } elsif ($self->want_feature("workers")) {
    $self->add_files("manifests/concourse/workers.yml");

    # Show warnings for incompatible features
    for my $feature (qw(provided-cert self-signed-cert github-oauth github-enterprise-oauth cf-oauth vault vault-approle)) {
      if ($self->want_feature($feature)) {
        $self->env->notify("#Y{[WARNING]} $feature feature has no effect on worker-only deployment, and will be ignored");
      }
    }
  } else {
    bail("Concourse needs to be configured as 'full' or 'workers'. If upgrading,".
         "\nplease add 'full' to your environment's list of features");
  }

  # Show warnings for deprecated features
  if ($self->want_feature("shield")) {
    $self->env->notify("#Y{[WARNING]} The 'shield' feature is no longer supported. Instead, please add the".
                        "\nshield agent to your runtime configuration.");
  }

  if ($self->want_feature("azure")) {
    $self->env->notify("#Y{[WARNING]} The 'azure' feature is no longer necessary - azure CPI will be detected".
                        "\nautomatically at deployment time.");
  }

  # Add any ops files last if using OCFP
  if (@opsfiles) {
    for my $ops (@opsfiles) {
      $self->add_files($ops);
    }
  }

  return $self->done(1);
}

sub _handle_tls_features {
  my ($self) = @_;

  if (!$self->want_feature("no-tls")) {
    $self->add_files("manifests/concourse/tls.yml");

    if ($self->want_feature("self-signed-cert")) {
      $self->add_files("manifests/addons/self-signed.yml");
    } elsif (!$self->want_feature("provided-cert")) {
      bail("Concourse needs to be configured with 'no-tls', 'provided-cert' or".
           "\n'self-signed-cert'.".
           "\n".
           "\nIf upgrading, please add 'self-signed-cert' to your environment's list of".
           "\nfeatures and run 'genesis add-secrets' to generate the certificate.");
    }
  }
}

sub _handle_okta_feature {
  my ($self) = @_;

  if ($self->want_feature("okta")) {
    $self->add_files("manifests/addons/okta.yml");
  }
}

1;

