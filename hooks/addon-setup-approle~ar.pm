package Genesis::Hook::Addon::Concourse::SetupApprole v5.1.3;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use Genesis qw/bail info run/;
use Genesis::UI qw/prompt_for_boolean/;
use File::Temp ();

use parent qw(Genesis::Hook::Addon);
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub cmd_details {
  return
  "\nCreate the necessary Vault AppRole and policy for Genesis Concourse deployments.\n".
  "Unlike other addons, this can and should be run before deployment.\n".
  "\n".
  "This will setup up the app roles and policies for concourse and genesis-pipelines.\n".
  "The concourse app role will provide concourse access to a vault location\n".
  "(usually `/concourse`) for interpolating secrets in pipelines. The genesis-pipelines\n".
  "app role is used to allow the Genesis pipelines to access vault for reading\n".
  "deployment secrets and writing exodus data.\n".
  "\n".
  "Supports the following options:\n".
  "[[  #y{--yes, -y}          >>Answer yes to every confirmation, for non-interactive runs\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  my %options = $self->parse_options([
    'yes|y', # Answer yes to every confirmation prompt
  ]);
  $self->{non_interactive} = $options{'yes'} ? 1 : 0;

  info(
    "\nThis will setup up the app roles and policies for concourse and".
    "\ngenesis-pipelines. The concourse app role will provide concourse access to a".
    "\nvault location (usually `/concourse`) for interpolating secrets in pipelines.".
    "\nThe genesis-pipelines app role is used to allow the Genesis pipelines to access".
    "\nvault for reading deployment secrets and writing exodus data.\n"
  );

  # Check if AppRole is enabled
  info("Ensuring Vault AppRole is enabled...");
  my $result = $self->vault->query("vault","auth","enable","approle");

  my @roles = ();
  if ($result =~ /(Success\! Enabled approle auth method)/) {
    info("#G{[ok - successfully enabled approle]}");
  } elsif ($result =~ /(path is already in use)/) {
    info("#G{[ok - approle already enabled]}");
    info("Checking for existing roles...");

    my $roles_output = $self->vault->query("ls","auth/approle/role","-1");
    @roles = split(/\n/, $roles_output);
    info("#G{[ok - " . scalar(@roles) . " role(s) found]}");
  } else {
    bail("#R{[error]}\nFailed to enable app role on your targeted Vault:\n$result\n");
  }

  # Setup concourse approle
  my $create_concourse = $self->_confirm("Do you want to install the #C{concourse} app role? [Y/N]", 0);

  if ($create_concourse) {
    $self->_setup_concourse_approle(\@roles);
  }

  # Setup genesis-pipelines approle
  my $create_pipelines = $self->_confirm("Do you want to install the #C{genesis-pipelines} app role?", 0);

  if ($create_pipelines) {
    $self->_setup_pipelines_approle(\@roles);
  }

  return $self->done();
}

