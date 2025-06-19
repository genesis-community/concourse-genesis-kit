package Genesis::Hook::CloudConfig::Concourse;

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
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
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
  my $is_ocfp = $self->want_feature('ocfp');
  my $env_scale = $is_ocfp ? $self->env->lookup('meta.ocfp.env.scale', 'dev') : 'default';

  my $config = $self->build_cloud_config({
    'networks' => [
      $self->network_definition($network_name,
        strategy => $is_ocfp ? 'ocfp' : 'manual',
        dynamic_subnets => {
          allocation => {
            size => 12, #was 16
            statics => 5,
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
              'subnet' => $self->network_reference('subnet_ids.0'),
              'security_groups' => ['concourse'],
            },
          },
        },
      )
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
              dev => 'm1.2',
              prod => 'g1.3'
            }, 'm1.3'),
            'root_disk' => {
              'size' => 40 # in gigabytes
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
                prod => gigabytes(128)
              }, gigabytes(64)),
              'type' => 'gp3'
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
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
              dev => 'g1.3',
              prod => 'g1.4'
            }, 'm1.3'),
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
