"""
Default service plans for AppCat services
"""

import defs

# PostgreSQL service plans
postgres = {
    "standard-2": defs.PlanSpec {
        name: "standard-2"
        cpu: "400m"
        memory: "1936Mi"
        storage: "20Gi"
        replicas: 2
        description: "Standard plan with 2 replicas for high availability"
    }
    "standard-4": defs.PlanSpec {
        name: "standard-4"
        cpu: "800m"
        memory: "3872Mi"
        storage: "40Gi"
        replicas: 2
        description: "Large plan with 2 replicas and increased resources"
    }
    "standard-8": defs.PlanSpec {
        name: "standard-8"
        cpu: "1600m"
        memory: "7744Mi"
        storage: "80Gi"
        replicas: 3
        description: "XL plan with 3 replicas for production workloads"
    }
}

# Redis service plans
redis = {
    "standard-2": defs.PlanSpec {
        name: "standard-2"
        cpu: "250m"
        memory: "1Gi"
        storage: "10Gi"
        replicas: 2
        description: "Standard Redis with 2 replicas"
    }
    "standard-4": defs.PlanSpec {
        name: "standard-4"
        cpu: "500m"
        memory: "2Gi"
        storage: "20Gi"
        replicas: 2
        description: "Large Redis with increased memory"
    }
}

# MariaDB service plans
mariadb = {
    "standard-2": defs.PlanSpec {
        name: "standard-2"
        cpu: "400m"
        memory: "1936Mi"
        storage: "20Gi"
        replicas: 2
        description: "Standard MariaDB with 2 replicas"
    }
    "standard-4": defs.PlanSpec {
        name: "standard-4"
        cpu: "800m"
        memory: "3872Mi"
        storage: "40Gi"
        replicas: 2
        description: "Large MariaDB with increased resources"
    }
}

# Default plan names (for validation)
defaultPlan = "standard-2"
