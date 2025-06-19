package Genesis::Hook::Addon::Concourse::Fly;

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
  "\nRun fly commands targetting this Concourse Deployment\n".
  "\nUsage: fly [FLY_OPTIONS...]\n".
  "\tRuns fly command with auto-login against the main team of this Concourse\n".
  "\tYou don't need to specify -t <target> as it's handled automatically\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Find the fly binary
  my $fly = $self->_find_fly();
  if (!$fly) {
    my $download = $self->_prompt_for_download();
    if ($download) {
      # Run the download-fly addon
      $self->env->run_hook('addon', script => 'download-fly');
      $fly = "./fly";
    } else {
      bail("Cannot continue without #C{fly} command - aborting.");
    }
  }

  # Check if logged in, if not, log in
  my $host_env = $env->exodus_lookup("host_env") || $env->name;
  my $main_target = $env->exodus_lookup("main_target", $host_env, $host_env . "/concourse");

  if (!$self->_is_logged_in($fly, $main_target)) {
    info("You are not logged in to target '$main_target', logging in now...");
    $self->env->run_hook('addon', script => 'login');
  }

  # Run the fly command
  $env->notify("\nRunning fly against #C{$host_env}\n");

  my @cmd = ($fly, "-t", $main_target, @{$self->{args}});
  my $rc = system(@cmd);
  info("");

  return $rc == 0 ? $self->done() : $self->done(0);

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

sub _prompt_for_download {
  my ($self) = @_;
  my $download;
  prompt_for(
    'download',
    'boolean',
    "Command #C{fly} not found -- download it?",
    "-i",
    "--default",
    "true",
    \$download
  );
  return $download eq 'true';
}

sub _is_logged_in {
  my ($self, $fly, $target) = @_;
  return system("$fly -t '$target' status >/dev/null 2>&1") == 0;
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
