"""
Default resource requests and limits for AppCat components
"""

# Controller resource defaults
controller = {
    requests: {
        cpu: "100m"
        memory: "128Mi"
    }
    limits: {
        cpu: "500m"
        memory: "512Mi"
    }
}

# API Server resource defaults
apiServer = {
    requests: {
        cpu: "100m"
        memory: "128Mi"
    }
    limits: {
        cpu: "500m"
        memory: "512Mi"
    }
}

# SLI Exporter resource defaults
sliExporter = {
    requests: {
        cpu: "50m"
        memory: "64Mi"
    }
    limits: {
        cpu: "200m"
        memory: "256Mi"
    }
}

# Function runtime resource defaults
function = {
    requests: {
        cpu: "100m"
        memory: "256Mi"
    }
    limits: {
        cpu: "1000m"
        memory: "1Gi"
    }
}

# Crossplane resource defaults
crossplane = {
    requests: {
        cpu: "100m"
        memory: "256Mi"
    }
    limits: {
        cpu: "1000m"
        memory: "1Gi"
    }
}
