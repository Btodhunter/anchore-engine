# Project Specific configuration
DEV_IMAGE_REPO ?= anchore/anchore-engine-dev
PROD_IMAGE_REPO ?=
RELEASE_BRANCHES ?=
LATEST_RELEASE_BRANCH ?=
ANCHORE_CLI_VERSION ?=
DOCKER_USER ?=
DOCKER_PASS ?=
# Set VERBOSE=1 or VERBOSE=true to display stdout. Set VERBOSE=2 for command details & stdout
VERBOSE ?= false
# Set CI=true when running in CircleCI. This setting will setup the proper env for CircleCI
# All 'production' image push jobs to Dockerhub are gated on CI=true
CI ?= false
# Set SKIP_CLEANUP=true to prevent all error/exit cleanup scripts from running
SKIP_CLEANUP ?= false
# Use $CIRCLE_SHA or use SHA from HEAD
COMMIT_SHA ?= $(shell echo $${CIRCLE_SHA:=$$(git rev-parse HEAD)})
# Use $CIRCLE_PROJECT_REPONAME or the git project top level dir name
GIT_REPO ?= $(shell echo $${CIRCLE_PROJECT_REPONAME:=$$(basename `git rev-parse --show-toplevel`)})
# Use $CIRCLE_BRANCH or use current HEAD branch
GIT_BRANCH ?= $(shell echo $${CIRCLE_BRANCH:=$$(git rev-parse --abbrev-ref HEAD)})
# Get commit SHA of the latest anchore-cli tag
CLI_COMMIT_SHA ?= $(shell echo $$(git ls-remote git@github.com:anchore/anchore-cli.git --sort="version:refname" --tags v\* | tail -n1 | awk '{print $$1}'))

# testing environment configuration
TEST_IMAGE_NAME = $(GIT_REPO):dev
KIND_VERSION := v0.7.0
KIND_NODE_IMAGE_TAG := v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
KUBECTL_VERSION := v1.15.0
HELM_VERSION := v3.1.1

# Make environment configuration
RUN_COMMAND := scripts/ci/run_command
ENV := /usr/bin/env
VENV_NAME := venv
VENV_ACTIVATE = $(VENV_NAME)/bin/activate
PYTHON = $(VENV_NAME)/bin/python3
PYTHON_VERSION := 3.6.6
.DEFAULT_GOAL := help # Running `Make` will run the help target
.NOTPARALLEL: # wait for targets to finish
.EXPORT_ALL_VARIABLES: # send all vars to shell

