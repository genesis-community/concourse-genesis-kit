#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Features::Concourse v2.7.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Add all requested features
  for my $feature (@{$self->{features}}) {
    $self->add_feature($feature);
  }

  if ($self->has_feature("ocfp")) {
    # Contract handles database (via vault) & sizing (dev/prod)
    $self->add_feature("+locker");
  } else {
    # Non-ocfp based
    if (!$self->has_feature("external-db")) {
      $self->add_feature("+internal-db");
    }

    if ($self->has_feature("full") || $self->has_feature("small-footprint")) {
      $self->add_feature("+locker");
    }

    if ($self->has_feature("vault") && $ENV{GENESIS_COMMAND} ne 'new') {
      if ($self->has_feature("vault-approle")) {
        my $role_id = $self->env->lookup("params.vault_approle_role_id", "");
        my $secret_id = $self->env->lookup("params.vault_approle_secret_id", "");
        if ($role_id eq "" && $secret_id eq "") {
          $self->add_feature("+vault-approle-default");
        }
      } else {
        my $token = $self->env->lookup("params.vault_token", "");
        if ($token eq "") {
          $self->add_feature("+vault-token-default");
        }
      }
    }
  }

  return $self->done();
}

1;

