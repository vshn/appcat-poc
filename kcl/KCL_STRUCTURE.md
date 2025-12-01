# KCL Repo Structure Proposal

```
config/
├── defs/                       # Global schemas and shared types
│   ├── package.kcl
│   ├── base.kcl                # Common structs (Resources, Plans, Tenants)
│   └── appcat.kcl              # Service-specific schemas
├── platform/                   # Cluster-wide/static assets
│   ├── crossplane/             # Helm/values for Crossplane core, namespaces
│   │   ├── package.kcl
│   │   └── crossplane.kcl
│   ├── providers/              # Provider manifests (reference xpks)
│   │   ├── kubernetes.kcl
│   │   └── helm.kcl
│   └── workloads/              # Controllers, API server, SLI exporter
│       ├── controller.kcl
│       ├── apiserver.kcl
│       └── sliexporter.kcl
├── services/                   # Per-service templates and schemas
│   ├── forgejo/
│   │   ├── package.kcl
│   │   ├── schema.kcl          # ServiceSpec (name, plans, flags)
│   │   ├── templates.kcl       # Namespace/ConfigMap/Service definitions
│   │   └── operators.kcl       # Operator subscriptions if needed
│   ├── postgres/
│   │   └── ...
│   └── redis/
├── tenants/                    # Tenant-level overrides
│   ├── vshn/
│   │   ├── package.kcl
│   │   └── tenant.kcl          # Default plans, SLA policies
│   └── acme/
├── clusters/                   # Cluster-specific facts/overrides (nested under tenants)
│   ├── vshn/
│   │   ├── dev-1/
│   │   │   ├── package.kcl
│   │   │   ├── cluster.kcl
│   │   │   └── facts.kcl
│   │   └── prod-1/
│   └── acme/
└── outputs/
    ├── templates/              # Rendered JSON for service templates/configmaps
    ├── xpks/                   # Generated XRD/Composition manifests per service
    └── platform/               # Rendered manifests for ArgoCD (Crossplane install, operators)
```

- `defs/` holds the canonical schemas so services/tenants/clusters all reuse the same types.
- `platform/` emits the Git/ArgoCD workloads (Crossplane helm values, controller deployments, template ConfigMaps).
- `services/<name>/` feeds both the xpks (XRD/Composition YAML) and the JSON templates consumed by composition functions.
- `tenants/<tenant>/` encodes tenant-specific defaults (plan availability, maintenance policies), while `clusters/<tenant>/<cluster>/` captures per-cluster facts (cloud, region) and overrides.
- `outputs/` is a build artifact directory (not committed) where CI renders KCL into JSON/YAML for distribution.
