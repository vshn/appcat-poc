# AppCat KCL PoC

KCL-based configuration management for VSHN AppCat services. This proof-of-concept demonstrates migrating PostgreSQL service from Jsonnet/Project Syn to KCL with Crossplane 2.0.

## Overview

This PoC replaces the complex vars.jsonnet conditional logic with a clean, type-safe KCL hierarchy that prioritizes **split-mode** and **platform detection** as first-class configuration dimensions.

### Key Features

- **Type-safe schemas** for platform (OpenShift vs Kubernetes) and cluster mode (converged/control_plane/service_cluster)
- **Platform-specific resource generation** with automatic detection
- **Split-mode architecture** with proper ProviderConfig for cross-cluster management
- **Crossplane 2.0 Pipeline mode** compositions with proper metadata
- **Build automation** with Makefile and scripts
- **End-to-end testing** with Kind clusters

## Architecture

### Configuration Hierarchy and Merge Order

The PoC implements a **4-level hierarchy** with **explicit merge order** following KCL best practices:

```
Priority (low → high):
1. modes/           Base configuration (which components enabled)
2. platforms/       Platform-specific helpers (used by services)
3. defaults/        Default values (images, resources, plans)
4. clusters/        Cluster-specific overrides (FINAL - highest priority)
```

**Key Principle from KCL docs:**
> "Use `:` in the common configurations, and `=` for override in the environment-specific configurations."

**How merge order is made explicit:**

```python
# clusters/dev-1/main.k
import modes.converged as modeConfig
import clusters.dev_1.facts as facts

# Explicit merge using ** (unpack) and = (override)
config = {
    **modeConfig.config              # BASE: start with mode config
    platform = facts.platform        # OVERRIDE: cluster-specific platform
    mode = facts.clusterMode         # OVERRIDE: cluster-specific mode
}
```

The **`**` (unpack)** operator makes it visually clear:
- Start with `modeConfig.config`
- Then override specific fields

The **`=` (override)** operator shows explicit replacement (not merge).

**See [MERGE_ORDER.md](./MERGE_ORDER.md) for complete documentation.**

### KCL Operators Explained

| Operator | Purpose | Semantics | Use Case |
|----------|---------|-----------|----------|
| `**` | Unpack | Start with this config | Show base configuration |
| `=` | Override | Replace value explicitly | Environment-specific overrides |
| `:` | Merge | Add/merge idempotently | Common configurations |

**Example:**
```python
# modes/converged.k (common config)
config = defs.ClusterConfig {
    components: defs.ComponentsConfig {   # : merge operator
        controller: defs.ComponentConfig {
            replicas: 1                   # : merge operator
        }
    }
}

# clusters/prod-control-plane-1/main.k (environment override)
config = {
    **modeConfig.config                   # ** unpack base
    components = {                        # = override operator
        **modeConfig.config.components
        controller = {
            **modeConfig.config.components.controller
            replicas = 5                  # = override: production HA
        }
    }
}
```

### Critical Improvements Over vars.jsonnet

**Before (vars.jsonnet):**
```jsonnet
// Scattered across 50+ files:
if vars.isOpenshift then { ... } else { ... }
if vars.isControlPlane then { controller: {...} }
if vars.isServiceCluster then { operators: {...} }
```

**After (KCL):**
```python
# Declarative mode configuration in cluster_catalog.k:
mode: str = option("mode") or "converged"
platform: str = option("platform") or "kubernetes"

isOpenShift = platform == "openshift"
isServiceCluster = mode == "service_cluster" or mode == "converged"
isControlPlane = mode == "control_plane" or mode == "converged"

# Platform-specific resource generation:
operatorInstall = if isServiceCluster then {
    if isOpenShift then ocp.olmOperatorInstall(...)
    else k8s.helmOperatorInstall(...)
} else {}
```

## Directory Structure

