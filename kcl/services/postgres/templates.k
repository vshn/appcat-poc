import services.postgres.service as svc
import encoding.json as json

schema TemplateData:
    serviceName: str
    defaultPlan: str
    plans: {str: svc.PlanSpec}
    secretNamespace: str
    plansJson: str
    sideCars: str
    initContainers: str
    keepMetrics: str
    sgNamespace: str
    additionalMaintenanceClusterRole: str
    externalDatabaseConnectionsEnabled: str
    bucketRegion: str
    bucketEndpoint: str
    controlNamespace: str
    loadbalancerAnnotations: str

template = TemplateData {
    serviceName = svc.service.serviceName
    defaultPlan = svc.service.defaultPlan
    plans = svc.service.plans
    secretNamespace = svc.service.secretNamespace
    plansJson = json.encode(svc.service.plans)
    sideCars = json.encode(svc.service.sideCars)
    initContainers = json.encode(svc.service.initContainers)
    keepMetrics = json.encode(svc.service.keepMetrics)
    sgNamespace = svc.service.stackgres.namespace
    additionalMaintenanceClusterRole = svc.service.additionalMaintenanceClusterRole
    externalDatabaseConnectionsEnabled = "${svc.service.externalDatabaseConnectionsEnabled}"
    bucketRegion = svc.service.bucketRegion
    bucketEndpoint = svc.service.bucketEndpoint or ""
    controlNamespace = svc.service.controlNamespace
    loadbalancerAnnotations = svc.service.loadbalancerAnnotations or ""
}

templates = {
    "configmap.json": template,
}
