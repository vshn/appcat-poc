# Platform types
schema Platform:
    """
    Platform type for cluster deployment.
    - kubernetes: Standard Kubernetes (vanilla, EKS, GKE, AKS, etc.)
    - openshift: Red Hat OpenShift or OKE
    """
    type: "kubernetes" | "openshift"
    distribution?: str  # e.g., "vanilla", "eks", "gke", "oke", "openshift4"

    check:
        type != "openshift" or distribution, \
            "OpenShift platform requires distribution to be set"

# Component configuration
schema ComponentConfig:
    """
    Component-level configuration (controller, apiServer, etc.)
    """
    enabled: bool
    replicas?: int = 1

schema ComponentsConfig:
    """
    All AppCat components configuration
    """
    controller?: ComponentConfig
    apiServer?: ComponentConfig
    sliExporter?: ComponentConfig
    operators?: {str: ComponentConfig}  # operator name -> config

# Cluster configuration combining platform and mode
schema ClusterConfig:
    """
    Complete cluster configuration with platform information.
    """
    platform: Platform
    components: ComponentsConfig
    namespace?: str = "appcat"
    enableMetrics?: bool = True
    enableTracing?: bool = False

schema PlanSpec:
    name: str
    cpu: str
    memory: str
    storage: str
    replicas?: int
    description?: str

schema StackGresSpec:
    namespace: str
    channel: str
    installPlanApproval?: str = "Automatic"

schema ServiceSpec:
    serviceName: str
    apiVersion: str
    composite: str
    secretNamespace: str
    stackgres: StackGresSpec
    plans: {str: PlanSpec}
    defaultPlan: str
    connectionSecretKeys: [str]
    functionRef: str
