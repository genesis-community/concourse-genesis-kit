# Container Runtime Options in Concourse

Concourse worker nodes use a container runtime to isolate and execute tasks in your pipelines. The Concourse Genesis Kit supports multiple container runtime options through the `container_runtime` parameter. This document explains the available options and when to use each one.

## Overview

The `container_runtime` parameter determines which container backend will be used on worker nodes. As of version 3.13.0, the following options are available:

- `containerd` (default)
- `guardian`
- `houdini`

Each runtime has different characteristics, performance profiles, and compatibility considerations.

## Configuring the Container Runtime

To configure the container runtime, set the `container_runtime` parameter in your environment file:

```yaml
params:
  container_runtime: containerd  # Options: containerd, guardian, houdini
```

If not specified, the runtime defaults to `containerd`.

## Containerd

### Overview

Containerd is the default container runtime in Concourse starting with version 7.0. It is a lightweight container runtime that provides better performance and resource utilization compared to Guardian.

### Key Features

- Open Container Initiative (OCI) compliant
- Lightweight and high-performance
- Improved resource utilization
- Better isolation between containers
- Faster container startup times

### When to Use Containerd

Containerd is the recommended choice for most deployments because it offers:

- Better performance characteristics
- Lower resource overhead
- Improved security isolation
- Compatibility with modern container standards

### Configuration

To use Containerd (default option):

```yaml
params:
  container_runtime: containerd
```

### Considerations

- Requires a Linux kernel version 4.19 or newer for optimal functionality
- May have different behavior than Guardian for certain edge cases
- The transition from Guardian to Containerd might require adjustments to pipeline tasks

## Guardian

### Overview

Guardian (also known as Garden-runC) was the default container runtime for Concourse before version 7.0. It is a container runtime that focuses on strong isolation guarantees.

### Key Features

- Strong isolation guarantees
- Mature and well-tested
- Compatible with older Concourse workloads
- Fine-grained resource limiting

### When to Use Guardian

Consider using Guardian when:

- You have legacy pipelines that rely on Guardian-specific behavior
- You're upgrading from older Concourse versions and want to maintain consistent behavior
- You encounter compatibility issues with Containerd

### Configuration

To use Guardian:

```yaml
params:
  container_runtime: guardian
```

### Considerations

- Higher resource overhead compared to Containerd
- Slower container startup times
- Will eventually be deprecated in future Concourse versions

## Houdini

### Overview

Houdini is a "fake" container runtime that doesn't provide actual process isolation. It executes processes directly on the worker VM, making it useful for development or testing environments, particularly on Windows where container isolation is more complex.

### Key Features

- No actual container isolation
- Lightweight (no container overhead)
- Works on all platforms, including Windows
- Faster task execution (no container startup time)

### When to Use Houdini

Houdini is appropriate for:

- Development or testing environments
- Windows worker nodes where container isolation is not required
- Scenarios where absolute performance is prioritized over isolation

### Configuration

To use Houdini:

```yaml
params:
  container_runtime: houdini
```

### Considerations

- **No process isolation** - tasks run directly on the worker VM
- **No security boundaries** between tasks
- **Not recommended for production** environments with untrusted code
- Tasks may interfere with each other or the worker VM

## Runtime Comparison

| Feature | Containerd | Guardian | Houdini |
|---------|------------|----------|---------|
| Isolation | Strong | Strong | None |
| Performance | High | Moderate | Very High |
| Resource Overhead | Low | Moderate | Minimal |
| Container Startup Time | Fast | Slower | Instant |
| Compatibility | Modern | Legacy | Limited |
| Platform Support | Linux | Linux | All |
| Production Use | Recommended | Supported | Not Recommended |
| Memory Usage | Lower | Higher | Lowest |

## Volume Driver Configuration

In addition to the container runtime, you can configure the volume driver using the `volume_driver` parameter:

```yaml
params:
  volume_driver: detect  # Default option
```

Options include:
- `detect` - Automatically detect the appropriate driver
- `naive` - Simple directory-based driver
- `btrfs` - BTRFS filesystem driver
- `overlay` - OverlayFS driver

The appropriate volume driver depends on the container runtime and the underlying filesystem.

## Best Practices

1. **Use Containerd for New Deployments**: 
   - Start with Containerd for new deployments as it's the default and preferred runtime

2. **Test Migration from Guardian**:
   - When migrating from Guardian to Containerd, test your pipelines extensively

3. **Use Houdini Only for Development**:
   - Avoid Houdini in production environments due to lack of isolation

4. **Consider Workload Characteristics**:
   - For memory-constrained environments, Containerd offers better efficiency
   - For legacy workloads, Guardian may provide more consistent behavior

5. **Monitor Resource Usage**:
   - Different runtimes have different resource profiles; monitor accordingly

## Troubleshooting

### Common Issues with Containerd

1. **Incompatible Kernel**:
   - **Symptom**: Worker fails to start with kernel-related errors
   - **Solution**: Upgrade to a newer kernel or switch to Guardian

2. **Task Failures After Migration**:
   - **Symptom**: Tasks that worked with Guardian fail with Containerd
   - **Solution**: Check for assumptions about container environment

### Common Issues with Guardian

1. **High Memory Usage**:
   - **Symptom**: Workers consume excessive memory
   - **Solution**: Consider switching to Containerd or increasing worker resources

2. **Slow Task Startup**:
   - **Symptom**: Tasks take a long time to start
   - **Solution**: Switch to Containerd for better performance

### Common Issues with Houdini

1. **Task Interference**:
   - **Symptom**: Tasks affect each other unexpectedly
   - **Solution**: Use a proper container runtime with isolation

2. **Security Concerns**:
   - **Symptom**: Tasks can affect worker VM directly
   - **Solution**: Switch to Containerd or Guardian for production