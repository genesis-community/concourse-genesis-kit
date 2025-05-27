#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Concourse::Login v2.7.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook::Addon);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "\nLogin to this Concourse deployment with fly\n".
  "\nUsage: login [TEAM]\n".
  "\n\tOptions:\n".
  "\t\t--local    Log in using basic auth instead of browser-based auth\n".
  "\n\tIf no team is specified, logs into the main team";
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

  info("Using fly at " . humanize_path($fly));

  # Parse options
  my %options = $self->parse_options(['local']);
  my $use_local = $options{local} || 0;

  # Get host data and team if specified
  my $host_env = $env->exodus_lookup("host_env") || $env->name;
  my $team = "";
  if ($self->{args} && @{$self->{args}}) {
    $team = $self->{args}[0];
  }

  my $host_user = $env->exodus_lookup("username", undef, $host_env . "/concourse");
  my $host_pw = $env->exodus_lookup("password", undef, $host_env . "/concourse");
  my $main_target = $env->exodus_lookup("main_target", $host_env, $host_env . "/concourse");

  my $target_desc = '';
  if ($main_target ne $host_env) {
    $target_desc = " (target: $main_target)";
  }

  $env->notify(
    "\nLogging in to Concourse deployment #C{$host_env}${target_desc} as user '$host_user'.\n"
  );

  # Set target
  my $target = $main_target;
  if ($team) {
    $target = "$target/$team";
  } else {
    $use_local = 1;
  }

  # Prepare login command
  my @cmd = ($fly, "-t", $target, "login");

  if ($use_local) {
    push @cmd, "--username=$host_user", "--password=$host_pw";
  }

  if ($team) {
    push @cmd, "-n", $team;
  }

  # Add URL if target doesn't exist
  if (!$self->_has_target($fly, $target)) {
    my $url = $env->exodus_lookup("external_url", undef, $host_env . "/concourse");
    push @cmd, "--concourse-url", $url;
  }

  # Add insecure option if self-signed
  if ($env->exodus_lookup("self-signed", "no", $host_env . "/concourse") eq "1") {
    push @cmd, "-k";
  }

  # Run the login command
  my ($output, $rc) = run({ interactive => 1 }, @cmd);

  if ($rc != 0) {
    $env->notify("#R{[ERROR]} Failed to log in!");
  }

  return $rc == 0 ? $self->done() : $self->done(0);
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

sub _has_target {
  my ($self, $fly, $target) = @_;

  my $url = $self->env->exodus_lookup("external_url");
  my $host_env = $self->env->exodus_lookup("host_env") || $self->env->name;

  # Extract team from target
  my $team = $target;
  $team =~ s/^[^\/]*\///;
  if ($team eq $target) {
    $team = 'main';
  }

  # Check if target exists
  my $found = `$fly targets | grep "^${target} " || true`;
  return 0 if !$found;

  # Parse target info
  my @parts = split(/\s+/, $found);
  my $target_url = $parts[1];
  my $target_team = $parts[2];

  # Check URL and team match
  if ($url ne $target_url) {
    bail(
      "\n#R{[ERROR]} Target mismatch in URL from expected ($url) and current ($target_url).".
      "\n\tCannot continue."
    );
  }

  if ($team ne $target_team) {
    bail(
      "\n#R{[ERROR]} Target mismatch in team from expected ($team) and current ($target_team).".
      "\nCannot continue."
    );
  }

  return 1;
}

1;
