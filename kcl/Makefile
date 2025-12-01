KCL_BIN ?= kcl
CATALOG_ROOT ?= ./appcat-catalog
PROFILE ?= kind-dev
OUTPUT_ROOT ?= $(CATALOG_ROOT)/$(PROFILE)

PLATFORM_DIR = $(OUTPUT_ROOT)/platform
REDIS_DIR = $(OUTPUT_ROOT)/redis
FORGEJO_DIR = $(OUTPUT_ROOT)/.forgejo/workflows
ARGOCD_DIR = $(OUTPUT_ROOT)/argocd

CLUSTERS ?= kind-dev

.PHONY: all clean platform redis workflows argocd fmt lint build-cluster forgejo kind-servala kind-servala-delete kind-servala-kubeconfig kind-servala-kubeconfig-local setup-dev

all: $(CLUSTERS)

$(CLUSTERS):
	@echo "==> Generating catalog for $@..."
	@$(MAKE) build-cluster PROFILE=$@ OUTPUT_ROOT=$(CATALOG_ROOT)/$@

build-cluster: platform redis workflows argocd

platform:
	@echo "==> Generating platform manifests for $(PROFILE)..."
	@rm -rf $(PLATFORM_DIR)
	@mkdir -p $(PLATFORM_DIR)
	$(KCL_BIN) run \
		profiles/$(PROFILE).k \
		platform/main.k \
		--format json | \
	python3 scripts/write_manifests.py platform $(PLATFORM_DIR)

redis:
	@echo "==> Generating redis manifests for $(PROFILE)..."
	@rm -rf $(REDIS_DIR)
	@mkdir -p $(REDIS_DIR)
	$(KCL_BIN) run \
		profiles/$(PROFILE).k \
		services/redis/main.k \
		--format json | \
	python3 scripts/write_manifests.py redis $(REDIS_DIR)
	@cp ../appcat/crds/vshn.appcat.vshn.io_xvshnredis.yaml $(REDIS_DIR)/00_xrd_vshn_redis.yaml

clean:
	@rm -rf $(OUTPUT_ROOT)

workflows:
	@echo "==> Generating Forgejo workflows..."
	@rm -rf $(FORGEJO_DIR)
	@mkdir -p $(FORGEJO_DIR)
	$(KCL_BIN) run \
		profiles/$(PROFILE).k \
		services/forgejo/main.k \
		--format json | \
	python3 scripts/write_manifests.py workflow $(FORGEJO_DIR)

argocd:
	@echo "==> Generating Argo CD resources for $(PROFILE)..."
	@rm -rf $(ARGOCD_DIR)
	@mkdir -p $(ARGOCD_DIR)
	$(KCL_BIN) run \
		profiles/$(PROFILE).k \
		argocd/main.k \
		--format json | \
	python3 scripts/write_manifests.py argocd $(ARGOCD_DIR)

fmt:
	$(KCL_BIN) fmt **/*.k

lint:
	$(KCL_BIN) lint **/*.k

# --------------------------------------------------------------------
# Development helper targets (Forgejo & Kind)
# --------------------------------------------------------------------

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    OS_TYPE := linux
    KIND_NETWORK ?= kind
else ifeq ($(UNAME_S),Darwin)
    OS_TYPE := darwin
    KIND_NETWORK ?=
else
    OS_TYPE := unknown
    KIND_NETWORK ?=
endif

FORGEJO_IMAGE ?= codeberg.org/forgejo/forgejo:1.20
FORGEJO_DATA ?= $(CURDIR)/forgejo-data
FORGEJO_RUNNER_DATA ?= $(CURDIR)/forgejo-runner-data
FORGEJO_HTTP_PORT ?= 3000
FORGEJO_SSH_PORT ?= 2222
FORGEJO_CONTAINER ?= forgejo
FORGEJO_USER ?= gitadmin
FORGEJO_PASS ?= admin123
FORGEJO_EMAIL ?= admin@example.com
FORGEJO_REPO ?= kind-dev
FORGEJO_ENV ?=

forgejo:
	@if ! command -v docker >/dev/null; then echo "Docker CLI not found"; exit 1; fi
	@mkdir -p $(FORGEJO_DATA) $(FORGEJO_RUNNER_DATA)
	@docker rm -f $(FORGEJO_CONTAINER) >/dev/null 2>&1 || true
	@echo "Starting Forgejo on http://localhost:$(FORGEJO_HTTP_PORT) (OS: $(OS_TYPE))"
