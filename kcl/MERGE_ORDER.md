# KCL Configuration Merge Order

This document explains how configuration values flow through the hierarchy and which values take precedence.

## Quick Reference

```
Priority (low → high):
1. modes/           Base configuration (which components enabled)
2. platforms/       Platform-specific helpers (used by services)
3. defaults/        Default values (images, resources, plans)
4. clusters/        Cluster-specific overrides (FINAL)
```

**Rule:** Later in the chain = higher priority

## KCL Operators and Semantics

KCL provides three operators with distinct merge behaviors:

### 1. `**` (Unpack Operator)
**Purpose:** Start with a base configuration

**Usage:**
```python
config = {
    **baseConfig    # Unpack: use this as starting point
    key = "value"   # Then add/override fields
}
```

**Result:** All fields from `baseConfig` are included, then new fields added/overridden.

### 2. `=` (Override Operator)
**Purpose:** Explicit replacement of a value

**Usage:**
```python
config = {
    replicas = 5    # Override: replace whatever was there
}
```

**Semantics:**
- **Not idempotent:** Order matters
- **Explicit:** Shows intent to replace
- **Best for:** Environment-specific overrides

**From KCL docs:**
> "Use `=` for override in the environment-specific configurations."

### 3. `:` (Merge Operator)
**Purpose:** Idempotent merge (additive)

**Usage:**
```python
config = {
    labels: {key: "value"}    # Merge: add to existing labels
}
```

**Semantics:**
- **Idempotent:** Order doesn't matter (exchange law)
- **Additive:** Combines values instead of replacing
- **Conflicts throw errors:** If values differ
- **Best for:** Common configurations

**From KCL docs:**
> "Use `:` in the common configurations."

**Exchange Law Example:**
```python
# Both produce identical results:
config1 = {labels: {key2: "value2"}, labels: {key1: "value1"}}
config2 = {labels: {key1: "value1"}, labels: {key2: "value2"}}
# Result: {"labels": {"key1": "value1", "key2": "value2"}}
```

## Merge Flow

### Level 1: Mode Configuration (Base)

**Location:** `modes/{converged,control_plane,service_cluster}.k`

**Purpose:** Define which components are enabled and their base settings

**Operator:** Uses `:` (merge) for component definitions

**Example:**
```python
# modes/control_plane.k
config = defs.ClusterConfig {
    mode: defs.ClusterMode { mode: "control_plane" }

    components: defs.ComponentsConfig {
        controller: defs.ComponentConfig {
            enabled: True
            replicas: 3              # Mode default
            splitMode: True
        }
        operators: {
            stackgres: defs.ComponentConfig {
                enabled: False       # No operators in control plane
            }
        }
    }
}
```

**What it defines:**
- Which components are enabled (`controller`, `apiServer`, `operators`)
- Default replica counts
- Split-mode behavior

### Level 2: Platform Helpers

**Location:** `platforms/{kubernetes,openshift}.k`

**Purpose:** Provide platform-specific resource generators

**Used by:** `services/*/cluster_catalog.k` (not directly merged)

**Example:**
```python
# platforms/kubernetes.k
helmOperatorInstall = lambda name, namespace, chart, repo, version -> any {
    {
        apiVersion = "helm.crossplane.io/v1beta1"
        kind = "Release"
        # ...
    }
}
```

**What it provides:**
- Platform-specific resource generators
- Helper functions for RBAC, operators, network policies

### Level 3: Defaults

**Location:** `defaults/{images,resources,plans}.k`

**Purpose:** Reusable default values

**Operator:** Uses `:` (merge) when referenced

**Example:**
```python
# defaults/plans.k
postgres = {
    "standard-2": defs.PlanSpec {
        cpu: "400m"
        memory: "1936Mi"
        storage: "20Gi"
        replicas: 2
    }
}
```

**What it defines:**
- Container images and versions
- Resource requests/limits
- Service plans

**Usage in services:**
```python
# services/postgres/service.k
import defaults.plans as defaultPlans

plans = defaultPlans.postgres  # Reference defaults
```

### Level 4: Cluster Configuration (FINAL)

**Location:** `clusters/{name}/main.k`

