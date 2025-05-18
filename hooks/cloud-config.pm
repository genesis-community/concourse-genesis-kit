#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::CloudConfig::Concourse v2.7.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

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

sub perform {
  my ($self) = @_;
  return 1 if $self->completed;

  my $network_name = $self->env->lookup('params.concourse_network', 'concourse');
  my $is_ocfp = $self->env->want_feature('ocfp');
  my $env_scale = $is_ocfp ? $self->env->lookup('meta.ocfp.env.scale', 'dev') : 'default';

  my $config = $self->build_cloud_config({
    'networks' => [
      $self->network_definition($network_name,
        strategy => $is_ocfp ? 'ocfp' : 'manual',
        dynamic_subnets => {
          allocation => {
            size => 16,
            statics => 5,
          },
          cloud_properties_for_iaas => {
            openstack => {
              'net_id' => $self->network_reference('id'),
              'security_groups' => ['default', 'concourse'],
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
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.large',
              prod => 'm5.xlarge'
            }, 't3.large'),
            'ephemeral_disk' => {
              'size' => 40,
              'type' => 'gp2'
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
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.xlarge',
              prod => 'm5.2xlarge'
            }, 't3.xlarge'),
            'ephemeral_disk' => {
              'size' => 80,
              'type' => 'gp2'
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
          aws => {
            'type' => 'gp2',
          },
        },
      ),
    ],
  });

  $self->done($config);
}

1;

