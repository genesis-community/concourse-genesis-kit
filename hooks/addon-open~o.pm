# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Addon::Concourse::Open;

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
  "Open the Concourse Web User Interface in your browser\n".
  "(requires macOS or Linux with xdg-open support).\n".
  "You will be shown the credentials to use for login.";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  my $host_env = $env->exodus_lookup("host_env") || $env->name;
  my $exodus_path = $env->exodus_mount . "$host_env/concourse";

  my $cmd = $self->_get_open_command();
  if (!$cmd) {
    $env->notify(error => "The 'open' addon script only works on macOS and Linux with xdg-open, currently.");
    return 0;
  }

  my $host_user = $env->exodus_lookup("username", undef, $host_env . "/concourse");
  my $host_pw = $env->exodus_lookup("password", undef, $host_env . "/concourse");

  $env->notify(
    "You will need to enter the following credentials once the page opens:".
    "\n#I{\tusername:} #C{$host_user}".
    "\n#I{\tpassword:} #C{$host_pw}".
    "\n"
  );

  my $host = $env->exodus_lookup("external_url", undef, $host_env . "/concourse");

  # TODO: Convert to use Genesis run cmd
  system("read -n 1 -s -r -p \"Press any key to open the web console...\"");
  system($cmd, "${host}/teams/main/login");

  return $self->done();
}

sub _get_open_command {
  my ($self) = @_;
  my $uname = `uname`;
  chomp($uname);

  if ($uname eq "Darwin") {
    return "open";
  }
  elsif ($uname eq "Linux" && `command -v xdg-open 2>/dev/null`) {
    return "xdg-open";
  }

  return undef;
}

1;

