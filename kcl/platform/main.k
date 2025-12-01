crossplane_namespace = profile.crossplaneNamespace or "crossplane-system"
function_runtime_name = "function-appcat"

resources = {
    "00_namespace.yaml": {
        apiVersion = "v1"
        kind = "Namespace"
        metadata = {
            name = crossplane_namespace
        }
    }
    "05_crossplane_release.yaml": {
        apiVersion = "helm.crossplane.io/v1beta1"
        kind = "Release"
        metadata = {
            name = "crossplane"
            namespace = crossplane_namespace
        }
        spec = {
            forProvider = {
                chart = "crossplane"
                repository = "https://charts.crossplane.io/stable"
                version = "1.15.0"
                namespace = crossplane_namespace
                values = {
                    args = ["--enable-composition-webhook-schema-validation"]
                }
            }
            providerConfigRef = {
                name = "helm-incluster"
            }
        }
    }
    "10_provider_kubernetes.yaml": {
        apiVersion = "pkg.crossplane.io/v1"
        kind = "Provider"
        metadata = {
            name = "crossplane-provider-kubernetes"
        }
        spec = {
            package = "xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.15.0"
        }
    }
    "11_provider_helm.yaml": {
        apiVersion = "pkg.crossplane.io/v1"
        kind = "Provider"
        metadata = {
            name = "crossplane-provider-helm"
        }
        spec = {
            package = "xpkg.upbound.io/crossplane-contrib/provider-helm:v0.17.0"
        }
    }
    "20_providerconfig_kubernetes.yaml": {
        apiVersion = "kubernetes.crossplane.io/v1alpha1"
        kind = "ProviderConfig"
        metadata = {
            name = "kubernetes-incluster"
        }
        spec = {
            credentials = {
                source = "InjectedIdentity"
            }
        }
    }
    "21_providerconfig_helm.yaml": {
        apiVersion = "helm.crossplane.io/v1beta1"
        kind = "ProviderConfig"
        metadata = {
            name = "helm-incluster"
        }
        spec = {
            credentials = {
                source = "InjectedIdentity"
            }
        }
    }
    "30_runtime_config.yaml": {
        apiVersion = "pkg.crossplane.io/v1beta1"
        kind = "DeploymentRuntimeConfig"
        metadata = {
            name = function_runtime_name
        }
        spec = {
            deploymentTemplate = {
                spec = {
                    selector = {}
                    template = {
                        spec = {
                            serviceAccountName = "crossplane"
                        }
                    }
                }
            }
        }
    }
}

platform = resources
