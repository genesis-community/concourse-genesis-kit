package Genesis::Hook::CloudConfig::Concourse v5.1.0;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw//;
use JSON::PP;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub stackit_subnet_reference {
	my ($self, $property) = @_;
	# Custom method to handle stackit's 1:1 network:subnet relationship
	# This extracts subnet information directly instead of using network references
	return $self->subnet_reference($property);
}

sub perform {
  my ($self) = @_;
  return 1 if $self->completed;

  my $network_name = $self->env->lookup('params.concourse_network', 'concourse');
  my $network_web_name = $self->env->lookup('params.concourse_web_network', 'concourse-web'); # Used by AWS
  my $is_ocfp = $self->want_feature('ocfp');
  my $env_scale = $is_ocfp ? $self->env->lookup('meta.ocfp.env.scale', 'dev') : 'default';

	my $topology = $self->env->ocfp_config_lookup('net.topology', 'v2');

  my $config = $self->build_cloud_config({
    'networks' => [
      $self->network_definition($network_name,
        strategy => $is_ocfp ? 'ocfp' : 'manual',
        dynamic_subnets => {
          allocation => {
            total_size => $topology eq 'v1' ? 0 : 16
          },
          cloud_properties_for_iaas => {
            openstack => {
              'net_id' => $self->network_reference('id'),
              'security_groups' => ['default', 'concourse'],
            },
            stackit => {
              'net_id' => $self->network_reference('id'),
	            'security_groups' => $self->network_reference('sgs', 'get_sgs_by_names', 'ocfp', 'default'),
            },
            aws => {
              'subnet' => $self->subnet_reference('id'),
	            'security_groups' => $self->get_network_security_groups(),
            },
            pve => {
              'bridge' => scalar($self->env->lookup('bosh-configs.cpi.pve_network_bridge', 'lvnet001')),
            },
          },
        },
      ),
      $topology eq 'v1' ? $self->network_definition($network_web_name,
        strategy => $is_ocfp ? 'ocfp' : 'manual',
        dynamic_subnets => {
          subnets => ['ocfp-0'],
          allocation => {
            total_size => 0,
          },
          cloud_properties_for_iaas => {
            openstack => {
              'net_id' => $self->network_reference('id'),
              'security_groups' => ['default', 'concourse-web'],
            },
            stackit => {  # STACKIT most likely will use the IaaS Load-balancer for access
              'net_id' => $self->network_reference('id'),
              'security_groups' => $self->network_reference('sgs', 'get_sgs_by_names', 'ocfp', 'default'),
            },
            aws => {
              'subnet' => $self->subnet_reference('id'),
              'security_groups' => $self->get_network_security_groups(),
            },
            pve => {
              'bridge' => scalar($self->env->lookup('bosh-configs.cpi.pve_network_bridge', 'lvnet001')),
            },
          },
        },
      ) : (),
    ],
    'vm_types' => [
      $self->vm_type_definition('concourse',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.large',
              prod => 'm1.xlarge'
            }, 'm1.large'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 40 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1a.2d',
              prod => 'g1a.4d'
            }, 'm1a.4d'),
            'root_disk' => {
              'size' => 40 # in gigabytes
            },
          },
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.large',
              prod => 'm6i.large'
            }, 't3.large'),
            'ephemeral_disk' => {
              'encrypted' => $self->TRUE,
              'size' => $self->for_scale({
                dev => gigabytes(64),
                prod => gigabytes(128)
              }, gigabytes(64)),
              'type' => 'gp3'
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
          pve => {
            'cpu'            => scalar($self->env->lookup('bosh-configs.cpi.pve_concourse_cpu',  $self->for_scale({ dev => 2, prod => 4 }, 2))),
            'ram'            => scalar($self->env->lookup('bosh-configs.cpi.pve_concourse_ram',  $self->for_scale({ dev => 4096, prod => 8192 }, 4096))),
            'disk'           => scalar($self->env->lookup('bosh-configs.cpi.pve_concourse_disk', $self->for_scale({ dev => 40960, prod => 81920 }, 40960))),
            'network_bridge' => scalar($self->env->lookup('bosh-configs.cpi.pve_network_bridge', 'lvnet001')),
          },
        },
      ),
      $self->vm_type_definition('concourse-worker',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.xlarge',
              prod => 'm1.2xlarge'
            }, 'm1.xlarge'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 80 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'g1a.2d',
              prod => 'g1a.4d'
            }, 'm1a.2d'),
            'root_disk' => {
              'size' => 80 # in gigabytes
            },
          },
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.large'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'encrypted' => $self->TRUE,
              'size' => $self->for_scale({
                dev => gigabytes(64),
                prod => gigabytes(256)
              }, gigabytes(64)),
              'type' => 'gp3'
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
          pve => {
            'cpu'            => scalar($self->env->lookup('bosh-configs.cpi.pve_concourse_worker_cpu',  $self->for_scale({ dev => 4, prod => 8 }, 4))),
            'ram'            => scalar($self->env->lookup('bosh-configs.cpi.pve_concourse_worker_ram',  $self->for_scale({ dev => 8192, prod => 16384 }, 8192))),
            'disk'           => scalar($self->env->lookup('bosh-configs.cpi.pve_concourse_worker_disk', $self->for_scale({ dev => 81920, prod => 163840 }, 81920))),
            'network_bridge' => scalar($self->env->lookup('bosh-configs.cpi.pve_network_bridge', 'lvnet001')),
          },
        },
      ),
    ],
    'disk_types' => [
      $self->disk_type_definition('concourse',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(64),
            prod => gigabytes(256)
          }, gigabytes(64)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf6',
          },
          stackit => {
            'type' => 'storage_premium_perf6',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
          pve => {
            'storage'     => scalar($self->env->lookup('bosh-configs.cpi.pve_disk_storage', 'zfs-1')),
            'disk_format' => scalar($self->env->lookup('bosh-configs.cpi.pve_disk_format', 'raw')),
          },
        },
      ),
    ],
  });

  # Add AWS load balancer VM extension
  if ($self->iaas eq 'aws') {
    push @{$config->{vm_extensions}}, {
      name => 'concourse-lb',
      cloud_properties => {
        lb_target_groups => ['ocfp-mgmt-concourse-lb-tg']
      }
    };
  }

  $self->done($config);

  return 1;

}

sub get_sgs_by_names {
	my ($self, $subnet_data, $ref, @names) = @_;
	my @ids = map {$subnet_data->{$ref}{$_}{id}} @names;
	# TODO: Error checking
	return \@ids
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
