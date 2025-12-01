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
    planNames: [str]
    defaultPlan: str
    connectionSecretKeys: [str]
    functionRef: str
    externalDatabaseConnectionsEnabled: bool
    sideCars: [any]
    initContainers: [any]
    keepMetrics: [str]
    bucketRegion: str
    bucketEndpoint?: str
    controlNamespace: str
    additionalMaintenanceClusterRole: str
    loadbalancerAnnotations?: str

service = ServiceSpec {
    serviceName = "postgresql"
    apiVersion = "vshn.appcat.vshn.io/v1"
    composite = "vshnpostgres.vshn.appcat.vshn.io"
    secretNamespace = "syn-crossplane"
    stackgres = StackGresSpec {
        namespace = "stackgres"
        channel = "stable"
    }
    plans = {
        "standard-2": PlanSpec {
            name = "standard-2"
            cpu = "400m"
            memory = "1936Mi"
            storage = "20Gi"
            replicas = 2
            description = "Highly available plan with 2 replicas"
        },
        "standard-4": PlanSpec {
            name = "standard-4"
            cpu = "800m"
            memory = "3872Mi"
            storage = "40Gi"
            replicas = 2
        },
    }
    planNames = ["standard-2", "standard-4"]
    defaultPlan = "standard-2"
    connectionSecretKeys = [
        "ca.crt",
        "tls.crt",
        "tls.key",
        "POSTGRESQL_URL",
        "POSTGRESQL_DB",
        "POSTGRESQL_HOST",
        "POSTGRESQL_PORT",
        "POSTGRESQL_USER",
        "POSTGRESQL_PASSWORD",
        "LOADBALANCER_IP",
    ]
    functionRef = "function-appcat-v3-61-0-v4-174-0"
    externalDatabaseConnectionsEnabled = True
    sideCars = []
    initContainers = []
    keepMetrics = [
        "pg_locks_count",
        "pg_postmaster_start_time_seconds",
        "pg_replication_lag",
    ]
    bucketRegion = "global"
    bucketEndpoint = ""
    controlNamespace = "syn-crossplane"
    additionalMaintenanceClusterRole = "crossplane:appcat:job:postgres:maintenance"
    loadbalancerAnnotations = ""
}
