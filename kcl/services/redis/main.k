import services.redis.service as svc

_overrides = {}
if profile.services?.redis?.overrides:
    _overrides = profile.services.redis.overrides
base = svc.redis_service

service = {
    serviceName = _overrides?.serviceName if _overrides?.serviceName else base.serviceName
    serviceID = _overrides?.serviceID if _overrides?.serviceID else base.serviceID
    apiVersion = _overrides?.apiVersion if _overrides?.apiVersion else base.apiVersion
    compositeName = _overrides?.compositeName if _overrides?.compositeName else base.compositeName
    claim = _overrides?.claim if _overrides?.claim else base.claim
    composedKind = _overrides?.composedKind if _overrides?.composedKind else base.composedKind
    connectionSecretKeys = _overrides?.connectionSecretKeys if _overrides?.connectionSecretKeys else base.connectionSecretKeys
    defaultPlan = _overrides?.defaultPlan if _overrides?.defaultPlan else base.defaultPlan
    plansJSON = _overrides?.plansJSON if _overrides?.plansJSON else base.plansJSON
    functionStep = _overrides?.functionStep if _overrides?.functionStep else base.functionStep
    functionName = _overrides?.functionName if _overrides?.functionName else base.functionName
    restore = _overrides?.restore if _overrides?.restore else base.restore
    metadata = _overrides?.metadata if _overrides?.metadata else base.metadata
    planZone = _overrides?.planZone if _overrides?.planZone else base.planZone
    bucketRegion = _overrides?.bucketRegion if _overrides?.bucketRegion else base.bucketRegion
    chartRepository = _overrides?.chartRepository if _overrides?.chartRepository else base.chartRepository
    chartVersion = _overrides?.chartVersion if _overrides?.chartVersion else base.chartVersion
    imageRegistry = _overrides?.imageRegistry if _overrides?.imageRegistry else base.imageRegistry
    imageRepositoryPrefix = _overrides?.imageRepositoryPrefix if _overrides?.imageRepositoryPrefix else base.imageRepositoryPrefix
    imageTag = _overrides?.imageTag if _overrides?.imageTag else base.imageTag
    kubectlImage = _overrides?.kubectlImage if _overrides?.kubectlImage else base.kubectlImage
    maintenanceSA = _overrides?.maintenanceSA if _overrides?.maintenanceSA else base.maintenanceSA
    maintenanceURL = _overrides?.maintenanceURL if _overrides?.maintenanceURL else base.maintenanceURL
    sideCarsJSON = _overrides?.sideCarsJSON if _overrides?.sideCarsJSON else base.sideCarsJSON
    sliNamespace = _overrides?.sliNamespace if _overrides?.sliNamespace else base.sliNamespace
}
crossplane_namespace = profile.crossplaneNamespace or "crossplane-system"
redis_enabled = profile.services?.redis?.enabled != False
function_name = service.functionName
function_image = service.functionImage
function_manifest = {
    apiVersion = "apiextensions.crossplane.io/v1alpha1"
    kind = "Function"
    metadata = {
        name = function_name
        namespace = crossplane_namespace
    }
    spec = {
        package = function_image
        runtimeConfigRef = {
            name = "function-appcat"
        }
    }
}

function_configmap = {
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
        name = "appcat-redis-func-config"
        namespace = crossplane_namespace
    }
    data = {
        serviceName = service.serviceName
        serviceID = service.serviceID
        defaultPlan = service.defaultPlan
        plans = service.plansJSON
        connectionSecretKeys = service.connectionSecretKeys
        secretNamespace = crossplane_namespace
        controlNamespace = crossplane_namespace
        crossplaneNamespace = crossplane_namespace
        bucketRegion = service.bucketRegion
        chartRepository = service.chartRepository
        chartVersion = service.chartVersion
        imageRegistry = service.imageRegistry
        imageRepositoryPrefix = service.imageRepositoryPrefix
        imageTag = service.imageTag
        kubectl_image = service.kubectlImage
        maintenanceSA = service.maintenanceSA
        maintenanceURL = service.maintenanceURL
        sideCars = service.sideCarsJSON
        sliNamespace = service.sliNamespace
    }
}

composition = {
    apiVersion = "apiextensions.crossplane.io/v1"
    kind = "Composition"
    metadata = {
        name = service.compositeName
        labels = {
            "metadata.appcat.vshn.io/serviceID" = service.serviceID
            "metadata.appcat.vshn.io/offered" = service.metadata.offered
        }
        annotations = {
            "metadata.appcat.vshn.io/displayname" = service.metadata.displayName
            "metadata.appcat.vshn.io/description" = service.metadata.description
            "metadata.appcat.vshn.io/end-user-docs-url" = service.metadata.docsURL
            "metadata.appcat.vshn.io/product-description" = service.metadata.productDescription
            "metadata.appcat.vshn.io/flavor" = service.metadata.flavor
            "metadata.appcat.vshn.io/plans" = service.plansJSON
            "metadata.appcat.vshn.io/zone" = service.planZone
        }
    }
    spec = {
        compositeTypeRef = {
            apiVersion = service.apiVersion
            kind = service.composedKind
        }
        writeConnectionSecretsToNamespace = crossplane_namespace
        mode = "Pipeline"
        pipeline = [
            {
                step = service.functionStep
                functionRef = {
                    name = service.functionName
                }
                inputRef = {
                    apiVersion = "v1"
                    kind = "ConfigMap"
                    name = "appcat-redis-func-config"
                    namespace = crossplane_namespace
                }
            }
        ]
    }
}

plans_cm = {
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
        name = "vshnredisplans"
        namespace = crossplane_namespace
        labels = {
            name = "vshnredisplans"
        }
    }
    data = {
        plans = service.plansJSON
    }
}

restore_role = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind = "ClusterRole"
    metadata = {
        name = service.restore.clusterRole
    }
    rules = [
        {
            apiGroups = ["vshn.appcat.vshn.io"]
            resources = ["*"]
            verbs = ["get"]
        }
        {
            apiGroups = ["k8up.io"]
            resources = ["snapshots"]
            verbs = ["get"]
        }
        {
            apiGroups = [""]
            resources = ["secrets"]
            verbs = ["get", "list", "create", "delete"]
        }
        {
            apiGroups = ["apps"]
            resources = ["statefulsets", "statefulsets/scale"]
            verbs = ["get", "update", "patch"]
        }
        {
            apiGroups = ["batch"]
            resources = ["jobs"]
            verbs = ["get"]
        }
        {
            apiGroups = [""]
            resources = ["events"]
            verbs = ["get", "create", "patch"]
        }
    ]
}

restore_sa = {
    apiVersion = "v1"
    kind = "ServiceAccount"
    metadata = {
        name = service.restore.serviceAccount
        namespace = crossplane_namespace
    }
}

restore_binding = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind = "ClusterRoleBinding"
    metadata = {
        name = service.restore.clusterRoleBinding
    }
    roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind = "ClusterRole"
        name = service.restore.clusterRole
    }
    subjects = [
        {
            kind = "ServiceAccount"
            name = service.restore.serviceAccount
            namespace = crossplane_namespace
        }
    ]
}

redis = {
    "10_composition_vshn_redis.yaml": composition,
    "15_function_configmap.yaml": function_configmap,
    "20_plans_configmap.yaml": plans_cm,
    "30_restore_clusterrole.yaml": restore_role,
    "31_restore_serviceaccount.yaml": restore_sa,
    "32_restore_binding.yaml": restore_binding,
    "40_function_appcat_redis.yaml": function_manifest,
} if redis_enabled else {}
