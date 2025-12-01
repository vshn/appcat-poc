import defs

profile = {
    name: "servala"
    description: "Servala PoC running on a vanilla Kind cluster"
    platform: defs.Platform {
        type: "kubernetes"
        distribution: "kind"
    }
    argocdNamespace: "argocd"
    crossplaneNamespace: "crossplane-system"
    repoURL: "https://gitlab.example.com/vshn/appcat-catalog.git"
    services: {
        redis: {
            enabled: True
            overrides: {}
        }
    }
}
