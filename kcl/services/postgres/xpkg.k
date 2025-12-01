import services.postgres.service as svc
import services.postgres.xrd_data as xrd_data

xpkg = {
    "crossplane.yaml": {
        apiVersion = "meta.pkg.crossplane.io/v1"
        kind = "Configuration"
        metadata = {
            name = "appcat-${svc.service.serviceName}"
            annotations = {
                "meta.crossplane.io/maintainer" = "VSHN AG"
                "meta.crossplane.io/source" = "github.com/vshn/appcat"
                "meta.crossplane.io/license" = "BSD-3-Clause"
                "meta.crossplane.io/description" = "AppCat ${svc.service.serviceName} service configuration"
                "meta.crossplane.io/readme" = "Provides VSHN managed ${svc.service.serviceName} instances with StackGres backend"
            }
        }
        spec = {
            crossplane = {
                version = ">=v1.15.0"
            }
            dependsOn = [
                {
                    provider = "xpkg.upbound.io/crossplane-contrib/provider-kubernetes"
                    version = ">=v0.12.1"
                },
                {
                    provider = "xpkg.upbound.io/crossplane-contrib/provider-helm"
                    version = ">=v0.17.0"
                },
                {
                    provider = "xpkg.upbound.io/crossplane-contrib/provider-sql"
                    version = ">=v0.10.0"
                },
                {
                    function = "ghcr.io/vshn/appcat"
                    version = ">=v4.174.0"
                },
            ]
        }
    },
    "xrd.yaml": xrd_data.xrd,
    "composition.yaml": {
        apiVersion = "apiextensions.crossplane.io/v1"
        kind = "Composition"
        metadata = {
            name = svc.service.composite
            labels = {
                "appcat.vshn.io/service" = svc.service.serviceName
            }
        }
        spec = {
            compositeTypeRef = {
                apiVersion = svc.service.apiVersion
                kind = "XVSHNPostgreSQL"
            }
            writeConnectionSecretsToNamespace = svc.service.secretNamespace
            mode = "Pipeline"
            pipeline = [
                {
                    step = "postgres-composition"
                    functionRef = {
                        name = svc.service.functionRef
                    }
                    input = {
                        apiVersion = "appcat.vshn.io/v1"
                        kind = "PostgreSQLConfig"
                        metadata = {
                            name = "postgres-config"
                        }
                        spec = {
                            service = svc.service.serviceName
                            plans = svc.service.plans
                            defaultPlan = svc.service.defaultPlan
                            connectionSecretKeys = svc.service.connectionSecretKeys
                            stackgres = svc.service.stackgres
                        }
                    }
                }
            ]
        }
    }
}