```
kcl/
├── Makefile                  # Build automation
├── README.md                 # This file
│
├── defs/                     # Shared schemas (Level 0)
│   └── base.k                # Platform, ClusterMode, ComponentConfig, ServiceSpec
│
├── modes/                    # Mode configurations (Level 1 - PRIMARY DIMENSION)
│   ├── converged.k           # Single cluster (control plane + service cluster)
│   ├── control_plane.k       # Control plane only (manages remote clusters)
│   └── service_cluster.k     # Service cluster only (runs workloads)
│
├── platforms/                # Platform-specific helpers (Level 2)
│   ├── kubernetes.k          # Helm-based operator installation, standard RBAC
│   └── openshift.k           # OLM-based operators, SCC, Routes
│
├── defaults/                 # Default values (Level 3)
│   ├── images.k              # Container image defaults
│   ├── resources.k           # Resource requests/limits defaults
│   └── plans.k               # Service plan defaults (PostgreSQL, Redis, etc.)
│
├── clusters/                 # Cluster-specific configurations (Level 4)
│   ├── dev-1/
│   │   ├── facts.k           # Cluster metadata (mode: converged, platform: kubernetes)
│   │   └── main.k            # Merged configuration
│   ├── prod-control-plane-1/
│   │   ├── facts.k           # mode: control_plane, platform: openshift
│   │   └── main.k
│   └── prod-service-1/
│       ├── facts.k           # mode: service_cluster, platform: openshift
│       └── main.k
│
├── services/                 # Service definitions
│   └── postgres/
│       ├── service.k         # Plans, versions, function ref
│       ├── xrd_data.k        # XRD (6109 lines)
│       ├── xpkg.k            # Composition + crossplane.yaml
│       ├── cluster_catalog.k # Platform/mode-specific resources (cluster-aware)
│       └── templates.k       # ConfigMap templates
│
├── platform/                 # Crossplane installation
│   └── crossplane.k          # Providers, ProviderConfigs, Function
│
└── scripts/                  # Automation scripts
    ├── split-xpkg.sh         # Split multi-doc YAML into files
    ├── package-xpkg.sh       # Package xpkg as OCI image
    ├── setup-kind.sh         # Setup Kind clusters for testing
    └── e2e-test.sh           # End-to-end tests
```

## Prerequisites