ifeq ($(OS_TYPE),linux)
	@docker network inspect $(KIND_NETWORK) >/dev/null 2>&1 || docker network create $(KIND_NETWORK)
	docker run -d --name $(FORGEJO_CONTAINER) \
		--network $(KIND_NETWORK) \
		-p $(FORGEJO_HTTP_PORT):3000 \
		-p $(FORGEJO_SSH_PORT):22 \
		-v $(FORGEJO_DATA):/data \
		-v $(FORGEJO_RUNNER_DATA):/runner \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-e FORGEJO__security__INSTALL_LOCK=true \
		-e FORGEJO__server__ROOT_URL=http://localhost:$(FORGEJO_HTTP_PORT)/ \
		-e FORGEJO__actions__ENABLED=true \
		-e FORGEJO__actions__DEFAULT_ACTIONS_URL=https://code.forgejo.org \
		$(FORGEJO_IMAGE)
else
	docker run -d --name $(FORGEJO_CONTAINER) \
		-p $(FORGEJO_HTTP_PORT):3000 \
		-p $(FORGEJO_SSH_PORT):22 \
		-v $(FORGEJO_DATA):/data \
		-v $(FORGEJO_RUNNER_DATA):/runner \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--add-host=host.docker.internal:host-gateway \
		-e FORGEJO__security__INSTALL_LOCK=true \
		-e FORGEJO__server__ROOT_URL=http://localhost:$(FORGEJO_HTTP_PORT)/ \
		-e FORGEJO__actions__ENABLED=true \
		-e FORGEJO__actions__DEFAULT_ACTIONS_URL=https://code.forgejo.org \
		$(FORGEJO_IMAGE)
endif
	@echo "Waiting for Forgejo to be ready..."
	@until curl -fsS http://localhost:$(FORGEJO_HTTP_PORT)/api/healthz >/dev/null 2>&1; do sleep 2; done
	@sleep 5
	@docker exec -u git $(FORGEJO_CONTAINER) /app/gitea/gitea admin user create --admin --username $(FORGEJO_USER) --password '$(FORGEJO_PASS)' --email $(FORGEJO_EMAIL) --must-change-password=false 2>&1 | grep -v "already exists" || true
	@curl -sf -X POST "http://$(FORGEJO_USER):$(FORGEJO_PASS)@localhost:$(FORGEJO_HTTP_PORT)/api/v1/user/repos" \
		-H "Content-Type: application/json" \
		-d '{"name":"$(FORGEJO_REPO)","auto_init":true,"default_branch":"main"}' >/dev/null 2>&1 || true
	@sleep 2
	@curl -sf -X PATCH "http://$(FORGEJO_USER):$(FORGEJO_PASS)@localhost:$(FORGEJO_HTTP_PORT)/api/v1/repos/$(FORGEJO_USER)/$(FORGEJO_REPO)" \
		-H "Content-Type: application/json" \
		-d '{"has_actions":true}' >/dev/null 2>&1
	@docker exec $(FORGEJO_CONTAINER) sh -c 'if ! command -v act_runner >/dev/null 2>&1; then \
		wget -q https://dl.gitea.com/act_runner/0.2.6/act_runner-0.2.6-linux-amd64 -O /usr/local/bin/act_runner && \
		chmod +x /usr/local/bin/act_runner; fi' || true
	@if [ ! -f $(FORGEJO_RUNNER_DATA)/.runner ]; then \
		RUNNER_TOKEN=$$(docker exec -u git $(FORGEJO_CONTAINER) /app/gitea/gitea actions generate-runner-token 2>/dev/null | tail -1) && \
		docker exec $(FORGEJO_CONTAINER) sh -c "cd /runner && act_runner register --no-interactive --instance http://localhost:3000 --token $$RUNNER_TOKEN --name local-runner --labels ubuntu-latest,ubuntu-22.04,ubuntu-20.04,self-hosted" 2>/dev/null; \
	else \
		echo "Runner already registered, reusing configuration"; \
	fi
	@docker exec -d $(FORGEJO_CONTAINER) sh -c "cd /runner && act_runner daemon" 2>/dev/null || true
	@sleep 2
	@echo "Pushing kind-dev folder to Forgejo..."
	@cd $(OUTPUT_ROOT) && \
	git init >/dev/null 2>&1 && \
	git config user.name "AppCat Bot" && \
	git config user.email "appcat@example.com" && \
	$(if $(FORGEJO_ENV),echo '$(FORGEJO_ENV)' > .env &&,) \
	git add . >/dev/null 2>&1 && \
	git commit -m "Initial commit from appcat-catalog" >/dev/null 2>&1 && \
	git remote add forgejo http://$(FORGEJO_USER):$(FORGEJO_PASS)@localhost:$(FORGEJO_HTTP_PORT)/$(FORGEJO_USER)/$(FORGEJO_REPO).git 2>/dev/null || true && \
	git push -f forgejo HEAD:main && \
	rm -rf .git
	@echo "✓ Pushed catalog to http://localhost:$(FORGEJO_HTTP_PORT)/$(FORGEJO_USER)/$(FORGEJO_REPO)"

