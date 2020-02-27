# Project Specific configuration
DEV_IMAGE_REPO ?= anchore/anchore-engine-dev
PROD_IMAGE_REPO ?= ''
RELEASE_BRANCHES ?= ''
LATEST_RELEASE_BRANCH ?= ''
ANCHORE_CLI_VERSION ?= ''
# Set VERBOSE=1 or VERBOSE=true to display stdout. Set VERBOSE=2 for command details & stdout
VERBOSE ?= 'false'
# Set CI=true when running in CircleCI. This setting will setup the proper env for CircleCI
# All 'production' image push jobs to Dockerhub are gated on CI=true
CI ?= 'false'
# Set SKIP_CLEANUP=true to prevent all error/exit cleanup scripts from running
SKIP_CLEANUP ?= 'false'
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
KIND_VERSION = v0.7.0
KIND_NODE_IMAGE_TAG = v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
KUBECTL_VERSION = v1.15.0
HELM_VERSION = v3.1.1

# Make environment configuration
ENV = /usr/bin/env
VENV_NAME = .venv
VENV_ACTIVATE = $(VENV_NAME)/bin/activate
PYTHON = $(VENV_NAME)/bin/python3
PYTHON_VERSION = 3.6.6
.DEFAULT_GOAL := help # Running `Make` will run the help target
.NOTPARALLEL: # wait for targets to finish
.EXPORT_ALL_VARIABLES: # send all vars to shell

# Setup shell colors for print/echo statements -- ${OK}=green, ${WARN}=yellow, ${INFO}=cyan, ${ERR}=red, ${NC}=normal
OK=\033[0;32m
WARN=\033[0;33m
INFO=\033[0;36m
ERR=\033[0;31m
NC=\033[0m

# Define available make commands - use ## on target names to create 'help' text
.PHONY: build
build: Dockerfile ## build image
	@scripts/ci/run_command "Building image" build
	@printf "%s\n\tSuccessfully built image: $(INFO)$(TEST_IMAGE_NAME)$(NC)\n\n"

.PHONY: push
push: ## push image to dockerhub
	@VERBOSE=$${VERBOSE:=1} scripts/ci/run_command "Pushing $(IMAGE_NAME) to Dockerhub" push_image

.PHONY: venv
venv: $(VENV_ACTIVATE) ## setup virtual environment
$(VENV_ACTIVATE):
	@scripts/ci/run_command "Creating virtualenv at $(VENV_NAME)" setup_venv
	@touch $@

.PHONY: install
install: venv setup.py requirements.txt ## install to venv in dev mode
	@scripts/ci/run_command "Installing $(GIT_REPO) to $(VENV_NAME)" install_dev

.PHONY: lint
lint: venv ## lint code with pylint
	@scripts/ci/run_command "Linting $(GIT_REPO)" lint

.PHONY: deps
deps: venv ## install testing dependencies
	@scripts/ci/run_command "Installing dependencies to $(VENV_NAME)" install_test_deps

.PHONY: compose-up
compose-up: deps scripts/ci/docker-compose-ci.yaml ## run image with docker compose
	@SKIP_CLEANUP=true scripts/ci/run_command "Starting Docker Compose" compose_up
	@printf "%s\n$(INFO)To stop running use:\n\t\t$(WARN)make compose-down${NC}\n"

.PHONY: compose-down
compose-down: deps scripts/ci/docker-compose-ci.yaml ## Bring down docker-compose
	@scripts/ci/run_command "Stopping Docker Compose" compose_down

.PHONY: test
test-all: test-unit test-integration test-functional test-compose ## run all tests - unit, integration, functional, e2e

.PHONY: test-unit
test-unit: deps ## run unit tests with tox
	@scripts/ci/run_command "Run unit tests with tox" unit_tests

.PHONY: test-integration
test-integration: deps ## run integration tests with tox
	@scripts/ci/run_command "Run integration tests with tox" integration_tests

.PHONY: test-functional
test-functional: deps compose-up ## run functional tests with tox
	@scripts/ci/run_command "Run functional tests with tox" functional_tests

.PHONY: test-e2e
test-e2e: deps ## run e2e tests with KIND & Helm
	@scripts/ci/run_command "Install e2e test dependencies" e2e_test_install_deps
	@scripts/ci/run_command "Setup e2e test infra" e2e_test_setup
	@scripts/ci/run_command "Run e2e tests with KIND/Helm" e2e_tests	

.PHONY: clean-all
clean-all: clean clean-tests clean-container ## clean all build/test artifacts

.PHONY: clean
clean: ## delete all build directories, pycache & virtualenv
	@scripts/ci/run_command "Clean up python environment" clean_python_env

.PHONY: clean-tests
clean-tests: ## delete temporary test directories
	@scripts/ci/run_command "Clean up temporary testing files" clean_tests

.PHONY: clean-container
clean-container: ## delete built image
	@scripts/ci/run_command "Delete the $(TEST_IMAGE_NAME) container" clean_container

.PHONY: dev
dev: setup-pyenv deps install ## Setup dev environment from scratch
	@printf "%s\n\t$(INFO)Enable virtualenv by running:\n\t\t$(WARN)source $(VENV_ACTIVATE)$(NC)\n\n"

.PHONY: setup-pyenv
setup-pyenv: | .python-version ## install pyenv, python and set local .python_version
.python-version: | $(HOME)/.pyenv/versions/$(PYTHON_VERSION)/bin/python
	@scripts/ci/run_command "Pyenv - set local Python to $(PYTHON_VERSION)" set_pyenv_local_version
$(HOME)/.pyenv/versions/$(PYTHON_VERSION)/bin/python: | $(HOME)/.pyenv
	@scripts/ci/run_command "Pyenv - installing python $(PYTHON_VERSION)" install_python_version
$(HOME)/.pyenv:
	@scripts/ci/run_command "Installing pyenv" install_pyenv
	@printf "%s\n\t$(INFO)To enable pyenv in your current shell run:\n\t\t$(WARN)exec $(SHELL)$(NC)\n"

.PHONY: help
help: ## show help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(INFO)%-30s$(NC) %s\n", $$1, $$2}'
