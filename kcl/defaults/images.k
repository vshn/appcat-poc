"""
Default container images for AppCat components
"""

# AppCat component images
appcat = {
    controller: "ghcr.io/vshn/appcat:v4.174.0"
    apiServer: "ghcr.io/vshn/appcat:v4.174.0-apiserver"
    sliExporter: "ghcr.io/vshn/appcat:v4.174.0-sli"
    function: "ghcr.io/vshn/appcat:v4.174.0-func"
}

# Crossplane images
crossplane = {
    core: "xpkg.upbound.io/crossplane/crossplane:v1.15.0"
    providerKubernetes: "xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.12.1"
    providerHelm: "xpkg.upbound.io/crossplane-contrib/provider-helm:v0.17.0"
    providerSql: "xpkg.upbound.io/crossplane-contrib/provider-sql:v0.10.2"
}

# Service operator images
operators = {
    stackgres: {
        version: "1.10.0"
        chart: "stackgres-operator"
        repo: "https://stackgres.io/downloads/stackgres-k8s/stackgres/helm/"
    }
    cnpg: {
        version: "1.22.0"
        chart: "cloudnative-pg"
        repo: "https://cloudnative-pg.github.io/charts"
    }
}

# Pull policy
pullPolicy = "IfNotPresent"