sub _setup_concourse_approle {
  my ($self, $roles_ref) = @_;
  my $approle = 'concourse';

  # Check if role already exists
  if (grep { $_ eq $approle } @$roles_ref) {
    info("#y{[WARNING]} App role #C{$approle} already exists. This action will overwrite it...");
    my $continue = $self->_confirm("Continue?", 0);
    return 0 if !$continue ;
  }

  # Get concourse mount point
  my $concourse_mount = "concourse";
  #  $concourse_mount = prompt_for_line("Mount to use for concourse secrets", 'concourse', '/^[a-z0-9]*$/'); # FIXME

  # Get approle path
  my $concourse_approle_path = $ENV{GENESIS_SECRETS_BASE} . "approle/concourse";
  #  $concourse_approle_path = prompt_for_line("Vault path for storing concourse app role credentials", $concourse_approle_path); # FIXME

  # Check if mount exists
  my $mount_type = $self->_get_mount_type($concourse_mount);
  my $concourse_mount_path = "/$concourse_mount";
  $concourse_mount_path =~ s#^/+##;
  $concourse_mount_path = "/$concourse_mount_path";

  if (!$mount_type) {
    # Create mount if it doesn't exist, Is there a reason to still offer kv_v1?
    my $kv_version = "2";
#    prompt_for('kv_version', 'select', "", "--default", "2",
#      "Mount ${concourse_mount_path} does not exist. It must be a v1 or v2 kv store.",
#      "-o", "[1] Create a kv v1 secrets store",
#      "-o", "[2] Create a kv v2 secrets store",
#      \$kv_version);

    info("Creating mount #C{${concourse_mount_path} (kv v$kv_version)}...");

    if ($kv_version) {
      my $desc = "endpoint used for interpolating concourse pipeline secrets";
      my ( $out, $rc, $err ) = $self->vault->query(
        "vault","secrets","enable","-path",$concourse_mount,"-version",$kv_version,"-description",$desc, "kv"
      );
      info("Output: %s", $out);

      if ($err//$out =~ /Error/ ) {
        bail("#R{[error]}\nFailed to create mount ${concourse_mount_path} -- please resolve and try again:\n %s", $err//$out);
      }
    }
    info("#G[ok]");
    $mount_type = "kv_v$kv_version";
  } else {
    info("Found existing mount #C{${concourse_mount_path}} - validating...");
    if ($mount_type =~ /^kv_v[12]$/) {
      info("#G{[ok - ${mount_type}]}");
    } else {
      bail(
        "\n#R{[error - invalid type]}\nFound a ${mount_type} at mount ${concourse_mount_path} -- Cannot use this as a concourse secrets store (must be kv v1 or v2)\n"
      );
    }
  }

  # Create concourse policy
  info("Creating #C{concourse} policy...");
  my $policy = _concourse_policy($concourse_mount, $mount_type eq "kv_v1" ? "1" : "2");

	info("#Y{Policy file being applied to Concourse}\n\n%s\n\n", $policy);

  my ($out, $rc, $err) = $self->_write_policy("concourse", $policy);
  info("Output: %s", $out) if $out;
  if ($out !~ /Success/) {
    bail("#R{[error]}\nFailed to save #C{concourse} policy:\n%s", $err//$out);
  }
  info("#G{[ok]}");
  info("#wui{Policy for $approle}\n#K{$policy}\n");

  # Create app role
  info("Creating and configuring app role #C{$approle}...");
  $self->vault->query("vault","delete","auth/approle/role/$approle");

  # A role is API config, not a kv secret, so we write it natively: safe set
  # would merge into a read-back whose values come back normalised (lists,
  # integers), which the write confirmation then refuses to trust.
  my ($role_out, $role_rc, $role_err) = $self->vault->query(
    "vault", "write", "auth/approle/role/$approle",
    "secret_id_ttl=0",
    "token_num_uses=0",
    "token_period=3600",
    "token_ttl=3600",
    "token_max_ttl=0",
    "secret_id_num_uses=0",
    "token_policies=concourse",
  );
  $rc = $role_rc;

  if ($rc != 0) {
    bail("#R{[error]}\nFailed to create #C{$approle} approle.");
  }
  info("#G{[ok]}");

  # Generate credentials
  info("Generating and storing authentication credentials...");
  my $role_id = $self->vault->get("auth/approle/role/$approle/role-id:role_id");
  my $approle_secret = $self->vault->query("vault","write","-field=secret_id","-f","auth/approle/role/$approle/secret-id");

  # Store credentials
  $self->vault->set("${concourse_approle_path}", "approle-id", "$role_id");
  $self->vault->set("${concourse_approle_path}", "approle-secret", "$approle_secret");

  info("#G{[ok]} Access credentials written to #M{$concourse_approle_path}");
  info("#G{[DONE]} App role #C{$approle} created.");

  return 1;
}

sub _setup_pipelines_approle {
  my ($self, $roles_ref) = @_;
  my $approle = 'genesis-pipelines';

  # Check if role already exists
  if (grep { $_ eq $approle } @$roles_ref) {
    info("#y{[WARNING]} App role #C{$approle} already exists. This action will overwrite it...");
    my $continue = $self->_confirm("Continue?", 0);
    return 0 if !$continue;
  }

  # Create genesis-pipelines policy
  info("Generating policy for #C{$approle} app role...");

  # Get paths from secrets and exodus mounts
  my $sec_info = $self->_match_mount($ENV{GENESIS_SECRETS_MOUNT});
  if (!$sec_info) {
    bail("#R{[error]}\nCannot find mount for secrets path of '$ENV{GENESIS_SECRETS_MOUNT}'");
  }
  my ($sec_mnt, $sec_path, $sec_ver) = @$sec_info;

  info("Secret Mount: '%s', Path: '%s', Version: '%s'", $sec_mnt, $sec_path, $sec_ver);

  my $exo_info = $self->_match_mount($ENV{GENESIS_EXODUS_MOUNT});
  if (!$exo_info) {
    bail("#R{[error]}\nCannot find mount for exodus path of '$ENV{GENESIS_EXODUS_MOUNT}'");
  }
  my ($exo_mnt, $exo_path, $exo_ver) = @$exo_info;
  info("Exodus Mount: '%s', Path: '%s', Version: '%s'", $exo_mnt, $exo_path, $exo_ver);

  # Build policy based on mount types and paths
  my $policy = _pipelines_policy($sec_info, $exo_info);

  # Write policy to vault
  my ($out, $rc, $err) = $self->_write_policy($approle, $policy);
  info("Output: %s", $rc);
  if ($out !~ /Success/) {
    bail("#R{[error]}\nFailed to create #C{$approle} policy:\n%s", $err//$out);
  }
  info("#G{[ok]}");
  info("#wui{Policy for $approle}\n#K{$policy}\n");

  # Create AppRole
  info("Creating and configuring app role #C{$approle}...");
  $self->vault->query("vault","delete","auth/approle/role/$approle");

  # A role is API config, not a kv secret, so we write it natively: safe set
  # would merge into a read-back whose values come back normalised (lists,
  # integers), which the write confirmation then refuses to trust.
  my ($role_out, $role_rc, $role_err) = $self->vault->query(
    "vault", "write", "auth/approle/role/$approle",
    "secret_id_ttl=0",
    "token_num_uses=0",
    "token_ttl=60m",
    "token_max_ttl=60m",
    "secret_id_num_uses=0",
    "token_policies=default,$approle",
  );
  $rc = $role_rc;

  if ($rc != 0) {
    bail("#R{[error]}\nFailed to create #C{$approle} approle.");
  }
  info("#G{[ok]}");

  # Generate credentials
  info("Writing access credentials to Exodus...");
  my $role_id = $self->vault->get("auth/approle/role/$approle/role-id:role_id");
  my $approle_secret = $self->vault->query("vault","write","-field=secret_id","-f","auth/approle/role/$approle/secret-id");

  # Store credentials in CI mount
  $self->vault->set("${ENV{GENESIS_CI_MOUNT}}$approle", "approle-id", "$role_id");
  $self->vault->set("${ENV{GENESIS_CI_MOUNT}}$approle", "approle-secret", "$approle_secret");

  info("#G{[ok]} Access credentials written to #M{${ENV{GENESIS_CI_MOUNT}}$approle}");
  info("#G{[DONE]} App role #C{$approle} created.\n");

  return 1;
}

sub _get_mount_type {
  my ($self, $mount) = @_;
  # vault->query runs safe, so the vault CLI has to be invoked through
  # `safe vault ...`; a bare `safe secrets list` is not a safe command and
  # returns nothing, which used to make this look like a missing mount.
  my ($output, $rc, $err) = $self->vault->query("vault","secrets","list","--detailed");
  bail(
    "#R{[error]}\nFailed to list vault mounts while checking for %s -- please resolve and try again:\n %s",
    $mount, $err // $output
  ) if $rc;

  # Parse output to find mount type
  my @lines = split(/\n/, $output);
  for my $line (@lines) {
    if ($line =~ /^${mount}\// && $line =~ /kv/) {
      my @parts = split(/\s+/, $line);
      my $type = $parts[1] || "";
      my $version = "";

      if ($line =~ /map\[version:([12])\]/) {
        $version = $1;
        return "${type}_v${version}";
      }

      return $type;
    }
  }

  return "";
}

sub _confirm {
  my ($self, $prompt, $default) = @_;
  if ($self->{non_interactive}) {
    (my $shown = $prompt) =~ s/\s*\[Y\/N\]\s*$//;
    info("%s #G{yes} (--yes)", $shown);
    return 1;
  }
  return prompt_for_boolean($prompt, $default);
}

sub _match_mount {
  my ($self, $path) = @_;
  my $output = $self->vault->query("vault","secrets","list","--detailed");
  return _longest_mount_match($path, _parse_kv_mounts($output));
}

sub _write_policy {
  my ($self, $name, $policy) = @_;

  # A private temp file (mode 0600) that is removed when $tmp goes out of
  # scope, so concurrent runs cannot clobber or read each other's policy.
  my $tmp = File::Temp->new(TEMPLATE => "genesis-policy-XXXXXX", SUFFIX => ".hcl", TMPDIR => 1);
  print $tmp $policy or bail("#R{[error]}\nFailed to write policy to %s: %s", $tmp->filename, $!);
  close($tmp) or bail("#R{[error]}\nFailed to write policy to %s: %s", $tmp->filename, $!);

  return $self->vault->query("vault","policy","write",$name,$tmp->filename);
}

# Pure helpers {{{
# Everything below takes plain values and returns plain values, so the policy
# text can be tested without a vault.

# Collapse a vault path to its segments joined by single slashes, with no
# leading or trailing slash: "/secret//exodus/" becomes "secret/exodus".
sub _normalize_path {
  my ($path) = @_;
  return join('/', grep { length } split(m{/+}, $path // ''));
}

# Parse `vault secrets list --detailed` into [ mount, version ] pairs for every
# kv mount. A kv mount with no version option is kv v1.
sub _parse_kv_mounts {
  my ($output) = @_;
  my @mounts = ();
  for my $line (split(/\n/, $output // '')) {
    my ($mount, $type) = split(' ', $line);
    next unless defined($type) && $type eq 'kv' && $mount =~ m{/$};
    my $version = ($line =~ /map\[[^\]]*\bversion:([12])\b/) ? $1 : "1";
    push @mounts, [ _normalize_path($mount), $version ];
  }
  return @mounts;
}

# Find the most specific kv mount holding $path, matching whole segments, so
# secret/exodus/ wins over secret/ when both are mounted. Returns
# [ "mount/", subpath, version ] or undef.
sub _longest_mount_match {
  my ($path, @mounts) = @_;
  my $want = _normalize_path($path);

  my $best;
  for my $mount_info (@mounts) {
    my ($mount, $version) = @$mount_info;
    $mount = _normalize_path($mount);
    next unless length($mount);
    next unless $want eq $mount || index($want, "$mount/") == 0;
    next if $best && length($best->[0]) >= length($mount);
    $best = [ $mount, _normalize_path(substr($want, length($mount))), $version ];
  }
  return undef unless $best;

  $best->[0] .= '/';
  return $best;
}

# The policy globs covering everything under $subpath of a kv mount: the path
# itself on kv v1, and its data/ and metadata/ trees on kv v2.
sub _kv_policy_paths {
  my ($mount, $subpath, $version) = @_;
  my @trees = ($version eq "2") ? ("data", "metadata") : ("");
  return map {
    join('/', grep { length } (_normalize_path($mount), $_, _normalize_path($subpath), '*'))
  } @trees;
}

sub _policy_rules {
  my ($paths, @capabilities) = @_;
  my $caps = join(', ', map { "\"$_\"" } @capabilities);
  return join('', map { "path \"$_\" { capabilities = [$caps] }\n" } @$paths);
}

sub _concourse_policy {
  my ($mount, $version) = @_;
  return
    "# List, create, update, and delete key/value secrets for Concourse\n".
    _policy_rules(
      [ _kv_policy_paths($mount, "", $version) ],
      qw(create read update delete list sudo)
    );
}

# $sec_info and $exo_info are the [ mount, subpath, version ] results of
# _match_mount for the secrets and exodus paths.
sub _pipelines_policy {
  my ($sec_info, $exo_info) = @_;
  return
    "# Allow the pipelines to read deployment secrets, and write genesis exodus data\n\n".
    _policy_rules([ _kv_policy_paths(@$sec_info) ], qw(read list)).
    _policy_rules([ _kv_policy_paths(@$exo_info) ], qw(create read update list delete));
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
