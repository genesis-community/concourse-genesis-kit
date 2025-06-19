package Genesis::Hook::Addon::Concourse::Logout;

use v5.20;
use warnings; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "\nLogout of this Concourse deployment with fly\n".
  "\nUsage: logout [TEAM...]\n".
  "\n\tLogs out of the specified team(s), or main team if none specified";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Find the fly binary
  my $fly = $self->_find_fly();
  if (!$fly) {
    bail("Cannot continue without #C{fly} command - aborting.");
  }

  info("Using fly at " . humanize_path($fly));
  info("");

  # Process arguments
  my @teams = @{$self->{args} || []};
  if (!@teams) {
    push @teams, "main";
  }

  my $host_env = $env->exodus_lookup("host_env") || $env->name;
  my $main_target = $env->exodus_lookup("main_target", $host_env, $host_env . "/concourse");
  my $success = 1;

  foreach my $team (@teams) {
    my $target = $main_target;
    if ($team ne "main") {
      $target = "$target/$team";
    }

    info("Logging out of #C{$team} team on #C{$main_target} (#M{$host_env})");

    if (!$self->_has_target($fly, $target)) {
      info("#R{[E]} No target set for #C{$target}");
      $success = 0;
      next;
    }

    if (!$self->_is_logged_in($fly, $target)) {
      info("#y{[W]} Target #C{$target} was not logged in");
      next;
    }

    system($fly, "-t", $target, "logout");
    if ($? != 0) {
      info("#R{[E]} Failed to log out of target #C{$target}");
      $success = 0;
    }
  }

  return $self->done();
}

sub _find_fly {
  my ($self) = @_;

  # Check for fly in specific environment variable
  if ($ENV{GENESIS_FLY_CMD}) {
    return $ENV{GENESIS_FLY_CMD};
  }

  # Check for fly in the deployment root
  if (-x $ENV{GENESIS_ROOT} . "/fly") {
    return $ENV{GENESIS_ROOT} . "/fly";
  }

  # Check for fly in PATH
  my $fly = `which fly 2>/dev/null`;
  chomp($fly);
  if ($fly) {
    return $fly;
  }

  return undef;
}

sub _has_target {
  my ($self, $fly, $target) = @_;
  return system("$fly targets | grep -q '^${target} '") == 0;
}

sub _is_logged_in {
  my ($self, $fly, $target) = @_;
  return system("$fly -t '$target' status >/dev/null 2>&1") == 0;
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
