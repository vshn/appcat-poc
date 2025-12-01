"""
Kubernetes platform-specific configuration
For standard Kubernetes clusters (vanilla, EKS, GKE, AKS, etc.)
"""

import defs

# Platform configuration
platform = defs.Platform {
    type = "kubernetes"
    distribution = "vanilla"
}

# Helper to generate Helm-based operator installation
helmOperatorInstall = lambda name: str, namespace: str, chart: str, repo: str, version: str -> any {
    {
        apiVersion = "helm.crossplane.io/v1beta1"
        kind = "Release"
        metadata = {
            name = name
            namespace = namespace
        }
        spec = {
            forProvider = {
                chart = chart
                namespace = namespace
                repository = repo
                version = version
            }
            providerConfigRef = {
                name = "helm-incluster"
            }
        }
    }
}

# StackGres operator installation for Kubernetes
stackgresOperator = lambda namespace: str, version: str -> any {
    helmOperatorInstall(
        "stackgres-operator",
        namespace,
        "stackgres-operator",
        "https://stackgres.io/downloads/stackgres-k8s/stackgres/helm/",
        version
    )
}

# RBAC resources for Kubernetes
serviceAccount = lambda name: str, namespace: str -> any {
    {
        apiVersion = "v1"
        kind = "ServiceAccount"
        metadata = {
            name = name
            namespace = namespace
        }
    }
}

clusterRole = lambda name: str, rules: [any] -> any {
    {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind = "ClusterRole"
        metadata = {
            name = name
        }
        rules = rules
    }
}

clusterRoleBinding = lambda name: str, serviceAccountName: str, serviceAccountNamespace: str, roleName: str -> any {
    {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind = "ClusterRoleBinding"
        metadata = {
            name = name
        }
        roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind = "ClusterRole"
            name = roleName
        }
        subjects = [{
            kind = "ServiceAccount"
            name = serviceAccountName
            namespace = serviceAccountNamespace
        }]
    }
}

# NetworkPolicy for Kubernetes
networkPolicy = lambda name: str, namespace: str, podSelector: {str: str}, policyTypes: [str] -> any {
    {
        apiVersion = "networking.k8s.io/v1"
        kind = "NetworkPolicy"
        metadata = {
            name = name
            namespace = namespace
        }
        spec = {
            podSelector = {
                matchLabels = podSelector
            }
            policyTypes = policyTypes
            ingress = [{}]
            egress = [{}]
        }
    }
}
