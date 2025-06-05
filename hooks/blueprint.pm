package Genesis::Hook::Blueprint::Concourse v2.7.0;

use v5.20; # Genesis min perl version is 5.20
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail in_array/;

# init - Initialize the hook {{{
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

# }}}

# perform - Main hook execution {{{
sub perform {
  my ($self) = @_;

	my ($strategy,@opsfiles) = $self->validate_strategy_and_features();

  # Base files that are always included
  $self->add_files(
    "manifests/concourse/base.yml",
    "manifests/releases/concourse.yml",
    "manifests/releases/slack-notifications.yml",
    "manifests/concourse/jobs.yml"
  );

  # Track operations files separately for OCFP feature
	my $strategy_method = "build_${strategy}_blueprint" =~ s/-/_/gr;
	if ($self->can($strategy_method)) {
		$self->$strategy_method();
	} else {
		bail("Invalid strategy method '%s' for concourse blueprint", $strategy_method);
	}

	# Add any ops files if they were specified
	if (@opsfiles) {
		$self->add_files(@opsfiles);
	}

	return $self->done();
}

# }}}
# build_ocfp_blueprint - Build OCFP blueprint {{{
sub build_ocfp_blueprint {
	my ($self) = @_;

	# Enforce the 'full' feature, using OCFP vars
	$self->add_files(
		"manifests/concourse/full.yml",
		"manifests/releases/postgres.yml",
		"manifests/releases/locker.yml",
		"manifests/releases/haproxy.yml",
		"manifests/releases/bpm.yml"
	);

	# FIXME: Warn (maybe error?) if other unsupported features are requested
	# that OCFP does not support.

	$self->_handle_tls_features();
	$self->_handle_okta_feature();

	# OCFP enforces the 'no-haproxy' feature
	$self->add_files("manifests/addons/no-haproxy.yml");

	# OCFP vars overrides
	$self->add_files("ocfp/full-concourse-vars-override.yml");

	# 'vault' feature, using OCFP vars
	$self->add_files(
		"manifests/addons/vault.yml",
		"manifests/addons/vault-approle.yml",
		"ocfp/vault-vars-override.yml"
	);

	# 'external-db' & 'external-db-ca' features, using OCFP vars
	$self->add_files(
		"manifests/addons/external-db.yml",
		"manifests/addons/external-db-ca.yml",
		"ocfp/external-db-vars-override.yml"
	) unless $self->want_feature("internal-db");

	$self->add_files("ocfp/ocfp.yml");

	# Handle IaaS-specific OCFP files
	if ($self->supports_iaas()) {
		$self->kit_bug(
			"This concourse kit does not seem to support OCFP on the '%s' IaaS, ".
			"even though the kit.yml metadata says it does.",
			$self->iaas
		) unless -f $self->kit->path("ocfp/iaas/".$self->iaas.".yml");
		$self->add_files("ocfp/iaas/".$self->iaas.".yml");
	}
}

# }}}
# build_full_blueprint - Build full blueprint {{{
sub build_full_blueprint {
	my ($self) = @_;

	$self->add_files(
		"manifests/concourse/full.yml",
		"manifests/releases/postgres.yml",
		"manifests/releases/locker.yml",
		"manifests/releases/haproxy.yml",
		"manifests/releases/bpm.yml"
	);

	$self->_handle_tls_features();

	# Handle OAuth options
	$self->_handle_oauth_features();
	$self->_handle_okta_feature();

	# Database
	if ($self->want_feature("external-db")) {
		$self->add_files("manifests/addons/external-db.yml");
		$self->add_files("manifests/addons/external-db-ca.yml")
			if $self->want_feature("external-db-ca");
	}

	$self->add_files("manifests/addons/vault.yml")
		if ($self->want_feature("vault"));

	if ($self->want_feature("vault-approle")) {
		bail("Cannot use 'vault-approle' feature without 'vault' feature")
			if (!$self->want_feature("vault"));
		$self->add_files("manifests/addons/vault-approle.yml");
	}

	$self->add_files(
		"manifests/addons/shout.yml",
		"manifests/releases/shout.yml"
	) if ($self->want_feature("shout"));

	$self->add_files("manifests/addons/prometheus.yml")
		if ($self->want_feature("prometheus"));

	if ($self->want_feature("no-haproxy")) {
		# TODO: Is removing haproxy.yml the same as adding no-haproxy.yml?
		$self->add_files("manifests/addons/no-haproxy.yml");
		$self->add_files("manifests/addons/dynamic-web.yml")
			if ($self->want_feature("dynamic-web-ip"));
	}

	my $max_builds = $self->env->lookup("params.max_builds_to_retain", "0");
	if ($max_builds =~ /^\d+$/ && $max_builds > 0) {
		$self->add_files("manifests/addons/maximum-builds-retention.yml");
	}
}

# }}}