- **KCL** >= 0.10.0 ([install](https://kcl-lang.io/docs/user_docs/getting-started/install/))
- **kubectl** ([install](https://kubernetes.io/docs/tasks/tools/))
- **kind** ([install](https://kind.sigs.k8s.io/docs/user/quick-start/#installation))
- **helm** ([install](https://helm.sh/docs/intro/install/))
- **crossplane CLI** ([install](https://docs.crossplane.io/latest/cli/))
- **yq** (optional, for YAML splitting) ([install](https://github.com/mikefarah/yq))

## Quick Start

### 1. Build All Artifacts

```bash
make all
```

This generates:
- `output/platform/` - Crossplane installation manifests
- `output/xpkg/postgres/` - XRD + Composition for PostgreSQL
- `output/cluster-catalog/postgres/{mode}/{platform}/` - Platform/mode-specific resources

### 2. Setup Kind Clusters

```bash
make setup-kind
```

Creates two clusters:
- `kind-mgmt` (control plane) with Crossplane + ArgoCD
- `kind-svc` (service cluster)

### 3. Deploy Platform Resources

```bash
# Deploy Crossplane to management cluster
kubectl apply -f output/platform/crossplane-kubernetes.yaml --context kind-mgmt

# Wait for Crossplane to be ready
kubectl wait --for=condition=Available \
  --timeout=300s \
  -n crossplane-system \
  deployment/crossplane \
  --context kind-mgmt
```

### 4. Deploy PostgreSQL Service

```bash
# Deploy XRD + Composition
kubectl apply -f output/xpkg/postgres/ --context kind-mgmt

# Deploy cluster catalog to service cluster
kubectl apply -f output/cluster-catalog/postgres/service_cluster/kubernetes/ --context kind-svc
```

### 5. Create PostgreSQL Instance

```bash
cat <<EOF | kubectl apply --context kind-mgmt -f -
apiVersion: vshn.appcat.vshn.io/v1
kind: XVSHNPostgreSQL
metadata:
  name: my-postgres
  namespace: default
spec:
  parameters:
    service:
      version: "16"
    size:
      plan: standard-2
  writeConnectionSecretToRef:
    name: my-postgres-creds
EOF
```

### 6. Run Tests

```bash
make test
```

## Build Targets

| Target | Description |
|--------|-------------|
| `make all` | Build all artifacts (clean, build, validate, package) |
| `make build` | Generate all outputs from KCL |
| `make build-platform` | Generate platform manifests (Crossplane) |
| `make build-services` | Generate xpkg artifacts for services |
| `make build-catalogs` | Generate cluster catalog manifests (legacy parameter-based) |
| `make build-clusters` | **Build cluster catalogs for all defined clusters** ⭐ |
| `make build-cluster CLUSTER=dev-1` | **Build catalog for a specific cluster** ⭐ |
| `make validate` | Validate KCL configurations |
| `make package` | Package xpkg as OCI images |
| `make test` | Run end-to-end tests |
| `make setup-kind` | Setup Kind clusters |
| `make teardown-kind` | Delete Kind clusters |
| `make clean` | Clean output directories |
| `make fmt` | Format KCL files |
| `make lint` | Lint KCL files |
| `make docs` | Generate documentation |

## Configuration Options

### Cluster-Based Configuration (Recommended)

The PoC now supports cluster-based configuration that eliminates parameter passing:

```bash
# Build catalog for a specific cluster (mode and platform from cluster config)
make build-cluster CLUSTER=dev-1

# Build catalogs for all defined clusters
make build-clusters

# Output structure:
# output/cluster-catalog/clusters/
# ├── dev-1/postgres/catalog.yaml                    # converged + kubernetes
# ├── prod-control-plane-1/postgres/catalog.yaml    # control_plane + openshift
# └── prod-service-1/postgres/catalog.yaml          # service_cluster + openshift
```

**Benefits:**
- No need to pass `-D mode=...` or `-D platform=...` flags
- Cluster facts (mode, platform) defined once in `clusters/{name}/facts.k`
- Scales to 60+ clusters without parameter explosion
- Mode-specific component configuration from `modes/` directory

### Legacy Parameter-Based Configuration

For backward compatibility, parameter-based builds are still supported:

```bash
# Generate catalog for OpenShift service cluster (legacy)
kcl run kcl/services/postgres/cluster_catalog.k \
  -D mode=service_cluster \
  -D platform=openshift \
  -o output/catalog-openshift.yaml

# Generate catalog for Kubernetes converged mode (legacy)
kcl run kcl/services/postgres/cluster_catalog.k \
  -D mode=converged \
  -D platform=kubernetes \
  -o output/catalog-k8s.yaml

# Or use make target
make build-catalogs
```

### Supported Modes

- **converged**: Single cluster (control plane + service cluster)
- **control_plane**: Control plane only (manages remote service clusters)
- **service_cluster**: Service cluster only (runs workloads)

### Supported Platforms

- **kubernetes**: Standard Kubernetes (vanilla, EKS, GKE, AKS)
  - Uses Helm for operator installation
  - Standard RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding)
  - NetworkPolicy for network isolation

- **openshift**: Red Hat OpenShift / OKE
  - Uses OLM (OperatorGroup, Subscription) for operator installation
  - OpenShift-specific RBAC with annotations
  - SecurityContextConstraints (SCC) for pod security
  - NetworkPolicy with OpenShift annotations
  - Routes for ingress (instead of Ingress)

## Split-Mode Architecture

### How Split-Mode Works

1. **Control Plane Cluster** (`kind-mgmt`):
   - Runs Crossplane
   - Manages XRDs, Compositions, Claims
   - Stores connection secrets
   - Does NOT run workloads

2. **Service Cluster** (`kind-svc`):
   - Runs actual workloads (StackGres PostgreSQL clusters)
   - Runs operators (StackGres operator)
   - Does NOT have Crossplane

3. **Cross-Cluster Communication**:
   - Control plane has service cluster kubeconfig in Secret
   - ProviderConfig `kubernetes-service-cluster` uses this Secret
   - Crossplane creates resources in service cluster via provider-kubernetes

### ProviderConfig for Split-Mode

The `platform/crossplane.k` file includes two ProviderConfigs:

```yaml
# For control plane cluster (in-cluster resources)
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: kubernetes-incluster
spec:
  credentials:
    source: InjectedIdentity

# For service cluster (remote resources)
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: kubernetes-service-cluster
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: service-cluster-kubeconfig
      key: kubeconfig
```

The `setup-kind.sh` script automatically creates the `service-cluster-kubeconfig` Secret.

## Platform Detection

### Kubernetes Platform

**Operator Installation** (Helm-based):
```yaml
apiVersion: helm.crossplane.io/v1beta1
kind: Release
metadata:
  name: stackgres-operator
spec:
  forProvider:
    chart: stackgres-operator
    repository: https://stackgres.io/downloads/stackgres-k8s/stackgres/helm/
```

### OpenShift Platform

**Operator Installation** (OLM-based):
```yaml
# OperatorGroup
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: stackgres
  namespace: stackgres
spec:
  targetNamespaces: [stackgres]

# Subscription
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: stackgres
spec:
  channel: stable
  name: stackgres
  source: redhat-marketplace
  sourceNamespace: openshift-marketplace
```

**SecurityContextConstraints**:
```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: stackgres-anyuid
allowPrivilegedContainer: false
runAsUser:
  type: MustRunAsRange
users:
  - system:serviceaccount:stackgres:stackgres-operator
```

## Mode Hierarchy

### How Mode Configuration Works

The PoC implements a 4-level hierarchy that eliminates vars.jsonnet complexity:

```
Level 0: defs/          - Type definitions (Platform, ClusterMode, ComponentConfig)
Level 1: modes/         - Mode configurations (converged, control_plane, service_cluster)
Level 2: platforms/     - Platform helpers (kubernetes, openshift)
Level 3: defaults/      - Default values (images, resources, plans)
Level 4: clusters/      - Cluster-specific overrides
```

### Example: dev-1 Cluster

**1. Cluster facts** (`clusters/dev-1/facts.k`):
```python
facts = {
    name: "dev-1"
    cloud: "cloudscale"
    region: "lpg"
    distribution: "kubernetes"
}

platform = defs.Platform {
    type: "kubernetes"
    distribution: "vanilla"
}

clusterMode = defs.ClusterMode {
    mode: "converged"  # Single cluster with both control plane and workloads
}
```

**2. Mode configuration** (`modes/converged.k`):
```python
config = defs.ClusterConfig {
    mode: defs.ClusterMode { mode: "converged" }

    components: defs.ComponentsConfig {
        # Both control plane AND service cluster components
        controller: defs.ComponentConfig { enabled: True, replicas: 1 }
        apiServer: defs.ComponentConfig { enabled: True, replicas: 1 }
        operators: {
            stackgres: defs.ComponentConfig { enabled: True }
            cnpg: defs.ComponentConfig { enabled: True }
        }
    }
}
```

**3. Merged configuration** (`clusters/dev-1/main.k`):
```python
import modes.converged as modeConfig
import clusters.dev_1.facts as facts

# Merge mode config with cluster facts
config = modeConfig.config | {
    platform: facts.platform
    mode: facts.clusterMode
}
```

**4. Catalog generation** (`services/postgres/cluster_catalog.k`):
```python
# Load cluster configuration
clusterName: str = option("cluster") or ""

if clusterName != "":
    import clusters[clusterName].main as clusterMain
    clusterConfig = clusterMain.clusterConfig

    # Extract mode and platform from cluster config
    mode = clusterConfig.mode.mode
    platform = clusterConfig.platform.type
    isServiceCluster = clusterConfig.components.operators?.stackgres?.enabled or False
    isControlPlane = clusterConfig.components.controller?.enabled or False

# Generate resources based on mode and platform
operatorInstall = if isServiceCluster then { ... } else {}
maintenanceRBAC = if isControlPlane then { ... } else {}
```

### Mode Comparison

| Component | Converged | Control Plane | Service Cluster |
|-----------|-----------|---------------|-----------------|
| **controller** | ✅ replicas: 1 | ✅ replicas: 3 (HA) | ❌ disabled |
| **apiServer** | ✅ replicas: 1 | ✅ replicas: 2 (HA) | ❌ disabled |
| **sliExporter** | ✅ replicas: 1 | ✅ replicas: 1 | ❌ disabled |
| **operators** | ✅ enabled | ❌ disabled | ✅ enabled |
| **splitMode** | ❌ False | ✅ True | N/A |

### Adding a New Cluster

1. Create cluster directory:
```bash
mkdir -p kcl/clusters/prod-new-1
```

2. Define cluster facts (`clusters/prod-new-1/facts.k`):
```python
import defs

facts = {
    name: "prod-new-1"
    cloud: "exoscale"
    region: "rma"
    distribution: "kubernetes"
}

platform = defs.Platform {
    type: "kubernetes"
    distribution: "vanilla"
}

clusterMode = defs.ClusterMode {
    mode: "service_cluster"
    controlPlaneKubeconfig: "/etc/kubeconfig/control-plane"
}
```

3. Create main config (`clusters/prod-new-1/main.k`):
```python
import modes.service_cluster as modeConfig
import clusters.prod_new_1.facts as facts

config = modeConfig.config | {
    platform: facts.platform
    mode: facts.clusterMode
}

clusterConfig = config
```

4. Add to Makefile:
```makefile
CLUSTERS := dev-1 prod-control-plane-1 prod-service-1 prod-new-1
```

5. Build:
```bash
make build-cluster CLUSTER=prod-new-1
```

## Crossplane 2.0 API

### Pipeline Mode Composition

The `xpkg.k` file uses Crossplane 2.0 Pipeline mode with inline input:

```python
mode = "Pipeline"
pipeline = [
    {
        step = "postgres-composition"
        functionRef = {
            name = svc.service.functionRef
        }
        input = {
            apiVersion = "appcat.vshn.io/v1"
            kind = "PostgreSQLConfig"
            spec = {
                service = svc.service.serviceName
                plans = svc.service.plans
                defaultPlan = svc.service.defaultPlan
                connectionSecretKeys = svc.service.connectionSecretKeys
                stackgres = svc.service.stackgres
            }
        }
    }
]
```

### Package Metadata

The `crossplane.yaml` metadata includes proper dependencies:

```yaml
apiVersion: meta.pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: appcat-postgresql
spec:
  crossplane:
    version: ">=v1.15.0"
  dependsOn:
    - provider: xpkg.upbound.io/crossplane-contrib/provider-kubernetes
      version: ">=v0.12.1"
    - provider: xpkg.upbound.io/crossplane-contrib/provider-helm
      version: ">=v0.17.0"
    - provider: xpkg.upbound.io/crossplane-contrib/provider-sql
      version: ">=v0.10.0"
    - function: ghcr.io/vshn/appcat
      version: ">=v4.174.0"
```

## Migration from Jsonnet

### Comparison: vars.jsonnet vs KCL

| Aspect | vars.jsonnet | KCL |
|--------|--------------|-----|
| **Mode detection** | Complex conditionals scattered across files | Declarative schema at top of hierarchy |
| **Platform detection** | Manual `isOpenshift` checks everywhere | Platform-specific modules (kubernetes.k, openshift.k) |
| **Type safety** | None (runtime errors) | Full type checking at compile time |
| **Validation** | Manual assertions | Schema constraints with `check` blocks |
| **Code organization** | Flat with implicit dependencies | Hierarchical with explicit imports |
| **Testability** | Difficult (requires full Kapitan run) | Easy (unit test schemas directly) |
| **Documentation** | Comments only | Inline docstrings in schemas |

## Known Limitations

1. **Function API**: Currently using v4.174.0 function API. Need to verify compatibility with Crossplane 2.0 ApplyState/ObserveState API when function is updated.

2. **xpkg Packaging**: The `package-xpkg.sh` script creates OCI packages but does not automatically push to registry. Set `XPKG_REGISTRY` environment variable to enable auto-push.

3. **Platform Detection**: Platform is specified via `-D platform=kubernetes|openshift` flag. Auto-detection from cluster API could be added.

4. **Templates**: The `templates.k` ConfigMap is not yet integrated into the Composition. Inline input is used instead.

## References

- [KCL Documentation](https://kcl-lang.io/)
- [Crossplane 2.0 Documentation](https://docs.crossplane.io/)
- [VSHN AppCat](https://github.com/vshn/appcat)
- [StackGres](https://stackgres.io/)
- [Kind](https://kind.sigs.k8s.io/)

## License

BSD-3-Clause (same as VSHN AppCat)