**Purpose:** Cluster-specific overrides (highest priority)

**Operator:** Uses `**` (unpack) + `=` (override)

**Example:**
```python
# clusters/prod-control-plane-1/main.k
import modes.control_plane as modeConfig
import clusters.prod_control_plane_1.facts as facts

# Step 1: Base + facts
config = {
    **modeConfig.config              # Unpack mode config
    platform = facts.platform        # Override platform
    mode = facts.clusterMode         # Override mode
}

# Step 2: Production overrides
config = {
    **config                         # Unpack previous config
    components = {
        **config.components
        controller = {
            **config.components.controller
            replicas = 5             # Override: 5 instead of mode default (3)
        }
    }
}
```

**What it overrides:**
- Platform (kubernetes vs openshift)
- Mode settings (e.g., controlPlaneKubeconfig)
- Component replicas (production HA)
- Any mode defaults

## Visual Merge Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. modes/control_plane.k                                    │
│    config = {                                               │
│        components: {                                        │
│            controller: { enabled: True, replicas: 3 }       │
│            operators: { stackgres: { enabled: False } }     │
│        }                                                    │
│    }                                                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. platforms/openshift.k (used by services, not merged)    │
│    olmOperatorInstall(...)                                  │
│    securityContextConstraints(...)                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. defaults/images.k (referenced by services)               │
│    appcat.controller = "ghcr.io/vshn/appcat:v4.174.0"      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. clusters/prod-control-plane-1/main.k (FINAL)            │
│    config = {                                               │
│        **modeConfig.config          # Start with mode      │
│        platform = facts.platform    # Override platform    │
│    }                                                        │
│    config = {                                               │
│        **config                     # Previous config      │
│        components = {                                       │
│            controller = {                                   │
│                replicas = 5         # OVERRIDE: 5 not 3    │
│            }                                                │
│        }                                                    │
│    }                                                        │
└─────────────────────────────────────────────────────────────┘
```

## Precedence Rules

### 1. Within Same File (Sequential Override)

```python
config = {
    replicas = 1    # First
}
config = {
    **config
    replicas = 5    # WINS (last override)
}
# Result: replicas = 5
```

**Rule:** Later assignments override earlier ones when using `=`

### 2. Across Import Chain (Unpack + Override)

```python
# base.k
baseConfig = { replicas: 1 }

# override.k
import .base as base
config = {
    **base.baseConfig    # Unpack base
    replicas = 5         # Override
}
# Result: replicas = 5
```

**Rule:** Unpacking provides base, then overrides apply

### 3. Merge Operator (Idempotent)

```python
config = {
    labels: {app: "myapp"}       # Merge
    labels: {env: "prod"}        # Merge
}
# Result: labels = {app: "myapp", env: "prod"}
```

**Rule:** With `:`, order doesn't matter (exchange law)

### 4. Conflict Detection

```python
config = {
    replicas: 1     # Merge operator
    replicas: 2     # Merge operator
}
# ERROR: Conflict! Cannot merge different values
```

**Rule:** Merge operator (`:`) throws errors on conflicts

**Solution:** Use override operator (`=`):
```python
config = {
    replicas = 1    # Override operator
    replicas = 2    # Override operator
}
# OK: replicas = 2 (last wins)
```

## Examples

### Example 1: Dev Cluster (Simple Override)

**File:** `clusters/dev-1/main.k`

```python
import modes.converged as modeConfig
import clusters.dev_1.facts as facts

config = {
    **modeConfig.config              # Base: converged mode
    platform = facts.platform        # Override: kubernetes
    mode = facts.clusterMode         # Override: converged
}
```

**Result:**
- Starts with: `modes/converged.k` (both control plane and operators enabled)
- Overrides: platform = kubernetes, mode = converged
- **No replica overrides** (uses mode defaults)

### Example 2: Production Control Plane (Multi-Step Override)

**File:** `clusters/prod-control-plane-1/main.k`

```python
import modes.control_plane as modeConfig
import clusters.prod_control_plane_1.facts as facts

# Step 1: Base + facts
config = {
    **modeConfig.config
    platform = facts.platform        # Override: openshift
    mode = facts.clusterMode         # Override: control_plane
}

