#!/usr/bin/env perl
# Unit coverage for the policy text hooks/addon-setup-approle~ar.pm writes for
# the concourse and genesis-pipelines app roles.
#
# On a lab with GENESIS_SECRETS_MOUNT=/secret/ and
# GENESIS_EXODUS_MOUNT=/secret/exodus/ on a kv v2 mount, the addon used to
# write "/secret//*" and "/secret/data/exodus//*". Policy paths are matched
# literally, so the doubled slashes granted nothing. These tests drive the
# pure path-building helpers directly across kv v1 and v2 mounts, sub-paths
# with and without slashes, a secrets path equal to its mount, and nested
# mounts, and assert no rendered path ever carries an empty segment.
#
# Requires the real genesis Perl library on GENESIS_LIB or ~/.genesis/lib,
# same as the hook itself expects.

use v5.20;
use warnings;
use FindBin;
use Test::More;

require "$FindBin::Bin/../hooks/addon-setup-approle~ar.pm";

my $pkg = 'Genesis::Hook::Addon::Concourse::SetupApprole';
sub call { my $fn = shift; no strict 'refs'; return &{"${pkg}::$fn"}(@_); }

my $READ  = '{ capabilities = ["read", "list"] }';
my $WRITE = '{ capabilities = ["create", "read", "update", "list", "delete"] }';
my $ALL   = '{ capabilities = ["create", "read", "update", "delete", "list", "sudo"] }';

# Abridged `vault secrets list --detailed` from OpenBao 2.7.0, with a nested
# kv v2 mount under secret/, a kv v1 mount, a kv mount with no version option,
# and non-kv mounts that must be ignored.
my $SECRETS_LIST = <<'EOF';
Path              Plugin       Accessor              Default TTL    Max TTL    Force No Cache    Replication    Seal Wrap    External Entropy Access    Options           Description                                                UUID
----              ------       --------              -----------    -------    --------------    -----------    ---------    -----------------------    -------           -----------                                                ----
cubbyhole/        cubbyhole    cubbyhole_4b7c8a31    n/a            n/a        false             local          false        false                      map[]             per-token private secret storage                           1d0f0b1e
identity/         identity     identity_8e2d7a55     system         system     false             replicated     false        false                      map[]             identity store                                             2c3e4f5a
legacy/           kv           kv_0a1b2c3d           system         system     false             replicated     false        false                      map[version:1]    legacy v1 store                                            3d4e5f6a
plain/            kv           kv_1b2c3d4e           system         system     false             replicated     false        false                      map[]             kv with no version option                                  4e5f6a7b
secret/           kv           kv_2c3d4e5f           system         system     false             replicated     false        false                      map[version:2]    key/value secret storage                                   5f6a7b8c
secret/exodus/    kv           kv_3d4e5f6a           system         system     false             replicated     false        false                      map[version:2]    nested exodus store                                        6a7b8c9d
sys/              system       system_9f8e7d6c       n/a            n/a        false             replicated     true         false                      map[]             system endpoints used for control, policy and debugging    7b8c9d0e
EOF

