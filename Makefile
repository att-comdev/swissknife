.DEFAULT_GOAL              := help
PROJ_DIR                   := $(shell pwd)

.PHONY: help
help:
	@echo "Here are the make targets for $(shell basename ${PROJ_DIR})."
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: code-review
code-review: install-dependencies ## The standard CI interface for code review. Which includes linting, testing, and documents
	tox

.PHONY: install-dependencies
install-dependencies: ## Install none pip based software requirements for the project. (Requires to run as root to do any new installs)
	${PROJ_DIR}/install-apt-packages.sh ${PROJ_DIR}/apt-dependencies.txt
	pip3 install tox
