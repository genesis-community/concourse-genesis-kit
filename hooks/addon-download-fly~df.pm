package Genesis::Hook::Addon::Concourse::DownloadFly v5.0.1;

use v5.20;
use warnings; # Genesis min perl version is 5.20
use Genesis qw/bail info run humanize_path/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
use File::Basename qw/dirname/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "\nGet the version of fly compatible with this Concourse\n".
  "\nUsage: download-fly [OPTIONS] [PATH]\n".
  "\n\tOptions:\n".
  "\t\t-p PLATFORM    Specify platform (darwin, linux, windows)\n".
  "\t\t--sync         Update existing fly in PATH\n".
  "\n\tPATH defaults to current directory if not specified.";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Parse options
  my %options = $self->parse_options([
    'p=s',   # Platform
    'sync',  # Sync with existing fly
  ]);

  my $platform = $options{p};
  my $sync = $options{sync} || 0;
  my $path = "";

  # Check arguments
  if ($self->{args} && @{$self->{args}}) {
    $path = $self->{args}[0];
  }

  # Handle --sync option
  if ($sync) {
    if ($path) {
      bail("#R{[ERROR]} Can't specify a path and use --sync option");
    }
    $path = `which fly 2>/dev/null`;
    chomp($path);
    if (!$path) {
      bail("#R{[ERROR]} No fly found in path -- cannot use --sync option");
    }
    if (! -w $path) {
      bail("#R{[ERROR]} No write permission to $path -- cannot use --sync option");
    }
  }

  # If no path specified, use current directory
  if (!$path) {
    $path = ".";
  }

  # If path is a directory, append "/fly"
  if (-d $path) {
    $path = "$path/fly";
  }

  # Determine platform if not specified
  if (!$platform) {
    my $ostype = $ENV{OSTYPE} || `uname -s | tr "[:upper:]" "[:lower:]"`;
    chomp($ostype);

    if ($ostype =~ /darwin/ || $ostype eq "mac") {
      $platform = "darwin";
    }
    elsif ($ostype =~ /linux/) {
      $platform = "linux";
    }
    elsif ($ostype =~ /mingw|cygwin|win/) {
      $platform = "windows";
    }
    else {
      bail(
        "\n#R{[ERROR]} Cannot determine platform type:\n".
        "\tPlease specify one of darwin, linux or windows using the -p option"
      );
    }
  }

  # Validate platform
  if ($platform !~ /^(darwin|linux|windows)$/) {
    bail("#R{[ERROR]} Unknown platform type '$platform': expecting one of darwin, linux or windows");
  }

  # Get Concourse URL
  my $host_env = $env->exodus_lookup("host_env") || $env->name;
  my $url = $env->exodus_lookup("external_url", undef, $host_env . "/concourse") ||
            $env->exodus_lookup("external_url");

  # Download fly
  $env->notify("\nDownloading #C{$platform/amd64} version of fly from #C{${url}}...\n");

  # Create the directory if it doesn't exist
  my $dir = dirname($path);
  if (! -d $dir) {
    mkdir_or_fail($dir);
  }

  # Download the file
  my ($output, $resultcode) = run(
    'curl -o "$1" -w "%{http_code}" -Lk "$2/api/v1/cli?arch=amd64&platform=$3"',
    $path, $url, $platform
  );

  if ($resultcode ne "0") {
    bail("#R{[ERROR]} Failed to download fly (Status: $resultcode): $output");
  }

  # Make it executable
  chmod 0755, $path;

  $env->notify( "\n#G{Download successful - written to}:\n\t#C{$path}\n" );

  return $self->done();
}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