# Step 2: Production overrides
config = {
    **config
    components = {
        **config.components
        controller = {
            **config.components.controller
            replicas = 5                 # Override: 5 (mode default was 3)
        }
        apiServer = {
            **config.components.apiServer
            replicas = 3                 # Override: 3 (mode default was 2)
        }
    }
}
```

**Result:**
- Starts with: `modes/control_plane.k` (controller enabled, operators disabled)
- Overrides: platform = openshift, mode = control_plane
- **Replica overrides:** controller: 5 (was 3), apiServer: 3 (was 2)

### Example 3: Service Cluster (Mode + Facts)

**File:** `clusters/prod-service-1/main.k`

```python
import modes.service_cluster as modeConfig
import clusters.prod_service_1.facts as facts

config = {
    **modeConfig.config              # Base: service_cluster mode
    platform = facts.platform        # Override: openshift
    mode = facts.clusterMode         # Override: includes controlPlaneKubeconfig
}
```

**Result:**
- Starts with: `modes/service_cluster.k` (operators enabled, controller disabled)
- Overrides: platform = openshift, mode with controlPlaneKubeconfig
- **No replica overrides** (uses mode defaults)

## Debugging Merge Issues

### Check Current Value

```bash
# See final config for a cluster
kcl run kcl/clusters/dev-1/main.k

# See specific field
kcl run kcl/clusters/dev-1/main.k -o json | jq '.clusterConfig.components.controller.replicas'
```

### Trace Merge Chain

1. **Check mode config:**
   ```bash
   kcl run kcl/modes/converged.k
   ```

2. **Check cluster facts:**
   ```bash
   kcl run kcl/clusters/dev-1/facts.k
   ```

3. **Check merged config:**
   ```bash
   kcl run kcl/clusters/dev-1/main.k
   ```

### Common Issues

**Issue:** "Conflict error when merging"
```
Error: Conflicting values: expected 1, got 2
```

**Solution:** Use `=` instead of `:` for overrides:
```python
# Wrong (conflict)
config = {
    replicas: 1
    replicas: 2
}

# Correct (override)
config = {
    replicas = 2
}
```

**Issue:** "Value not overriding as expected"

**Solution:** Check operator precedence:
```python
# This doesn't override (merge operator)
config = {
    **base
    replicas: 5    # Merges, may conflict
}

# This overrides (override operator)
config = {
    **base
    replicas = 5   # Overrides
}
```

## Best Practices

### 1. Use Correct Operators

**From KCL docs:**
> "Use `:` in the common configurations, and `=` for override in the environment-specific configurations."

- **modes/** → Use `:` (merge operator)
- **clusters/** → Use `=` (override operator)

### 2. Make Merge Order Explicit

**Good:** Shows precedence with unpacking
```python
config = {
    **modeConfig.config     # Base (explicit)
    replicas = 5            # Override (explicit)
}
```

**Bad:** Implicit merge with `|` operator
```python
config = modeConfig.config | {replicas: 5}  # Unclear precedence
```

### 3. Document Override Intent

```python
# Step 1: Base configuration from mode
config = {
    **modeConfig.config
}

# Step 2: Production overrides for HA
config = {
    **config
    components = {
        **config.components
        controller = {
            **config.components.controller
            replicas = 5    # Override: production HA (mode default: 3)
        }
    }
}
```

### 4. Avoid Deep Nesting

**Instead of:**
```python
config = modeConfig.config | {
    components: {
        controller: {
            replicas: 5
        }
    }
}
```

**Use explicit unpacking:**
```python
config = {
    **modeConfig.config
    components = {
        **modeConfig.config.components
        controller = {
            **modeConfig.config.components.controller
            replicas = 5
        }
    }
}
```

## References

- [KCL Official Docs - Operators](https://www.kcl-lang.io/docs/reference/lang/tour)
- [KCL Best Practices](https://www.kcl-lang.io/docs/user_docs/guides/working-with-konfig/practice)
- [KCL Configuration Guide](https://www.kcl-lang.io/docs/user_docs/guides/configuration)
- [KCL FAQ - Merge Dictionaries](https://www.kcl-lang.io/docs/user_docs/support/faq-kcl)
