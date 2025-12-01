redis_service = {
    serviceName = "redis"
    serviceID = "vshn-redis"
    apiVersion = "vshn.appcat.vshn.io/v1"
    compositeName = "vshnredis.vshn.appcat.vshn.io"
    claim = {
        kind = "VSHNRedis"
        plural = "vshnredis"
    }
    composedKind = "XVSHNRedis"
    connectionSecretKeys = [
        "ca.crt",
        "tls.crt",
        "tls.key",
        "REDIS_HOST",
        "REDIS_PORT",
        "REDIS_USERNAME",
        "REDIS_PASSWORD",
        "REDIS_URL",
        "SENTINEL_HOSTS",
    ]
    defaultPlan = "standard-1"
    plansJSON = """{"standard-512m":{"size":{"enabled":true,"cpu":"125m","memory":"512Mi","disk":"16Gi"}},"standard-1":{"size":{"enabled":true,"cpu":"250m","memory":"1Gi","disk":"16Gi"}},"standard-2":{"size":{"enabled":true,"cpu":"500m","memory":"2Gi","disk":"16Gi"}},"standard-4":{"size":{"enabled":true,"cpu":"1","memory":"4Gi","disk":"16Gi"}},"standard-8":{"size":{"enabled":true,"cpu":"2","memory":"8Gi","disk":"16Gi"}}}"""
    functionStep = "redis-func"
    functionName = "function-appcat-redis"
    restore = {
        serviceAccount = "redisrestoreserviceaccount"
        clusterRole = "crossplane:appcat:job:redis:restorejob"
        clusterRoleBinding = "appcat:job:redis:restorejob"
    }
    metadata = {
        displayName = "Redis by VSHN"
        description = "Managed Redis instances"
        docsURL = "https://vs.hn/vshn-redis"
        flavor = "standalone"
        productDescription = "https://products.docs.vshn.ch/products/appcat/redis.html"
        offered = "true"
    }
    planZone = "global"
    bucketRegion = "global"
    chartRepository = "oci://registry-1.docker.io/bitnamicharts/redis"
    chartVersion = "23.2.1"
    imageRegistry = "ghcr.io"
    imageRepositoryPrefix = "vshn"
    imageTag = "v4.174.0"
    functionImage = "ghcr.io/vshn/appcat-redis:v4.174.0-func"
    kubectlImage = "docker.io/bitnamilegacy/kubectl:1.25.15"
    maintenanceSA = "helm-based-service-maintenance"
    maintenanceURL = "https://ghcr.io/v2/vshn/redis/tags/list?page_size=100"
    sideCarsJSON = """{"kubectl":{"requests":{"cpu":"10m","memory":"50Mi"},"limits":{"cpu":"100m","memory":"100Mi"}},"metrics":{"requests":{"cpu":"100m","memory":"128Mi"},"limits":{"cpu":"150m","memory":"192Mi"}},"sentinel":{"requests":{"cpu":"10m","memory":"50Mi"},"limits":{"cpu":"100m","memory":"100Mi"}}}"""
    sliNamespace = "syn-appcat-slos"
}
