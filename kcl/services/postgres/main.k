import services.postgres.xpkg as xpkg_mod
import services.postgres.cluster_catalog as catalog_mod
import services.postgres.templates as templates_mod

outputs = {
    xpkg = xpkg_mod.xpkg
    clusterCatalog = catalog_mod.cluster_catalog
    templates = templates_mod.templates
}
