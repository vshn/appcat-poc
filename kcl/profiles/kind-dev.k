import defs

profile = {
    name: "kind-dev"
    description: "Kind development cluster"
    platform: defs.Platform {
        type: "kubernetes"
        distribution: "kind"
    }
    argocdNamespace: "argocd"
    crossplaneNamespace: "syn-crossplane"
    # Forgejo is running on the host; the kind network gateway is reachable at 172.18.0.1
    # from inside the cluster. This keeps things simple for the PoC.
    repoURL: "http://172.18.0.1:3000/gitadmin/kind-dev"
    repoCredentials: {
        username: "gitadmin"
        password: "admin123"
        insecure: True
    }
    services: {
        redis: {
            enabled: True
            overrides: {
                chartRepository: "oci://registry-1.docker.io/bitnamicharts/redis"
            }
        }
    }
}
