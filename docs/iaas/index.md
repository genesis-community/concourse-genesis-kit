# IaaS-Specific Configurations

The Concourse Genesis Kit supports deployment across multiple infrastructure providers. This document provides guidance on configuring Concourse for specific Infrastructure as a Service (IaaS) platforms.

## Supported IaaS Providers

The kit currently has specific optimizations and configurations for:

- [AWS](#aws-amazon-web-services)
- [Azure](#azure)
- [STACKIT](#stackit)
- [vSphere](#vsphere)
- [OpenStack](#openstack)
- [GCP](#gcp-google-cloud-platform)

Each IaaS may require specific configurations for networking, load balancing, VM types, and more.

## Common IaaS Considerations

For all IaaS deployments, consider these common elements:

### VM Types

Ensure your cloud config defines appropriate VM types for Concourse roles:

```yaml
params:
  concourse_vm_type: concourse          # For web and other components
  worker_vm_type: concourse-worker      # For worker nodes (needs more resources)
  haproxy_vm_type: concourse-haproxy    # For HAProxy (if used)
```

### Networks

Define appropriate networks in your cloud config and reference them:

```yaml
params:
  concourse_network: concourse
```

### Availability Zones

Specify which availability zones to deploy across:

```yaml
params:
  availability_zones: [z1, z2, z3]
```

### External Access

Configure how Concourse is accessed externally:

```yaml
params:
  external_domain: concourse.example.com
```

## AWS (Amazon Web Services)

AWS is a fully supported IaaS platform for Concourse deployments.

### Networking Configuration

In AWS, you'll typically deploy Concourse in a VPC with public and private subnets:

- Web/HAProxy nodes in public subnets
- Workers and database in private subnets

### Load Balancing

For AWS deployments, use the `dynamic-web-ip` feature with an AWS load balancer:

```yaml
kit:
  features:
    - dynamic-web-ip

params:
  web_vm_extension: elb    # Ensure this extension is defined in cloud config
```

### RDS Integration

For production deployments, consider using Amazon RDS with the `external-db` feature:

```yaml
kit:
  features:
    - external-db

params:
  external_db_host: my-concourse-db.abcdef123456.us-east-1.rds.amazonaws.com
  external_db_port: 5432
  external_db_name: concourse
  external_db_user: concourse
  external_db_sslmode: verify-ca
```

## Azure

Azure is supported for Concourse deployments with some specific considerations.

### Networking Configuration

In Azure, you'll typically deploy using Azure Virtual Networks (VNets):

- Configure your cloud config with appropriate network definitions
- Use Network Security Groups (NSGs) to control access

### Availability Sets

Azure uses Availability Sets for high availability:

```yaml
params:
  availability_zones:
  - z1  # In Azure, this maps to an availability set
```

This feature is enabled through the `azure.yml` addon file.

### Load Balancing

For Azure, use Azure Load Balancer with the `dynamic-web-ip` feature:

```yaml
kit:
  features:
    - dynamic-web-ip

params:
  web_vm_extension: azure-lb
```

### Managed Database

Consider using Azure Database for PostgreSQL with the `external-db` feature.

## STACKIT

STACKIT is a European cloud provider that was added in version 3.13.0 of the kit.

### Networking Configuration

STACKIT networking has some similarities to OpenStack:

- Configure your cloud config with appropriate STACKIT network definitions
- Ensure security groups allow necessary traffic

### Load Balancing

For STACKIT, use their load balancer offering with the `dynamic-web-ip` feature:

```yaml
kit:
  features:
    - dynamic-web-ip

params:
  web_vm_extension: stackit-lb
```

### Storage Configuration

Configure appropriate storage classes in your cloud config for STACKIT:

```yaml
params:
  concourse_disk_type: stackit-persistent
```

### OCFP Integration with STACKIT

When using the OCFP feature with STACKIT, specific optimizations are automatically applied through the configuration in `ocfp/iaas/stackit.yml`.

## vSphere

vSphere is a well-supported platform for on-premises Concourse deployments.

### Resource Pools

Ensure your cloud config defines appropriate resource pools:

```yaml
params:
  concourse_vm_type: concourse-medium      # Maps to a vSphere resource pool
  worker_vm_type: concourse-worker-large   # Maps to a vSphere resource pool
```

### Networks

Configure appropriate vSphere networks in your cloud config:

```yaml
params:
  concourse_network: concourse-network     # Maps to a vSphere network
```

### Storage

Define appropriate disks in your cloud config:

```yaml
params:
  concourse_disk_type: concourse-persistent  # Maps to a vSphere datastore
```

### External Access

For vSphere deployments, you may need to configure a load balancer externally:

```yaml
kit:
  features:
    - dynamic-web-ip

params:
  web_vm_extension: vsphere-lb
  external_domain: concourse.internal
```

## OpenStack

OpenStack is supported for Concourse deployments with specific considerations.

### Flavors and Images

Map OpenStack flavors to VM types in your cloud config:

```yaml
params:
  concourse_vm_type: concourse-medium    # Maps to an OpenStack flavor
  worker_vm_type: concourse-worker       # Maps to an OpenStack flavor
```

### Networks

Configure appropriate OpenStack networks:

```yaml
params:
  concourse_network: concourse-net       # Maps to an OpenStack network
```

### Floating IPs

For external access, configure floating IPs:

```yaml
kit:
  features:
    - dynamic-web-ip

params:
  web_vm_extension: openstack-floating-ip
```

## GCP (Google Cloud Platform)

GCP is supported for Concourse deployments with specific considerations.

### Machine Types

Map GCP machine types to VM types in your cloud config:

```yaml
params:
  concourse_vm_type: concourse-n1-standard-2   # Maps to a GCP machine type
  worker_vm_type: concourse-n1-standard-4      # Maps to a GCP machine type
```

### Networks

Configure appropriate GCP networks:

```yaml
params:
  concourse_network: concourse-network       # Maps to a GCP network
```

### Load Balancing

For GCP, use Cloud Load Balancing:

```yaml
kit:
  features:
    - dynamic-web-ip

params:
  web_vm_extension: gcp-lb
```

### Cloud SQL Integration

For production deployments, consider using Cloud SQL with the `external-db` feature.

## Best Practices Across IaaS Platforms

### High Availability

For production deployments:
- Deploy at least 2 web nodes
- Use multiple availability zones
- Configure external databases with replication
- Use a load balancer for web node access

### Scaling Workers

Scale worker count based on workload:
- For light use: 3-5 workers
- For moderate use: 5-10 workers
- For heavy use: 10+ workers with appropriate VM sizing

### Performance Tuning

Optimize based on IaaS capabilities:
- Use SSD-backed storage for the database
- Select VM types with appropriate CPU/memory for workers
- Use instance store/ephemeral disks for temporary storage when available

### Security

Each IaaS has unique security considerations:
- Use private networks for worker and database communication
- Restrict public access to only the web nodes or load balancer
- Configure appropriate security groups/firewalls
- Use managed database services with encryption at rest