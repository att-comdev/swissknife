IMAGE_NAME      := swissknife
IMAGE_PREFIX               ?= att-comdev 
IMAGE_TAG                  ?= untagged
LABEL                      ?= commit-id

DOCKER_REGISTRY            ?= quay.io
PUSH_IMAGE                 ?= false

PROXY                      ?= http://proxy.foo.com:8000
NO_PROXY                   ?= localhost,127.0.0.1,.svc.cluster.local
USE_PROXY                  ?= false

IMAGE:=${DOCKER_REGISTRY}/${IMAGE_PREFIX}/$(IMAGE_NAME):${IMAGE_TAG}
IMAGE_DIR:=$(IMAGE_PREFIX)-$(IMAGE_NAME)

.PHONY: images

#Build all images in the list
images: $(IMAGE_NAME)

$(IMAGE_NAME):
	@echo
	@echo "===== Processing [$@] image ====="
	@make build_$@ IMAGE=${DOCKER_REGISTRY}/${IMAGE_PREFIX}/$@:${IMAGE_TAG} IMAGE_DIR=${IMAGE_PREFIX}-$@

.PHONY: build_swissknife
build_swissknife:
	docker build --network host -t $(IMAGE) --label $(LABEL) -f nc-swissknife/Dockerfile .
