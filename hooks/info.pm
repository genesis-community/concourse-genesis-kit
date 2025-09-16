package Genesis::Hook::Info::Concourse v5.0.1;

use v5.20;
use warnings; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/bail info/;
use JSON::PP;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Get host and worker data from exodus
  my $host_data = $env->exodus_lookup(".", {});
  my $worker_data = {};
  my $host_env = $host_data->{host_env} || "";

  if ($host_env) {
    $worker_data = $host_data;
    $host_data = $env->exodus_lookup(".", {}, $host_env . "/concourse");
  } else {
    $host_env = $env->name;
  }

  if ($self->want_feature("workers")) {
    if (!keys %$worker_data) {
      info("#R{[ERROR]} Missing data on this worker-only deploy. Please redeploy with Genesis v2.6 or later");
      return $self->done(0);
    }

    if (!exists $worker_data->{"tags[0]"}) {
      info("This is a #Y{worker-only} Concourse. The workers in this deployment have ".
           "not been tagged.");
    } else {
      info("This is a #Y{worker-only} Concourse. The workers in this deployment have ".
           "been tagged with the following:");
      my $i = 0;
      while (exists $worker_data->{"tags[$i]"}) {
        my $tag = $worker_data->{"tags[$i]"};
        info("  - #C{$tag}");
        $i++;
      }
    }

    info("");
    info("These workers connect to the host Concourse environment #C{$host_env}");
  } else {
    my $missing = "#RI{missing}";
    my $username = exists $host_data->{username} ? $host_data->{username} : $missing;
    my $password = exists $host_data->{password} ? $host_data->{password} : $missing;
    my $url = exists $host_data->{external_url} ? $host_data->{external_url} : "127.0.0.1";

    info("Web Client".
         "\n  URL:      #C{$url}".
         "\n  username: #C{$username}".
         "\n  password: #C{$password}");

    if ($self->want_feature("shout")) {
      info("");
      info("Shout! Integration".
           "\n  URL:   #G{" . $env->exodus_lookup("shout_url") . "}".
           "\n  Admin: " . $env->exodus_lookup("shout_admin_username") . "/#C{" .
           $env->exodus_lookup("shout_admin_password") . "}".
           "\n  Ops:   " . $env->exodus_lookup("shout_ops_username") . "/#C{" .
           $env->exodus_lookup("shout_ops_password") . "}");
    }
  }

  return $self->done(1);
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
