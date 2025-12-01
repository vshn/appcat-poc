"""
Cluster catalog for PostgreSQL service
Generates platform-specific and mode-specific resources based on cluster configuration

NOTE: This file will generate an empty catalog ({}) if the service is disabled in the cluster.
The Makefile will skip the output file generation for disabled services.
"""

import services.postgres.service as svc
import platforms.kubernetes as k8s
import platforms.openshift as ocp

# Check if this service is enabled in the cluster
# When cluster files are loaded, enabledServices dict is available from facts.k
# When running standalone (legacy mode), assume service is enabled
_serviceEnabled = enabledServices?.postgres if enabledServices else True

# Configuration: Use cluster-provided values when available, otherwise use legacy parameters
# When loaded with cluster files (clusters/*/facts.k, clusters/*/main.k), the following are available:
# - clusterConfig, platform (Platform object), isOpenshift, isServiceCluster, isControlPlane, clusterMode, enabledServices
# When running standalone with -D parameters, use option() to get parameters

_clusterMode = clusterMode.mode if clusterMode else (option("mode") or "converged")
_platformType = platform.type if platform else (option("platform") or "kubernetes")

# Use provided flags if available (from cluster facts), otherwise derive from mode
# Note: When cluster files are loaded, these variables are already defined and immutable
# So we just reference them directly instead of redefining
mode = _clusterMode
platformType = _platformType

stackgresNs = svc.service.stackgres.namespace

# OpenShift-specific labels and annotations
_openshiftLabels = {
    "openshift.io/cluster-monitoring" = "true"
    "openshift.io/user-monitoring" = "false"
}

_openshiftAnnotations = {
    "openshift.io/node-selector" = ""
}

# Base namespace (always created)
namespace = {
    "00-namespace.yaml": {
        apiVersion = "v1"
        kind = "Namespace"
        metadata = {
            name = stackgresNs
            labels = {
                "appcat.vshn.io/servicename" = svc.service.serviceName
                "appcat.vshn.io/mode" = mode
            } | (_openshiftLabels if isOpenshift else {})
            annotations = _openshiftAnnotations if isOpenshift else {}
        }
    }
}

# NetworkPolicy (both platforms)
networkPolicy = {
    "10-networkpolicy.yaml": ocp.networkPolicy(
        "allow-stackgres-api",
        stackgresNs,
        {"app": "StackGresConfig"},
        ["Ingress"]
    ) if isOpenshift else k8s.networkPolicy(
        "allow-stackgres-api",
        stackgresNs,
        {"app": "StackGresConfig"},
        ["Ingress"]
    )
}

# Operator installation for OpenShift (service clusters only)
_openshiftOperatorInstall = {
    "20-operatorgroup.yaml": ocp.operatorGroup(
        "stackgres",
        stackgresNs,
        [stackgresNs]
    )
    "30-subscription.yaml": ocp.olmOperatorInstall(
        "stackgres",
        stackgresNs,
        "stackgres",
        svc.service.stackgres.channel,
        "redhat-marketplace",
        "openshift-marketplace"
    )
}

# Operator installation for Kubernetes (service clusters only)
_k8sOperatorInstall = {
    "30-stackgres-operator.yaml": k8s.helmOperatorInstall(
        "stackgres-operator",
        stackgresNs,
        "stackgres-operator",
        "https://stackgres.io/downloads/stackgres-k8s/stackgres/helm/",
        "1.10.0"
    )
}

# Select operator install based on platform (only for service clusters)
operatorInstall = _openshiftOperatorInstall if (isServiceCluster and isOpenshift) else (_k8sOperatorInstall if (isServiceCluster and not isOpenshift) else {})

# RBAC for OpenShift (control plane only)
_openshiftMaintenanceRBAC = {
    "40-maintenance-sa.yaml": ocp.serviceAccount("appcat-maintenance", svc.service.secretNamespace)
    "41-maintenance-role.yaml": ocp.clusterRole(
        "crossplane:appcat:job:postgres:maintenance",
        [
            {
                apiGroups = ["apiextensions.crossplane.io"]
                resources = ["compositionrevisions"]
                verbs = ["get", "list"]
            }
            {
                apiGroups = ["vshn.appcat.vshn.io"]
                resources = ["xvshnpostgresqls", "vshnpostgresqls"]
                verbs = ["get", "update"]
            }
        ]
    )
    "42-maintenance-binding.yaml": ocp.clusterRoleBinding(
        "appcat:postgres:maintenance",
        "appcat-maintenance",
        svc.service.secretNamespace,
        "crossplane:appcat:job:postgres:maintenance"
    )
}

# RBAC for Kubernetes (control plane only)
_k8sMaintenanceRBAC = {
    "40-maintenance-sa.yaml": k8s.serviceAccount("appcat-maintenance", svc.service.secretNamespace)
    "41-maintenance-role.yaml": k8s.clusterRole(
        "crossplane:appcat:job:postgres:maintenance",
        [
            {
                apiGroups = ["apiextensions.crossplane.io"]
                resources = ["compositionrevisions"]
                verbs = ["get", "list"]
            }
            {
                apiGroups = ["vshn.appcat.vshn.io"]
                resources = ["xvshnpostgresqls", "vshnpostgresqls"]
                verbs = ["get", "update"]
            }
        ]
    )
    "42-maintenance-binding.yaml": k8s.clusterRoleBinding(
        "appcat:postgres:maintenance",
        "appcat-maintenance",
        svc.service.secretNamespace,
        "crossplane:appcat:job:postgres:maintenance"
    )
}

# Select RBAC based on platform (only for control plane)
maintenanceRBAC = _openshiftMaintenanceRBAC if (isControlPlane and isOpenshift) else (_k8sMaintenanceRBAC if (isControlPlane and not isOpenshift) else {})

# OpenShift-specific: SecurityContextConstraints (service clusters only)
openshiftSCC = {
    "50-stackgres-scc.yaml": ocp.securityContextConstraints(
        "stackgres-anyuid",
        False,  # allowPrivilegedContainer
        ["system:serviceaccount:${stackgresNs}:stackgres-operator"]
    )
} if (isOpenshift and isServiceCluster) else {}

# Combine all resources (or return empty if service is disabled)
cluster_catalog = (namespace | networkPolicy | operatorInstall | maintenanceRBAC | openshiftSCC) if _serviceEnabled else {}
