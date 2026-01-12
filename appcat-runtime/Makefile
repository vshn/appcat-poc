.PHONY: build kind-load build-xpkg push clean

IMAGE ?= ghcr.io/vshn/function-appcat-poc
TAG ?= v0.1.0
KIND_CLUSTER ?= appcat-poc
XPKG_FILE ?= function-appcat-poc.xpkg

# Auto-detect platform
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),arm64)
	GOARCH ?= arm64
else ifeq ($(UNAME_M),aarch64)
	GOARCH ?= arm64
else
	GOARCH ?= amd64
endif

# Build Go binary
build:
	@echo "Building Go composition function for linux/$(GOARCH)..."
	@CGO_ENABLED=0 GOOS=linux GOARCH=$(GOARCH) go build -o function-appcat-poc .
	@echo "Binary built: function-appcat-poc"

# Build and load into Kind cluster
kind-load: build
	@echo "Building Docker image for Kind cluster (linux/$(GOARCH))..."
	@docker build -t $(IMAGE):$(TAG) .
	@echo "Loading image into Kind cluster: $(KIND_CLUSTER)..."
	@kind load docker-image $(IMAGE):$(TAG) --name $(KIND_CLUSTER)
	@echo "Image loaded into Kind cluster"

# Build Crossplane xpkg package
build-xpkg: build
	@echo "Building Crossplane xpkg package..."
	@docker build -t $(IMAGE):$(TAG) .
	@crossplane xpkg build --package-root=. --package-file=$(XPKG_FILE) --embed-runtime-image=$(IMAGE):$(TAG)
	@echo "xpkg package built: $(XPKG_FILE)"

# Push xpkg to registry
push: build-xpkg
	@echo "Pushing xpkg to $(IMAGE):$(TAG)..."
	@crossplane xpkg push $(IMAGE):$(TAG) -f $(XPKG_FILE)
	@echo "xpkg pushed to $(IMAGE):$(TAG)"

# Clean build artifacts
clean:
	@rm -f function-appcat-poc $(XPKG_FILE)
	@echo "Cleaned build artifacts"