# build_small_footprint_blueprint - Build small footprint blueprint {{{
sub build_small_footprint_blueprint {
	my ($self) = @_;

	# This is based on the 'full' blueprint, but with some features altered or
	# removed.

	$self->build_full_blueprint();

	$self->remove_files(
		"manifests/releases/haproxy.yml",
		"manifests/addons/no-haproxy.yml"
	);

  $self->add_files("manifests/addons/external-db-small.yml")
    if ($self->want_feature("external-db"));

	$self->exchange_files(
		"manifests/concourse/full.yml" => "manifests/concourse/small-footprint.yml",
		"manifests/addons/prometheus.yml" => "manifests/addons/prometheus-small-footprint.yml"
	);
}

# }}}
# build_workers_blueprint - Build workers-only blueprint {{{
sub build_workers_blueprint {
	my ($self) = @_;
  $self->add_files("manifests/concourse/workers.yml");
}

# }}}

# validate_strategy_and_features - Validate strategy and feature combinations {{{
sub validate_strategy_and_features {
	my ($self) = @_;

	# Defunct features that are no longer supported
	my @defunct_features = qw(
		azure aws gcp vsphere
		shield
	);
	my @defunct = grep {
		in_array($_, @defunct_features)
	} $self->features;

	bail(
		"Concourse blueprint cannot be used with the following defunct features: %s%s",
		join(", ", @defunct),
		"\n\nIaaS features are automatically detected" . (
			in_array('shield', @defunct) ?
			", and the 'shield' feature is no longer needed." : ''
		)
	) if @defunct;

	# Strategy features

	my @strategy_features = qw(
		ocfp workers full small-footprint
	);

	my ($strategy, @extra_strategies) = grep {
		in_array($_, @strategy_features)
	} $self->features;

	bail(
		"Concourse needs to be configured with one of the following strategies: ".
		"'ocfp', 'workers', 'full', or 'small-footprint'. If upgrading, please ".
		"add 'full' to your environment's list of features to keep previous ".
		"functionality."
	) unless $strategy;
	bail(
		"Concourse cannot be configured with more than one of the following ".
		"strategies: 'ocfp', 'workers', 'full', or 'small-footprint'. This ".
		"environment currently specifies: %s",
		join(", ", @extra_strategies)
	) if @extra_strategies;

	my %valid_features = (
		ocfp => [
			qw(
				internal-db self-signed-cert provided-cert no-tls
				okta
			)
		],
		workers => [
		],
		default => [
			qw(
				provided-cert self-signed-cert no-tls
				vault vault-approle shout
				no-haproxy dynamic-web-ip
				external-db external-db-ca
				okta github-oauth github-enterprise-oauth cf-oauth
				prometheus
			)
		],
	);

  # Check for custom ops files in the deployment
	my @opsfiles = ();
	my @bad_features = ();
	my @good_features = exists($valid_features{$strategy})
		? @{$valid_features{$strategy}}
		: @{$valid_features{default}};
  for my $feature ($self->features) {
    next if (in_array($feature, @good_features, @strategy_features));

    if (-f $self->env->path("ops/$feature.yml")) {
			push @opsfiles, $self->env->path("ops/$feature.yml");
    } else {
			push @bad_features, $feature;
    }
  }
	bail(
		"Unrecognized features found in this %s environment: %s",
		$strategy,
		join(", ", @bad_features),
	) if @bad_features;

	return ($strategy, @opsfiles);
}

# }}}

# _handle_tls_features - Handle TLS-related feature processing {{{
sub _handle_tls_features {
  my ($self) = @_;

  if (!$self->want_feature("no-tls")) {
    $self->add_files("manifests/concourse/tls.yml");

    if ($self->want_feature("self-signed-cert")) {
      $self->add_files("manifests/addons/self-signed.yml");
    } elsif (!$self->want_feature("provided-cert")) {
      bail("Concourse needs to be configured with 'no-tls', 'provided-cert' or".
           "\n'self-signed-cert'.".
           "\n".
           "\nIf upgrading, please add 'self-signed-cert' to your environment's list of".
           "\nfeatures and run 'genesis add-secrets' to generate the certificate.");
    }
  }
}

# }}}

# _handle_okta_feature - Handle Okta authentication feature processing {{{
sub _handle_okta_feature {
  my ($self) = @_;

  if ($self->want_feature("okta")) {
    $self->add_files("manifests/addons/okta.yml");
  }
}

# }}}

# _handle_oauth_features - Handle OAuth-related feature processing {{{
sub _handle_oauth_features {
	my ($self) = @_;

	my @oath_features = grep {$_ =~ /-oauth$/} $self->features;
	for my $oauth (@oath_features) {
		my ($base, $extended) = $oauth =~ /^([^-]*)(?:-(.*))?-oauth$/;
		my @files = ("manifests/oauth/$base-oauth.yml");
		push @files, "manifests/oauth/$oauth.yml" if $extended;
		$self->add_files(grep {-f $self->kit->path($_)} @files);
	}
}

# }}}

1; # End of module
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

