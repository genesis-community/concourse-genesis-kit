package Genesis::Hook::Addon::Concourse::SetupApprole v5.1.2;

use v5.20;
use warnings; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use Genesis::UI qw/prompt_for_boolean/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

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
  my $policy = "";
  $policy .= "# List, create, update, and delete key/value secrets for Concourse\n";
  my $capabilities = '" { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }';

  if ($mount_type eq "kv_v1") {
    $policy .= "path \"${concourse_mount_path}/*$capabilities\n";
  } else {
    $policy .= "path \"${concourse_mount_path}/data/*$capabilities\n";
    $policy .= "path \"${concourse_mount_path}/metadata/*$capabilities\n";
  }

	info("#Y{Policy file being applied to Concourse}\n\n%s\n\n", $policy);

	# Write policy to file
  open(my $fh, '>', '/tmp/policy.hcl') or bail("#R{[error]}\nFailed to write policy to /tmp/policy.hcl: $!");
  print $fh $policy;
  close($fh);

  my ($out, $rc, $err) = $self->vault->query("vault","policy","write","concourse","/tmp/policy.hcl");
  info("Output: %s", $out) if $out;
  if ($out !~ /Success/) {
    bail("#R{[error]}\nFailed to save #C{concourse} policy:\n%s", $err//$out);
  }
  info("#G{[ok]}");
  info("#wui{Policy for $approle}\n#K{$policy}\n");

  # Create app role
  info("Creating and configuring app role #C{$approle}...");
  $self->vault->query("vault","delete","auth/approle/role/$approle");

  $rc = $self->vault->set(
    "auth/approle/role/$approle",
    "secret_id_ttl", "0",
    "token_num_uses", "0",
    "token_period", "3600",
    "token_ttl", "3600",
    "token_max_ttl", "0",
    "secret_id_num_uses", "0",
    "policies", "concourse"
  );

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
  my $policy = "# Allow the pipelines to read all items within Vault, and write to secret/exodus (for genesis exodus data)\n\n";

  my $read_capabilities = '" { capabilities = ["read", "list"] }';

  my $write_capabilities = '" { capabilities = ["create", "read", "update", "list", "delete"] }';

  # Secrets path (read access)
  if ($sec_ver eq "2" && $sec_path) {
    $policy .= "path \"${sec_mnt}data/${sec_path}/*$read_capabilities\n";
    $policy .= "path \"${sec_mnt}metadata/${sec_path}/*$read_capabilities\n";
  } else {
    $policy .= "path \"${ENV{GENESIS_SECRETS_MOUNT}}/*$read_capabilities\n";
  }

  # Exodus path (write access)
  if ($exo_ver eq "2" && $exo_path) {
    $policy .= "path \"${exo_mnt}data/${exo_path}/*$write_capabilities\n";
    $policy .= "path \"${exo_mnt}metadata/${exo_path}/*$write_capabilities\n";
  } else {
    $policy .= "path \"${ENV{GENESIS_EXODUS_MOUNT}}/*$write_capabilities\n";
  }

  # Write policy to file
  open(my $fh, '>', '/tmp/policy.hcl') or bail("#R{[error]}\nFailed to write policy to /tmp/policy.hcl: $!");
  print $fh $policy;
  close($fh);

  # Write policy to vault
  my ($out, $rc, $err) = $self->vault->query("vault","policy","write","$approle","/tmp/policy.hcl");
  info("Output: %s", $rc);
  if ($out !~ /Success/) {
    bail("#R{[error]}\nFailed to create #C{$approle} policy:\n%s", $err//$out);
  }
  info("#G{[ok]}");
  info("#wui{Policy for $approle}\n#K{$policy}\n");

  # Create AppRole
  info("Creating and configuring app role #C{$approle}...");
  $self->vault->query("vault","delete","auth/approle/role/$approle");

  $rc = $self->vault->set(
    "auth/approle/role/$approle",
    "secret_id_ttl", "0",
    "token_num_uses", "0",
    "token_ttl", "60m",
    "token_max_ttl", "60m",
    "secret_id_num_uses", "0",
    "policies", "default,$approle"
  );

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

  # Get all kv mounts with versions
  my @mounts = ();
  my @lines = split(/\n/, $output);
  for my $line (@lines) {
    if ($line =~ /^(\/?)([^\/].*\/)  *kv  *.*map\[version:([12])\]/) {
      push @mounts, [ "/$2", $3 ];
    }
  }

  # Find best match
  for my $mount_info (@mounts) {
    my ($mount, $version) = @$mount_info;
    if ($path =~ /^$mount(.*)/) {
      my $subpath = $1 || "";
      $subpath =~ s/^\///;
      return [ $mount, $subpath, $version ];
    }
  }

  return undef;
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
