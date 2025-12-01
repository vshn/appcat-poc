# Project configuration
PROJECT_NAME = function-appcat-poc
ORG = vshn
IMG_REPO = ghcr.io
IMG_TAG ?= latest
IMG = $(IMG_REPO)/$(ORG)/$(PROJECT_NAME):$(IMG_TAG)

# Build configuration
GOOS = linux
GOARCH = amd64
BIN_NAME = $(PROJECT_NAME)

# Docker configuration
DOCKER_CMD ?= docker
DOCKER_PLATFORM = $(GOOS)/$(GOARCH)

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: build
build: ## Build the Go binary
	env CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(BIN_NAME) .

.PHONY: clean
clean: ## Clean build artifacts
	rm -f $(BIN_NAME)
	rm -f package/*.xpkg

##@ Docker

.PHONY: docker-build
docker-build: build ## Build Docker image
	$(DOCKER_CMD) build --platform $(DOCKER_PLATFORM) -t $(IMG) .

.PHONY: docker-push
docker-push: docker-build ## Push Docker image
	$(DOCKER_CMD) push $(IMG)

.PHONY: docker-build-branchtag
docker-build-branchtag: ## Build Docker image with current branch as tag
	$(MAKE) docker-build IMG_TAG=$(shell git rev-parse --abbrev-ref HEAD | sed 's/\//_/g')

.PHONY: docker-push-branchtag
docker-push-branchtag: ## Push Docker image with current branch as tag
	$(MAKE) docker-push IMG_TAG=$(shell git rev-parse --abbrev-ref HEAD | sed 's/\//_/g')

##@ Crossplane Package

.PHONY: package-build
package-build: docker-build ## Build Crossplane XPKG
	rm -f package/*.xpkg
	go run github.com/crossplane/crossplane/cmd/crank@v1.16.0 xpkg build \
		-f package \
		--embed-runtime-image=$(IMG) \
		-o package/package.xpkg \
		--verbose

.PHONY: package-push
package-push: package-build ## Push Crossplane XPKG
	go run github.com/crossplane/crossplane/cmd/crank@v1.16.0 xpkg push \
		-f package/package.xpkg \
		$(IMG)-func \
		--verbose

.PHONY: package-build-branchtag
package-build-branchtag: ## Build XPKG with current branch as tag
	$(MAKE) package-build IMG_TAG=$(shell git rev-parse --abbrev-ref HEAD | sed 's/\//_/g')

.PHONY: package-push-branchtag
package-push-branchtag: ## Push XPKG with current branch as tag
	$(MAKE) package-push IMG_TAG=$(shell git rev-parse --abbrev-ref HEAD | sed 's/\//_/g')

##@ Local Development

.PHONY: docker-build-local
docker-build-local: ## Build Docker image for local registry (localhost:5000)
	$(MAKE) docker-build IMG_REPO=localhost:5000

.PHONY: package-build-local
package-build-local: ## Build XPKG for local registry
	$(MAKE) package-build IMG_REPO=localhost:5000

.PHONY: package-push-local
package-push-local: ## Push XPKG to local registry
	$(MAKE) package-push IMG_REPO=localhost:5000

##@ Release

.PHONY: release
release: docker-push package-push ## Build and push both Docker image and XPKG

.PHONY: release-branchtag
release-branchtag: docker-push-branchtag package-push-branchtag ## Build and push with branch tag