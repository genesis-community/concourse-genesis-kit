# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Check::Concourse; # version of the concourse kit

use v5.20;
use warnings; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook::Check);

# Import required functions
use Genesis;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->{ok} = 1; # Start assuming all checks will pass
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Skip cloud config checking as it's now handled separately

  # Check kit feature compatibility
  if ($self->want_feature('ocfp') && $self->want_feature('workers')) {
    $self->env->notify(
      error => "The 'ocfp' and 'workers' features cannot be used together: [#R{FAILED}]"
    );
    $self->{ok} = 0;
  }

  # Check mutual exclusivity of authentication methods
  my $auth_count = 0;
  for my $auth_feature (qw/github-oauth github-enterprise-oauth cf-oauth okta/) {
    $auth_count++ if $self->want_feature($auth_feature);
  }

  if ($auth_count > 1) {
    $self->env->notify(
      error => "Only one authentication method can be specified: [#R{FAILED}]"
    );
    $self->{ok} = 0;
  }

  # Check vault configuration
  if ($self->want_feature('vault-approle') && !$self->want_feature('vault')) {
    $self->env->notify(
      error => "The 'vault-approle' feature requires the 'vault' feature: [#R{FAILED}]"
    );
    $self->{ok} = 0;
  }

  # Return the final result
  if ($self->{ok}) {
    $self->env->notify(success => "environment files [#G{OK}]");
  } else {
    $self->env->notify(error => "environment files [#R{FAILED}]");
  }

  return $self->done(1);
}

1;

