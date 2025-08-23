package Genesis::Hook::PostDeploy::Concourse v5.0.0;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::PostDeploy);

use Genesis qw/info/;

sub init {
  my ($class, %ops) = @_;
  my $self = $class->SUPER::init(%ops);
  $self->check_minimum_genesis_version('3.1.0-rc.20');
  return $self;
}

sub perform {
  my ($self) = @_;

  #  # Call any parent methods that need to be executed
  #$self->SUPER::perform() if $self->can('SUPER::perform');

  # Only show deployment info if the deployment was successful
  if ($self->deploy_successful) {
    my $mode = $self->want_feature('workers') ? "Satellite (workers only)" : "Full";
    my $call_env = $self->env->get_call_path_with_env();

    info(
      "\n#M{$ENV{GENESIS_ENVIRONMENT}} $mode Concourse deployed!\n".
      "\nFor details about the deployment, run\n".
      "\t#G{$ENV{GENESIS_CALL} info $ENV{GENESIS_ENVIRONMENT}}\n".
      "\nTo download the '#C{fly}' CLI for the first time, run\n".
      "\t#G{$call_env do -- download-fly /location/in/your/path}\n".
      "\nTo update your current version of the '#C{fly}' CLI, run\n".
      "\t#G{$call_env do -- download-fly --sync}\n".
      "\nTo target & log into this Concourse with fly, run\n".
      "\t#G{$call_env do -- login}\n".
      "\nTo run a fly command against this Concourse, run (without -t <target>)\n".
      "\t#G{$call_env do -- fly [options and arguments]}\n".
      "\nAs an extra efficiency, if you run the '#C{fly}' addon above, it will\n".
      "\tautomatically create the target if one doesn't exist, and log you in if\n".
      "\tyou're not already logged in, before running your desired command.\n".
      "\nFinally, to visit the Concourse Web Portal, run:\n".
      "\t#G{$call_env do -- open}\n"
    );
  }

  return $self->done(1);
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