kind-servala:
	@if kind get clusters 2>/dev/null | grep -q "^servala$$"; then \
		echo "Kind cluster 'servala' already exists"; \
	else \
		echo "Creating Kind cluster 'servala' (OS: $(OS_TYPE))"; \
		if [ "$(OS_TYPE)" = "linux" ]; then \
			docker network inspect $(KIND_NETWORK) >/dev/null 2>&1 || docker network create $(KIND_NETWORK); \
			kind create cluster --name servala --config kindev/servala.yaml; \
			docker network connect $(KIND_NETWORK) servala-control-plane || true; \
		else \
			kind create cluster --name servala --config kindev/servala.yaml; \
		fi; \
	fi
	@echo "Rewriting kubeconfig for $(OS_TYPE)"
	@if [ "$(OS_TYPE)" = "linux" ]; then \
		kind get kubeconfig --name servala > kindev/servala-kubeconfig && \
		python3 scripts/rewrite-kubeconfig.py servala-control-plane kindev/servala-kubeconfig && \
		echo "✓ Kubeconfig saved (using servala-control-plane)"; \
	else \
		kind get kubeconfig --name servala > kindev/servala-kubeconfig && \
		python3 scripts/rewrite-kubeconfig.py host.docker.internal kindev/servala-kubeconfig && \
		echo "✓ Kubeconfig saved (using host.docker.internal)"; \
	fi
	@echo "Configuring Forgejo service inside cluster..."
	@if [ "$(OS_TYPE)" = "linux" ]; then \
		HOST_IP=$$(docker network inspect $(KIND_NETWORK) -f '{{(index .IPAM.Config 0).Gateway}}'); \
	else \
		HOST_IP=$$(python3 - <<'PY' \
import socket \
print(socket.gethostbyname('host.docker.internal')) \
PY \
); \
	fi; \
		kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null; \
	{ \
		echo "apiVersion: v1"; \
		echo "kind: Service"; \
		echo "metadata:"; \
		echo "  name: forgejo-external"; \
		echo "  namespace: argocd"; \
		echo "spec:"; \
		echo "  ports:"; \
		echo "    - name: http"; \
		echo "      port: 3000"; \
		echo "      targetPort: 3000"; \
		echo "---"; \
		echo "apiVersion: v1"; \
		echo "kind: Endpoints"; \
		echo "metadata:"; \
		echo "  name: forgejo-external"; \
		echo "  namespace: argocd"; \
		echo "subsets:"; \
		echo "  - addresses:"; \
		echo "      - ip: $${HOST_IP}"; \
		echo "    ports:"; \
		echo "      - port: 3000"; \
	} | kubectl apply -f - >/dev/null

kind-servala-delete:
	kind delete cluster --name servala

kind-servala-kubeconfig:
	@if [ ! -f kindev/servala-kubeconfig ]; then \
		echo "Error: kindev/servala-kubeconfig not found. Run 'make kind-servala' first." >&2; \
		exit 1; \
	fi
	@python3 -c "import base64; print(base64.b64encode(open('kindev/servala-kubeconfig', 'rb').read()).decode())"

kind-servala-kubeconfig-local:
	kind get kubeconfig --name servala

setup-dev: kind-servala forgejo
