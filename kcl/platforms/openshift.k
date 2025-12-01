"""
OpenShift platform-specific configuration
For Red Hat OpenShift and OKE (VSHN's OpenShift Kubernetes Engine)
"""

import defs

# Platform configuration
platform = defs.Platform {
    type = "openshift"
    distribution = "openshift4"
}

# Helper to generate OLM-based operator installation
olmOperatorInstall = lambda name: str, namespace: str, packageName: str, channel: str, source: str, sourceNamespace: str -> any {
    {
        apiVersion = "operators.coreos.com/v1alpha1"
        kind = "Subscription"
        metadata = {
            name = name
            namespace = namespace
        }
        spec = {
            channel = channel
            installPlanApproval = "Automatic"
            name = packageName
            source = source
            sourceNamespace = sourceNamespace
        }
    }
}

# OperatorGroup for OpenShift OLM
operatorGroup = lambda name: str, namespace: str, targetNamespaces: [str] -> any {
    {
        apiVersion = "operators.coreos.com/v1"
        kind = "OperatorGroup"
        metadata = {
            name = name
            namespace = namespace
        }
        spec = {
            targetNamespaces = targetNamespaces
        }
    }
}

# StackGres operator installation for OpenShift (via OLM)
stackgresOperator = lambda namespace: str, channel: str -> any {
    [
        operatorGroup(
            "stackgres-operator-group",
            namespace,
            [namespace]
        ),
        olmOperatorInstall(
            "stackgres-operator",
            namespace,
            "stackgres-operator",
            channel,
            "community-operators",
            "openshift-marketplace"
        ),
    ]
}

# RBAC resources for OpenShift
serviceAccount = lambda name: str, namespace: str -> any {
    {
        apiVersion = "v1"
        kind = "ServiceAccount"
        metadata = {
            name = name
            namespace = namespace
            annotations = {
                "openshift.io/description" = "Service account for ${name}"
            }
        }
    }
}

clusterRole = lambda name: str, rules: [any] -> any {
    {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind = "ClusterRole"
        metadata = {
            name = name
            annotations = {
                "openshift.io/description" = "Cluster role for ${name}"
            }
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
            annotations = {
                "openshift.io/description" = "Cluster role binding for ${name}"
            }
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

# SecurityContextConstraints for OpenShift
securityContextConstraints = lambda name: str, allowPrivilegedContainer: bool, serviceAccounts: [str] -> any {
    {
        apiVersion = "security.openshift.io/v1"
        kind = "SecurityContextConstraints"
        metadata = {
            name = name
            annotations = {
                "kubernetes.io/description" = "SCC for ${name}"
            }
        }
        allowPrivilegedContainer = allowPrivilegedContainer
        allowHostDirVolumePlugin = False
        allowHostIPC = False
        allowHostNetwork = False
        allowHostPID = False
        allowHostPorts = False
        readOnlyRootFilesystem = False
        runAsUser = {
            type = "MustRunAsRange"
        }
        seLinuxContext = {
            type = "MustRunAs"
        }
        fsGroup = {
            type = "MustRunAs"
        }
        supplementalGroups = {
            type = "RunAsAny"
        }
        users = serviceAccounts
        volumes = [
            "configMap",
            "downwardAPI",
            "emptyDir",
            "persistentVolumeClaim",
            "projected",
            "secret",
        ]
    }
}

# NetworkPolicy for OpenShift (same as Kubernetes but with annotations)
networkPolicy = lambda name: str, namespace: str, podSelector: {str: str}, policyTypes: [str] -> any {
    {
        apiVersion = "networking.k8s.io/v1"
        kind = "NetworkPolicy"
        metadata = {
            name = name
            namespace = namespace
            annotations = {
                "openshift.io/description" = "Network policy for ${name}"
            }
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

# OpenShift Route (similar to Ingress but OpenShift-specific)
route = lambda name: str, namespace: str, serviceName: str, port: str, tls: bool -> any {
    _tlsConfig = {
        termination = "edge"
        insecureEdgeTerminationPolicy = "Redirect"
    } if tls else {}

    _baseSpec = {
        to = {
            kind = "Service"
            name = serviceName
        }
        port = {
            targetPort = port
        }
    }

    _spec = _baseSpec | (_tlsConfig if tls else {})

    {
        apiVersion = "route.openshift.io/v1"
        kind = "Route"
        metadata = {
            name = name
            namespace = namespace
        }
        spec = _spec | ({"tls": _tlsConfig} if tls else {})
    }
}