sub no_empty_segments {
	my ($policy, $name) = @_;
	my @paths = $policy =~ /^path "([^"]*)"/mg;
	ok(scalar(@paths), "$name renders at least one path");
	for my $p (@paths) {
		unlike($p, qr{//}, "$name: '$p' has no empty segment");
		unlike($p, qr{^/}, "$name: '$p' has no leading slash");
	}
}

# --- path normalisation -------------------------------------------------------

subtest '_normalize_path collapses and trims slashes' => sub {
	is(call('_normalize_path', '/secret/'),          'secret',        'mount with both slashes');
	is(call('_normalize_path', 'secret'),            'secret',        'bare mount');
	is(call('_normalize_path', '//secret//exodus/'), 'secret/exodus', 'doubled slashes');
	is(call('_normalize_path', ''),                  '',              'empty path');
	is(call('_normalize_path', undef),               '',              'undefined path');
	is(call('_normalize_path', '/'),                 '',              'lone slash');
};

# --- mount parsing and matching -------------------------------------------------

subtest '_parse_kv_mounts keeps only kv mounts, with versions' => sub {
	my @mounts = call('_parse_kv_mounts', $SECRETS_LIST);
	is_deeply(\@mounts, [
		[ 'legacy',        '1' ],
		[ 'plain',         '1' ],
		[ 'secret',        '2' ],
		[ 'secret/exodus', '2' ],
	], 'kv mounts found, a kv mount with no version option is v1');
};

subtest '_longest_mount_match picks the most specific mount' => sub {
	my @mounts = call('_parse_kv_mounts', $SECRETS_LIST);
	# Listing order must not matter.
	my @reversed = reverse @mounts;

	for my $set ([ 'listed order', \@mounts ], [ 'reversed order', \@reversed ]) {
		my ($label, $m) = @$set;
		is_deeply(call('_longest_mount_match', '/secret/exodus/', @$m),
			[ 'secret/exodus/', '', '2' ], "$label: nested mount wins for its own root");
		is_deeply(call('_longest_mount_match', '/secret/exodus/lab/concourse', @$m),
			[ 'secret/exodus/', 'lab/concourse', '2' ], "$label: nested mount wins for a sub-path");
		is_deeply(call('_longest_mount_match', '/secret/', @$m),
			[ 'secret/', '', '2' ], "$label: secrets path equal to the mount");
		is_deeply(call('_longest_mount_match', '/secret/lab/', @$m),
			[ 'secret/', 'lab', '2' ], "$label: outer mount for a sibling sub-path");
	}

	is_deeply(call('_longest_mount_match', 'secret', @mounts),
		[ 'secret/', '', '2' ], 'path without any slashes still matches');
	is(call('_longest_mount_match', '/secretive/lab/', @mounts),
		undef, 'a mount only matches on a whole segment');
	is(call('_longest_mount_match', '/nowhere/', @mounts),
		undef, 'unknown mount returns undef');
};

# --- genesis-pipelines policy -------------------------------------------------

subtest 'pipelines policy: the lab case, kv v2 with the secrets path at the mount' => sub {
	# secret/exodus/ is not its own mount here, only secret/ is.
	my @mounts = ([ 'secret', '2' ]);
	my $sec = call('_longest_mount_match', '/secret/', @mounts);
	my $exo = call('_longest_mount_match', '/secret/exodus/', @mounts);
	my $policy = call('_pipelines_policy', $sec, $exo);

	is($policy,
		"# Allow the pipelines to read deployment secrets, and write genesis exodus data\n\n".
		"path \"secret/data/*\" $READ\n".
		"path \"secret/metadata/*\" $READ\n".
		"path \"secret/data/exodus/*\" $WRITE\n".
		"path \"secret/metadata/exodus/*\" $WRITE\n",
		'renders data/ and metadata/ rules with no doubled slashes');
	no_empty_segments($policy, 'lab case');
};

subtest 'pipelines policy: kv v2 sub-paths with and without slashes' => sub {
	for my $sub ('lab', 'lab/', '/lab', '/lab/', 'lab//') {
		my $policy = call('_pipelines_policy', [ 'secret/', $sub, '2' ], [ '/secret/', "exodus$sub", '2' ]);
		like($policy, qr{^path "secret/data/lab/\*" \Q$READ\E$}m,     "secrets data rule for '$sub'");
		like($policy, qr{^path "secret/metadata/lab/\*" \Q$READ\E$}m, "secrets metadata rule for '$sub'");
		no_empty_segments($policy, "sub-path '$sub'");
	}
};

subtest 'pipelines policy: kv v1 mounts' => sub {
	my @mounts = ([ 'legacy', '1' ]);
	for my $case (
		[ '/legacy/',             '/legacy/exodus/',  'legacy/*',     'legacy/exodus/*' ],
		[ '/legacy/lab/',         '/legacy/exodus',   'legacy/lab/*', 'legacy/exodus/*' ],
		[ 'legacy',               'legacy/exodus//',  'legacy/*',     'legacy/exodus/*' ],
	) {
		my ($sec_path, $exo_path, $want_sec, $want_exo) = @$case;
		my $policy = call('_pipelines_policy',
			call('_longest_mount_match', $sec_path, @mounts),
			call('_longest_mount_match', $exo_path, @mounts));
		is($policy,
			"# Allow the pipelines to read deployment secrets, and write genesis exodus data\n\n".
			"path \"$want_sec\" $READ\n".
			"path \"$want_exo\" $WRITE\n",
			"kv v1 secrets '$sec_path' and exodus '$exo_path'");
		no_empty_segments($policy, "kv v1 '$sec_path'");
	}
};

subtest 'pipelines policy: nested exodus mount' => sub {
	my @mounts = call('_parse_kv_mounts', $SECRETS_LIST);
	my $policy = call('_pipelines_policy',
		call('_longest_mount_match', '/secret/', @mounts),
		call('_longest_mount_match', '/secret/exodus/', @mounts));
	is($policy,
		"# Allow the pipelines to read deployment secrets, and write genesis exodus data\n\n".
		"path \"secret/data/*\" $READ\n".
		"path \"secret/metadata/*\" $READ\n".
		"path \"secret/exodus/data/*\" $WRITE\n".
		"path \"secret/exodus/metadata/*\" $WRITE\n",
		'exodus rules sit under the nested mount, not secret/data/exodus');
	no_empty_segments($policy, 'nested mount');
};

subtest 'pipelines policy: mixed kv versions' => sub {
	my @mounts = call('_parse_kv_mounts', $SECRETS_LIST);
	my $policy = call('_pipelines_policy',
		call('_longest_mount_match', '/legacy/lab/', @mounts),
		call('_longest_mount_match', '/secret/exodus/lab/', @mounts));
	is($policy,
		"# Allow the pipelines to read deployment secrets, and write genesis exodus data\n\n".
		"path \"legacy/lab/*\" $READ\n".
		"path \"secret/exodus/data/lab/*\" $WRITE\n".
		"path \"secret/exodus/metadata/lab/*\" $WRITE\n",
		'each rule follows its own mount version');
};

# --- concourse policy ----------------------------------------------------------

subtest 'concourse policy' => sub {
	for my $mount ('concourse', '/concourse', '/concourse/', 'concourse//') {
		is(call('_concourse_policy', $mount, '2'),
			"# List, create, update, and delete key/value secrets for Concourse\n".
			"path \"concourse/data/*\" $ALL\n".
			"path \"concourse/metadata/*\" $ALL\n",
			"kv v2 mount spelled '$mount'");
		is(call('_concourse_policy', $mount, '1'),
			"# List, create, update, and delete key/value secrets for Concourse\n".
			"path \"concourse/*\" $ALL\n",
			"kv v1 mount spelled '$mount'");
	}
};

done_testing;
