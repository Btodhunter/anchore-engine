# Variables set in CircleCI - do not set locally to prevent any accidental pushes to Dockerhub
DEV_IMAGE_REPO ?= anchore/anchore-engine-dev
PROD_IMAGE_REPO ?=
RELEASE_BRANCHES ?=
LATEST_RELEASE_BRANCH ?=
ANCHORE_CLI_VERSION ?=
DOCKER_USER ?=
DOCKER_PASS ?=
# Set CI=true when running in CircleCI. This setting will setup the proper env for CircleCI
# All production & RC image push jobs to Dockerhub are gated on CI=true
CI ?= false
# Set SKIP_CLEANUP=true to prevent all exit cleanup tasks from running
SKIP_CLEANUP ?= false
# Use $CIRCLE_SHA if it's set, otherwise use SHA from HEAD
COMMIT_SHA ?= $(shell echo $${CIRCLE_SHA:=$$(git rev-parse HEAD)})
# Use $CIRCLE_PROJECT_REPONAME if it's set, otherwise the git project top level dir name
GIT_REPO ?= $(shell echo $${CIRCLE_PROJECT_REPONAME:=$$(basename `git rev-parse --show-toplevel`)})
# Use $CIRCLE_BRANCH if it's set, otherwise use current HEAD branch
GIT_BRANCH ?= $(shell echo $${CIRCLE_BRANCH:=$$(git rev-parse --abbrev-ref HEAD)})
# Use $CIRCLE_TAG if it's set, otherwise set to latest tag
GIT_TAG ?= $(shell echo $${CIRCLE_TAG:=git describe --abbrev=0 --tags})
# Use $ANCHORE_CLI_VERSION if it's set, otherwise get commit SHA of the latest anchore-cli tag
CLI_COMMIT_SHA ?= $(shell echo $${ANCHORE_CLI_VERSION:=$$(git ls-remote git@github.com:anchore/anchore-cli.git --sort="version:refname" --tags v\* | tail -n1 | awk '{print $$1}')})

# Testing environment configuration
TEST_IMAGE_NAME = $(GIT_REPO):dev
KIND_VERSION := v0.7.0
KIND_NODE_IMAGE_TAG := v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
KUBECTL_VERSION := v1.15.0
HELM_VERSION := v3.1.1

# Make environment configuration
RUN_COMMAND := scripts/ci/make_run_command
ENV := /usr/bin/env
VENV_NAME := venv
VENV_ACTIVATE = $(VENV_NAME)/bin/activate
PYTHON = $(VENV_NAME)/bin/python3
PYTHON_VERSION := 3.6.6
.DEFAULT_GOAL := help # Running `Make` will run the help target
.NOTPARALLEL: # wait for targets to finish
.EXPORT_ALL_VARIABLES: # send all vars to shell

### Define available make commands - use ## on target names to create 'help' text ###

.PHONY: build
build: Dockerfile ## build dev image
	@$(RUN_COMMAND) build

.PHONY: push
push: ## push dev image to dockerhub
	@$(RUN_COMMAND) push_dev_image

.PHONY: push-rc
push-rc: ## push rc image to dockerhub
	@$(RUN_COMMAND) push_rc_image

.PHONY: push-prod
push-prod: ## push production image to dockerhub
	@$(RUN_COMMAND) push_prod_image

.PHONY: venv
venv: $(VENV_ACTIVATE) ## setup virtual environment
$(VENV_ACTIVATE):
	@$(RUN_COMMAND) setup_venv

.PHONY: install
install: venv setup.py requirements.txt ## install project to venv
	@$(RUN_COMMAND) install

.PHONY: install-dev
install-dev: venv setup.py requirements.txt ## install project to venv in editable mode
	@$(RUN_COMMAND) install_dev

.PHONY: deps
deps: venv ## install testing dependencies
	@$(RUN_COMMAND) install_testing_deps

.PHONY: compose-up
compose-up: deps scripts/ci/docker-compose-ci.yaml ## run docker compose with dev image
	@$(RUN_COMMAND) docker_compose_up

.PHONY: compose-down
compose-down: deps scripts/ci/docker-compose-ci.yaml ## stop docker-compose
	@$(RUN_COMMAND) docker_compose_down

.PHONY: cluster-up
cluster-up: deps test/e2e/kind-config.yaml ## setup kind testing cluster
	@$(RUN_COMMAND) kind_cluster_up

.PHONY: cluster-down
cluster-down: deps ## delete kind testing cluster
	@$(RUN_COMMAND) kind_cluster_down

.PHONY: lint
lint: venv ## lint code using pylint
	@$(RUN_COMMAND) lint

.PHONY: test
test-all: test-unit test-integration test-functional test-e2e ## run all tests - unit, integration, functional, e2e

.PHONY: test-unit
test-unit: deps ## run unit tests using tox
	@$(RUN_COMMAND) unit_tests

.PHONY: test-integration
test-integration: deps ## run integration tests using tox
	@$(RUN_COMMAND) integration_tests

.PHONY: test-functional
test-functional: compose-up ## run functional tests using tox
	@$(RUN_COMMAND) functional_tests
	@$(MAKE) compose-down

.PHONY: test-e2e
test-e2e: cluster-up ## run e2e tests using kind/helm
	@$(RUN_COMMAND) e2e_tests
	@$(MAKE) cluster-down

.PHONY: clean-all
clean-all: clean clean-tests clean-container ## run all clean jobs - clean, clean-tests, clean-container

.PHONY: clean
clean: ## delete all build directories, pycache & virtualenv
	@$(RUN_COMMAND) clean_python_env

.PHONY: clean-tests
clean-tests: ## delete temporary test directories
	@$(RUN_COMMAND) clean_tests

.PHONY: clean-container
clean-container: ## delete dev image
	@$(RUN_COMMAND) clean_container

.PHONY: setup-dev
setup-dev: setup-pyenv deps install-dev ## setup dev environment - install pyenv, python, deps, project
	@printf "\n\tEnable virtualenv by running:\n\t\tsource $(VENV_ACTIVATE)\n"

.PHONY: setup-pyenv
setup-pyenv: | .python-version ## install pyenv, python and set local .python_version
.python-version: | $(HOME)/.pyenv/versions/$(PYTHON_VERSION)/bin/python
	@$(RUN_COMMAND) set_pyenv_local_version
$(HOME)/.pyenv/versions/$(PYTHON_VERSION)/bin/python: | $(HOME)/.pyenv/bin/pyenv
	@$(RUN_COMMAND) install_python_version
$(HOME)/.pyenv/bin/pyenv:
	@$(RUN_COMMAND) install_pyenv

.PHONY: printvars
printvars: ## print configured make environment vars
	@$(foreach V,$(sort $(.VARIABLES)),$(if $(filter-out environment% default automatic,$(origin $V)),$(warning $V=$($V) ($(value $V)))))

.PHONY: help
help:
	@$(RUN_COMMAND) help
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\t\033[0;36m%-30s\033[0m %s\n", $$1, $$2}'
