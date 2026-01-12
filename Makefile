.PHONY: help setup build push build-proxy deploy test clean kind-delete debug-start debug-stop

# Default proxy endpoint for debug mode
PROXY_ENDPOINT ?= host.docker.internal:9443

# Default target
help:
	@echo "AppCat PoC - Available targets:"
	@echo ""
	@echo "Setup:"
	@echo "  setup                - Create Kind cluster + install Crossplane"
	@echo ""
	@echo "Build:"
	@echo "  build                - Build all packages locally"
	@echo "  push                 - Push built packages to ghcr.io"
	@echo "  build-proxy          - Build with proxy mode for local debugging"
	@echo ""
	@echo "Deploy:"
	@echo "  deploy               - Deploy platform + redis-service configuration"
	@echo ""
	@echo "Debug:"
	@echo "  debug-start          - Start local function for debugging (blocking)"
	@echo "  debug-stop           - Stop local debugging function"
	@echo ""
	@echo "Test:"
	@echo "  test                 - Create test Redis instance"
	@echo ""
	@echo "Clean:"
	@echo "  clean                - Clean all build artifacts"
	@echo "  kind-delete          - Delete Kind cluster"

# Setup: Create cluster and install Crossplane
setup:
	@echo "Creating Kind cluster 'appcat-poc'..."
	@kind create cluster --name appcat-poc
	@echo "Installing Crossplane 2.0..."
	@helm repo add crossplane-stable https://charts.crossplane.io/stable
	@helm repo update
	@helm install crossplane crossplane-stable/crossplane \
		--namespace crossplane-system \
		--create-namespace \
		--wait
	@echo "Cluster setup complete!"

# Build all packages locally
build:
	@echo "Building all packages locally..."
	@echo ""
	@echo "[1/3] Building platform..."
	@cd platform && $(MAKE) build
	@echo ""
	@echo "[2/3] Building appcat-runtime xpkg..."
	@cd appcat-runtime && $(MAKE) build-xpkg
	@echo ""
	@echo "[3/3] Building redis-service xpkg..."
	@cd redis-service && $(MAKE) build
	@echo ""
	@echo "All packages built!"

# Push built packages to registry
push:
	@echo "Pushing all packages to ghcr.io..."
	@echo ""
	@echo "[1/2] Pushing appcat-runtime function..."
	@cd appcat-runtime && $(MAKE) push
	@echo ""
	@echo "[2/2] Pushing redis-service package..."
	@cd redis-service && $(MAKE) push
	@echo ""
	@echo "All packages pushed to ghcr.io!"

# Build with proxy mode for local debugging
build-proxy:
	@echo "Building in proxy/debug mode..."
	@echo ""
	@echo "[1/3] Building platform with proxy enabled (endpoint: $(PROXY_ENDPOINT))..."
	@cd platform && $(MAKE) build-proxy PROXY_ENDPOINT=$(PROXY_ENDPOINT)
	@echo ""
	@echo "[2/3] Building appcat-runtime xpkg..."
	@cd appcat-runtime && $(MAKE) build-xpkg
	@echo ""
	@echo "[3/3] Building redis-service xpkg..."
	@cd redis-service && $(MAKE) build
	@echo ""
	@echo "Build complete in proxy mode!"
	@echo ""
	@echo "Remember to push packages: make push"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Push packages: make push"
	@echo "  2. Deploy: make deploy"
	@echo "  3. Start local function: make debug-start"

# Deploy: Platform infrastructure + Redis service configuration
deploy:
	@kind get kubeconfig --name appcat-poc > ~/.kube/config
	@echo "Deploying platform..."
	@echo ""
	@echo "[1/4] Installing providers and infrastructure..."
	@kubectl apply -f platform/rendered/ || true
	@echo ""
	@echo "[2/4] Waiting for provider-helm to be healthy..."
	@while true; do \
		if kubectl wait --for=condition=Healthy provider/provider-helm --timeout=30s 2>/dev/null; then \
			echo "Provider-helm is healthy!"; \
			break; \
		else \
			echo "Provider-helm still initializing..."; \
			sleep 10; \
		fi; \
	done
	@echo ""
	@echo "[3/4] Applying ProviderConfigs..."
	@kubectl apply -f platform/rendered/
	@echo ""
	@echo "Platform deployment complete!"
	@echo ""
	@echo "[4/4] Deploying redis-service configuration..."
	@kubectl apply -f redis-service/configuration/
	@echo ""
	@echo "Service Deployment complete!"


# Test: Create Redis instance
test:
	@kind get kubeconfig --name appcat-poc > ~/.kube/config
	@echo "Creating test Redis instance..."
	@kubectl apply -f examples/redis-instance.yaml
	@echo "Test instance created!"
	@echo ""
	@echo "Check status:"
	@echo "  kubectl get xvshnredis"
	@echo "  kubectl get release -n default"

# Debug: Start local composition function
debug-start:
	@echo "Starting local composition function for debugging..."
	@echo "Function will listen on localhost:9443"
	@echo "Cluster will forward requests to $(PROXY_ENDPOINT)"
	@cd appcat-runtime && go run . --insecure --addr :9443

# Debug: Stop local function
debug-stop:
	@echo "Stopping local debugging function..."
	@pkill -f "go run.*appcat-runtime" || echo "No debug process found"

# Clean: Remove build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@cd redis-service && $(MAKE) clean
	@cd platform && $(MAKE) clean
	@cd appcat-runtime && $(MAKE) clean
	@echo "Clean complete!"

# Teardown: Delete Kind cluster
kind-delete:
	@echo "Deleting Kind cluster 'appcat-poc'..."
	@kind delete cluster --name appcat-poc
	@echo "Kind cluster deleted!"
