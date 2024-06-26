include .env
export

##@ General

help: ## Display this help.
	@ awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-49s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: install-dependencies
install-dependencies:
	@ bash scripts/install-dependencies.sh

##@ Build

define build
	cd ../${SYSTEM_REPO_NAME} && git checkout scenario${1} && docker compose --env-file ${SCENARIOS_FOLDER}/${DOCKER_DEFAULT_ENV_FILE_NAME} \
		--env-file ${SCENARIOS_FOLDER}/${1}/${DOCKER_ENV_FILE_NAME} build --no-cache
endef

.PHONY: build-all
build-all: build-first build-second build-first-malabi build-second-malabi ## Build all scenarios images

.PHONY: build-first
build-first: ## Build the first scenario images
	@ $(call build,1)

.PHONY: build-second
build-second: ## Build the second scenario images
	@ $(call build,2)

.PHONY: build-first-malabi
build-first-malabi: ## Build the first scenario images for Malabi
	@ $(call build,1-malabi)

.PHONY: build-second-malabi
build-second-malabi: ## Build the second scenario images for Malabi
	@ $(call build,2-malabi)

##@ Docker Cluster

.PHONY: stop-docker
cluster-docker-stop: ## Stops the docker containers
	@ cd ../${SYSTEM_REPO_NAME} && docker compose \
		--env-file ${SCENARIOS_FOLDER}/${DOCKER_DEFAULT_ENV_FILE_NAME} down --remove-orphans --volumes
	@ echo "OpenTelemetry Demo is stopped."

.PHONY: start-first-docker
start-first-docker: ## Install and start the first scenario on docker
	@ bash scripts/start-docker-demo.sh 1

.PHONY: start-second-docker
start-second-docker: ## Install and start the second scenario on docker
	@ bash scripts/start-docker-demo.sh 2

.PHONY: start-first-malabi-docker
start-first-malabi-docker: ## Install and start the first Malabi scenario on docker
	@ bash scripts/start-docker-demo.sh 1-malabi

.PHONY: start-second-malabi-docker
start-second-malabi-docker: ## Install and start the second Malabi scenario on docker
	@ bash scripts/start-docker-demo.sh 2-malabi

##@ Kubernetes Cluster

.PHONY: cluster-kind-create
cluster-kind-create: cluster-kind-delete ## Creates a kind cluster and install the default scenario
	@ kind create cluster --config=./scripts/cluster-config.yaml --name ${CLUSTER_NAME}
	@ make cluster-load-images
	@ bash scripts/start-k8s-demo.sh
	@ make install-tracetest

.PHONY: cluster-kind-delete
cluster-kind-delete: ## Deletes the kind cluster
	@ kind delete cluster --name ${CLUSTER_NAME}

.PHONY: cluster-kind-stop
cluster-kind-stop: ## Stops the kind cluster
	@ docker stop ${CLUSTER_NAME}-control-plane
	@ echo "OpenTelemetry Demo is stopped."

.PHONY: cluster-load-images
cluster-load-images: ## Load the first scenario images on the kind cluster
	@ bash scripts/kind-load-images.sh ${DEFAULT_SCENARIO}

.PHONY: cluster-load-images-first
cluster-load-images-first: ## Load the first scenario images on the kind cluster
	@ bash scripts/kind-load-images.sh 1

.PHONY: cluster-load-images-second
cluster-load-images-second: ## Load the second scenario images on the kind cluster
	@ bash scripts/kind-load-images.sh 2

.PHONY: cluster-load-images-first-malabi
cluster-load-images-first-malabi: ## Load the first Malabi scenario images on the kind cluster
	@ bash scripts/kind-load-images.sh 1-malabi

.PHONY: cluster-load-images-second-malabi
cluster-load-images-second-malabi: ## Load the second Malabi scenario images on the kind cluster
	@ bash scripts/kind-load-images.sh 2-malabi

.PHONY: start-first-k8s
start-first-k8s: cluster-load-images-first ## Install and start the first scenario on a kubernetes cluster
	@ bash scripts/start-k8s-demo.sh 1

.PHONY: start-second-k8s
start-second-k8s: cluster-load-images-second ## Install and start the second scenario on a kubernetes cluster
	@ bash scripts/start-k8s-demo.sh 2

.PHONY: start-first-malabi-k8s
start-first-malabi-k8s: cluster-load-images-first-malabi ## Install and start the first Malabi scenario on a kubernetes cluster
	@ bash scripts/start-k8s-demo.sh 1-malabi

.PHONY: start-second-malabi-k8s
start-second-malabi-k8s: cluster-load-images-second-malabi ## Install and start the second Malabi scenario on a kubernetes cluster
	@ bash scripts/start-k8s-demo.sh 2-malabi

.PHONY: cluster-kind-uninstall-demo
cluster-kind-uninstall-demo:
	@ kubectx kind-${CLUSTER_NAME}
	@ helm uninstall ${DEMO_CHART_NAME} -n ${DEMO_NAMESPACE}

.PHONY: update-kubeconfig
update-kubeconfig: ## Updates the kind kubeconfig
	@ kind export kubeconfig --name ${CLUSTER_NAME}

##@ Tools

.PHONY: install-tracetest
install-tracetest: ## Install tracetest on the kubernetes cluster
	@ bash scripts/tracetest/setup.sh