# Setup shell colors for print/echo statements -- ${OK}=green, ${WARN}=yellow, ${INFO}=cyan, ${ERR}=red, ${NC}=normal
OK := \033[0;32m
WARN := \033[0;33m
INFO := \033[0;36m
ERR := \033[0;31m
NC := \033[0m

# Define available make commands - use ## on target names to create 'help' text
.PHONY: build
build: Dockerfile ## build image
	@VERBOSE=$${VERBOSE:=1} $(RUN_COMMAND) build "Building image"
	@printf "%s\n\tSuccessfully built image: $(INFO)$(TEST_IMAGE_NAME)$(NC)\n\n"

.PHONY: push
push: ## push image to dockerhub
	@VERBOSE=$${VERBOSE:=1} $(RUN_COMMAND) push_dev_image "Pushing $(IMAGE_NAME) to Dockerhub"

.PHONY: push-rc
push-rc: ## push RC image to dockerhub
	@VERBOSE=$${VERBOSE:=1} $(RUN_COMMAND) push_rc_image "Pushing $(IMAGE_NAME) to Dockerhub"

.PHONY: push-prod
push-prod: ## push production image to dockerhub
	@VERBOSE=$${VERBOSE:=1} $(RUN_COMMAND) push_prod_image "Pushing $(IMAGE_NAME) to Dockerhub"

.PHONY: venv
venv: $(VENV_ACTIVATE) ## setup virtual environment
$(VENV_ACTIVATE):
	@$(RUN_COMMAND) setup_venv "Creating virtualenv at $(VENV_NAME)"

.PHONY: install
install: venv setup.py requirements.txt ## install to venv in dev mode
	@$(RUN_COMMAND) install_dev "Installing $(GIT_REPO) to $(VENV_NAME)"

.PHONY: deps
deps: venv ## install testing dependencies
	@$(RUN_COMMAND) install_test_deps "Installing testing dependencies to $(VENV_NAME)"

.PHONY: compose-up
compose-up: deps scripts/ci/docker-compose-ci.yaml ## run image with docker compose
	@$(RUN_COMMAND) docker_compose_up_ci "Starting Docker Compose"
	@printf "%s\n\t$(INFO)To stop running use:\n\t\t$(WARN)make compose-down${NC}\n\n"

.PHONY: compose-down
compose-down: deps scripts/ci/docker-compose-ci.yaml ## Bring down docker-compose
	@$(RUN_COMMAND) docker_compose_down_ci "Stopping Docker Compose"

.PHONY: cluster-up
cluster-up: deps ## setup testing cluster using kind
	@$(RUN_COMMAND) e2e_test_setup "Setup e2e testing cluster"
	@$(RUN_COMMAND) e2e_test_install_deps "Install e2e testing dependencies"

.PHONY: cluster-down
cluster-down: deps
	@$(RUN_COMMAND) e2e_test_teardown "Delete testing cluster"

.PHONY: lint
lint: venv ## lint code with pylint
	@$(RUN_COMMAND) lint "Linting $(GIT_REPO)"

.PHONY: test
test-all: test-unit test-integration test-functional test-e2e ## run all tests - unit, integration, functional, e2e

.PHONY: test-unit
test-unit: deps ## run unit tests with tox
	@VERBOSE=$${VERBOSE:=1} $(RUN_COMMAND) unit_tests "Run unit tests with tox"

.PHONY: test-integration
test-integration: deps ## run integration tests with tox
	@VERBOSE=$${VERBOSE:=1} $(RUN_COMMAND) integration_tests "Run integration tests with tox"

.PHONY: test-functional
test-functional: compose-up ## run functional tests with tox
	@VERBOSE=$${VERBOSE:=1} $(RUN_COMMAND) functional_tests "Run functional tests with tox"
	@$(MAKE) compose-down

.PHONY: test-e2e
test-e2e: cluster-up ## run e2e tests using kind/helm
	@VERBOSE=$${VERBOSE:=1} $(RUN_COMMAND) e2e_tests "Run e2e tests using testing cluster & helm chart"
	@$(MAKE) cluster-down

.PHONY: clean-all
clean-all: clean clean-tests clean-container ## clean all build/test artifacts

.PHONY: clean
clean: ## delete all build directories, pycache & virtualenv
	@$(RUN_COMMAND) clean_python_env "Clean up python environment"

.PHONY: clean-tests
clean-tests: ## delete temporary test directories
	@$(RUN_COMMAND) clean_tests "Clean up temporary testing files"

.PHONY: clean-container
clean-container: ## delete built image
	@$(RUN_COMMAND) clean_container "Delete the $(TEST_IMAGE_NAME) container"

.PHONY: setup-dev
setup-dev: setup-pyenv deps install ## Setup dev environment from scratch
	@printf "%s\n\t$(INFO)Enable virtualenv by running:\n\t\t$(WARN)source $(VENV_ACTIVATE)$(NC)\n\n"

.PHONY: setup-pyenv
setup-pyenv: | .python-version ## install pyenv, python and set local .python_version
.python-version: | $(HOME)/.pyenv/versions/$(PYTHON_VERSION)/bin/python
	@$(RUN_COMMAND) set_pyenv_local_version "Set pyenv local Python version to $(PYTHON_VERSION)"
$(HOME)/.pyenv/versions/$(PYTHON_VERSION)/bin/python: | $(HOME)/.pyenv
	@$(RUN_COMMAND) install_python_version "Installing python $(PYTHON_VERSION) with pyenv"
$(HOME)/.pyenv:
	@$(RUN_COMMAND) install_pyenv "Installing pyenv"
	@printf "%s\n\t$(INFO)To enable pyenv in your current shell run:\n\t\t$(WARN)exec $(SHELL)$(NC)\n\n"

.PHONY: printvars
printvars: ## print make env vars
	@$(foreach V,$(sort $(.VARIABLES)),$(if $(filter-out environment% default automatic,$(origin $V)),$(warning $V=$($V) ($(value $V)))))

.PHONY: help
help: ## show help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(INFO)%-30s$(NC) %s\n", $$1, $$2}'
