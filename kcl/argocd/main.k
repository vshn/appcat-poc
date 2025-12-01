clusterName = profile.name or "cluster"
repoURL = profile.repoURL or "https://example.com/appcat-catalog.git"
argocdNs = profile.argocdNamespace or "argocd"
services = [
    {
        name = "redis"
        path = "redis"
    }
] if profile.services?.redis?.enabled != False else []

root_app = {
    apiVersion = "argoproj.io/v1alpha1"
    kind = "Application"
    metadata = {
        name = "appcat-root-" + clusterName
        namespace = argocdNs
    }
    spec = {
        project = "default"
        destination = {
            server = "https://kubernetes.default.svc"
            namespace = argocdNs
        }
        source = {
            repoURL = repoURL
            targetRevision = "HEAD"
            path = "argocd/apps"
            directory = {
                recurse = True
            }
        }
        syncPolicy = {
            automated = {
                prune = True
                selfHeal = True
            }
            syncOptions = ["CreateNamespace=true"]
        }
    }
}

platform_app = {
    apiVersion = "argoproj.io/v1alpha1"
    kind = "Application"
    metadata = {
        name = "appcat-platform-" + clusterName
        namespace = argocdNs
        annotations = {
            "argocd.argoproj.io/sync-wave" = "0"
        }
    }
    spec = {
        project = "default"
        destination = {
            server = "https://kubernetes.default.svc"
            namespace = profile.crossplaneNamespace or "crossplane-system"
        }
        source = {
            repoURL = repoURL
            targetRevision = "HEAD"
            path = "platform"
        }
        syncPolicy = {
            automated = {
                prune = True
                selfHeal = True
            }
            syncOptions = ["CreateNamespace=true"]
        }
    }
}

services_appset = {
    apiVersion = "argoproj.io/v1alpha1"
    kind = "ApplicationSet"
    metadata = {
        name = "appcat-services-" + clusterName
        namespace = argocdNs
        annotations = {
            "argocd.argoproj.io/sync-wave" = "10"
        }
    }
    spec = {
        generators = [
            {
                list = {
                    elements = services
                }
            }
        ]
        template = {
            metadata = {
                name = "appcat-{{name}}-" + clusterName
            }
            spec = {
                project = "default"
                destination = {
                    server = "https://kubernetes.default.svc"
                    namespace = profile.crossplaneNamespace or "crossplane-system"
                }
                source = {
                    repoURL = repoURL
                    targetRevision = "HEAD"
                    path = "{{path}}"
                }
                syncPolicy = {
                    automated = {
                        prune = True
                        selfHeal = True
                    }
                    syncOptions = ["CreateNamespace=true"]
                }
            }
        }
    }
}

argocd = {
    "root-app.yaml" = root_app
    "apps/platform-app.yaml" = platform_app
    "apps/services-appset.yaml" = services_appset
}
