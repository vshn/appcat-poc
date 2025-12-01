crossplane = {
    "00-namespace.yaml": {
        "apiVersion": "v1",
        "kind": "Namespace",
        "metadata": {
            "name": "crossplane-system",
        },
    },
    "05-runtime-config.yaml": {
        "apiVersion": "pkg.crossplane.io/v1beta1",
        "kind": "DeploymentRuntimeConfig",
        "metadata": {
            "name": "function-appcat",
        },
        "spec": {
            "deploymentTemplate": {
                "metadata": {},
                "spec": {
                    "selector": {
                        "matchLabels": {
                            "app.kubernetes.io/name": "appcat-function",
                        },
                    },
                    "template": {
                        "metadata": {
                            "labels": {
                                "app.kubernetes.io/name": "appcat-function",
                            },
                        },
                        "spec": {
                            "serviceAccountName": "crossplane",
                        },
                    },
                },
            },
        },
    },
    "10-helm-providerconfig.yaml": {
        "apiVersion": "tf.crossplane.io/v1beta1",
        "kind": "ProviderConfig",
        "metadata": {
            "name": "helm-incluster",
        },
        "spec": {
            "credentials": {
                "source": "InjectedIdentity",
            },
        },
    },
    "11-helm-release.yaml": {
        "apiVersion": "helm.crossplane.io/v1beta1",
        "kind": "Release",
        "metadata": {
            "name": "crossplane",
            "namespace": "crossplane-system",
        },
        "spec": {
            "forProvider": {
                "chart": "crossplane",
                "namespace": "crossplane-system",
                "repository": "https://charts.crossplane.io/stable",
                "version": "1.16.0",
            },
            "providerConfigRef": {
                "name": "helm-incluster",
            },
        },
    },
    "20-provider-sql.yaml": {
        "apiVersion": "pkg.crossplane.io/v1",
        "kind": "Provider",
        "metadata": {
            "name": "crossplane-provider-sql",
        },
        "spec": {
            "package": "xpkg.upbound.io/crossplane-contrib/provider-sql:v0.10.2",
        },
    },
    "21-provider-kubernetes.yaml": {
        "apiVersion": "pkg.crossplane.io/v1",
        "kind": "Provider",
        "metadata": {
            "name": "crossplane-provider-kubernetes",
        },
        "spec": {
            "package": "xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v1.14.0",
        },
    },
    "22-provider-helm.yaml": {
        "apiVersion": "pkg.crossplane.io/v1",
        "kind": "Provider",
        "metadata": {
            "name": "crossplane-provider-helm",
        },
        "spec": {
            "package": "xpkg.upbound.io/crossplane-contrib/provider-helm:v0.17.0",
        },
    },
    "25-providerconfig-kubernetes-incluster.yaml": {
        "apiVersion": "kubernetes.crossplane.io/v1alpha1",
        "kind": "ProviderConfig",
        "metadata": {
            "name": "kubernetes-incluster",
        },
        "spec": {
            "credentials": {
                "source": "InjectedIdentity",
            },
        },
    },
    "26-providerconfig-kubernetes-service-cluster.yaml": {
        "apiVersion": "kubernetes.crossplane.io/v1alpha1",
        "kind": "ProviderConfig",
        "metadata": {
            "name": "kubernetes-service-cluster",
            "annotations": {
                "kcl.appcat.vshn.io/description": "ProviderConfig for split-mode service cluster access",
                "kcl.appcat.vshn.io/mode": "service_cluster",
            },
        },
        "spec": {
            "credentials": {
                "source": "Secret",
                "secretRef": {
                    "namespace": "crossplane-system",
                    "name": "service-cluster-kubeconfig",
                    "key": "kubeconfig",
                },
            },
        },
    },
    "30-function-appcat.yaml": {
        "apiVersion": "apiextensions.crossplane.io/v1alpha1",
        "kind": "Function",
        "metadata": {
            "name": "function-appcat-v3-61-0-v4-174-0",
            "namespace": "crossplane-system",
        },
        "spec": {
            "package": "ghcr.io/vshn/appcat:v4.174.0-func",
            "runtimeConfigRef": {
                "apiVersion": "pkg.crossplane.io/v1beta1",
                "kind": "DeploymentRuntimeConfig",
                "name": "function-appcat",
            },
        },
    },
}
