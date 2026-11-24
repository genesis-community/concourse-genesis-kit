#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;

# kit-validator's lib is either on PERL5LIB (kit-CI convention) or
# supplied via the KIT_VALIDATOR_LIB env var (local iteration).
BEGIN { require lib; lib->import($ENV{KIT_VALIDATOR_LIB}) if $ENV{KIT_VALIDATOR_LIB} }

use Genesis::Kit::Validator::Spec qw/kit_dir test_env/;
use Test::More;

kit_dir("$FindBin::Bin/..");

# --- small-footprint ---------------------------------------------------------
test_env(name => 'small-footprint-no-tls',           cloud_config => 'aws', cpi => 'aws');
# small-footprint-provided-cert: provided cert doesnt do anything
test_env(name => 'small-footprint-self-signed-cert', cloud_config => 'aws', cpi => 'aws');
test_env(name => 'small-footprint-prometheus',       cloud_config => 'aws', cpi => 'aws');

# --- ocfp --------------------------------------------------------------------
test_env(name => 'ocfp-prometheus',                  cloud_config => 'aws', cpi => 'aws');

# --- full --------------------------------------------------------------------
test_env(name => 'full-no-tls',                      cloud_config => 'aws', cpi => 'aws');
# full-provided-cert: provided cert doesnt do anything
test_env(name => 'full-self-signed-cert',            cloud_config => 'aws', cpi => 'aws');
test_env(name => 'full-all-params',                  cloud_config => 'aws', cpi => 'aws');
test_env(name => 'full-github-teams',                cloud_config => 'aws', cpi => 'aws');

# --- workers -----------------------------------------------------------------
test_env(
	name         => 'workers-custom-exodus-mount',
	exodus       => 'workers-custom-exodus-mount',
	cloud_config => 'aws',
	cpi          => 'aws',
);

# --- resolute ----------------------------------------------------------------
test_env(name => 'resolute',                         cloud_config => 'aws', cpi => 'aws');
test_env(name => 'resolute-no-haproxy',              cloud_config => 'aws', cpi => 'aws');
test_env(name => 'resolute-small-footprint',         cloud_config => 'aws', cpi => 'aws');
test_env(name => 'resolute-mgmt',                    cloud_config => 'aws', cpi => 'aws');

# The two envs below are rejected by the blueprint at every step, so all
# three matchers are set; declaring genesis_check alone would stop the
# pipeline there and retire the manifest assertion.
test_env(
	name            => 'resolute-wrong-stemcell-os',
	cloud_config    => 'aws',
	cpi             => 'aws',
	output_matchers => {
		genesis_add_secrets => qr/stemcell os to/,
		genesis_check       => qr/stemcell os to/,
		genesis_manifest    => qr/stemcell os to/,
	},
);
test_env(
	name            => 'resolute-stemcell-without-feature',
	cloud_config    => 'aws',
	cpi             => 'aws',
	output_matchers => {
		genesis_add_secrets => qr/Enable the feature and remove that parameter/,
		genesis_check       => qr/Enable the feature and remove that parameter/,
		genesis_manifest    => qr/Enable the feature and remove that parameter/,
	},
);

done_testing;
