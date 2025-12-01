# AppCat PoC - Crossplane 2.0 Function

This repository contains a proof-of-concept implementation for Crossplane 2.0 composition functions with KCL-based configuration.

## Structure

```
appcat-poc/
├── kcl/              # KCL configuration for service definitions
│   └── ...           # KCL modules, schemas, and templates
└── poc-xfn2/         # Crossplane Function implementation
    ├── *.go          # Go source files
    ├── Dockerfile    # Container image definition
    ├── Makefile      # Build system
    └── package/      # Crossplane Function metadata
```

## Components

### poc-xfn2 - Crossplane Function

A Crossplane 2.0 composition function written in Go that:
- Implements gRPC-based function runtime
- Uses generic BaseState pattern for resource management
- Supports template-driven configuration from KCL
- Exports connection details for managed resources

**Key Features:**
- Zero-boilerplate state management with reflection-based BaseState
- Template rendering with `__PLACEHOLDER__` syntax
- Multi-instance support (dynamic namespace/secret naming)
- Password persistence across updates
- Fluent API builders for Namespace, Secret, HelmRelease

**Build:**
```bash
cd poc-xfn2/
make build          # Build Go binary
make docker-build   # Build container image
make package-build  # Build Crossplane XPKG
make help           # Show all available targets
```

**Images:**
- Runtime: `ghcr.io/vshn/function-appcat-poc:latest`
- XPKG: `ghcr.io/vshn/function-appcat-poc:latest-func`

### kcl - Configuration Layer

KCL (Kubernetes Configuration Language) definitions for:
- Service templates and defaults
- Resource structure definitions
- Helm values templates
- Per-cluster configurations

**Structure:** (To be documented)

## Current Implementation

### Phase 1: Core Infrastructure ✅
- ✅ Minimal XRD (RedisPoc API)
- ✅ Fluent builders (Namespace, Secret, HelmRelease)
- ✅ Generic BaseState pattern
- ✅ Connection details export
- ✅ Password persistence

### Phase 2: Template Configuration (75%)
- ✅ RenderTemplate() helper function
- ✅ Runtime name derivation (multi-instance support)
- ✅ Template rendering in buildRedisDesired()
- ⏳ KCL helmValuesTemplate integration (blocked: needs KCL structure documentation)

### Phase 3: Build Infrastructure ✅
- ✅ Dockerfile (Alpine 3.15, non-root)
- ✅ Makefile (self-contained build system)
- ✅ Crossplane Function metadata (requires 2.0+)
- ✅ Container and XPKG build targets

## Development

### Prerequisites
- Go 1.24+
- Docker
- Crossplane 2.0+ cluster (for testing)

### Quick Start

1. **Build the function:**
   ```bash
   cd poc-xfn2/
   make build
   ```

2. **Test locally:**
   ```bash
   ./function-appcat-poc
   ```

3. **Build and push:**
   ```bash
   make release IMG_TAG=v0.1.0
   ```

### Local Development with Kind

Build for local registry:
```bash
cd poc-xfn2/
make package-push-local  # Pushes to localhost:5000
```

## Architecture Highlights

### BaseState Generic Pattern

Eliminates boilerplate for state management:

```go
// Define resources
type redisResources struct {
    Namespace *corev1.Namespace
    Secret    *corev1.Secret
    Helm      client.Object
}

// Use BaseState - get Desired() and SetObserved() for free!
type redisState = BaseState[redisResources]

func newRedisState() *redisState {
    return NewBaseState[redisResources]([]ResourceDescriptor{
        {Name: "namespace", Type: reflect.TypeOf(&corev1.Namespace{})},
        {Name: "redis-secret", Type: reflect.TypeOf(&corev1.Secret{}), Optional: true},
        {Name: "helmrelease", Type: nil},  // nil = keep as Unstructured
    })
}
```

### Template-Driven Configuration

Hybrid approach where KCL provides templates and Go renders with runtime values:

```go
helmValuesJSON := RenderTemplate(cfg["helmValuesTemplate"], map[string]string{
    "__SECRET_NAME__": secretName,
    "__NAMESPACE__":   targetNamespace,
})
```

### Runtime Name Derivation

Multi-instance support via dynamic naming:
```go
compositeName := svc.desiredComposite.GetName()
targetNamespace := fmt.Sprintf("vshn-redis-%s", compositeName)  // "vshn-redis-my-instance"
secretName := fmt.Sprintf("%s-helm-secret", compositeName)       // "my-instance-helm-secret"
```

## Progress Tracking

See [`poc-xfn2/PROGRESS.md`](poc-xfn2/PROGRESS.md) for detailed implementation progress.

## License

(To be determined)