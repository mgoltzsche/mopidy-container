PLATFORM ?= linux/amd64

MOPIDY_BUILD_OPTS = -t mgoltzsche/mopidy:dev

BUILDX_BUILDER ?= mopidy-builder
BUILDX_OUTPUT ?= type=docker
BUILDX_OPTS ?= --builder=$(BUILDX_BUILDER) --output=$(BUILDX_OUTPUT) --platform=$(PLATFORM)
DOCKER ?= docker
DOCKER_COMPOSE ?= docker-compose

all: mopidy

mopidy: create-builder
	$(DOCKER) buildx build -f Dockerfile $(BUILDX_OPTS) --force-rm $(MOPIDY_BUILD_OPTS) .

create-builder:
	$(DOCKER) buildx inspect $(BUILDX_BUILDER) >/dev/null 2<&1 || $(DOCKER) buildx create --name=$(BUILDX_BUILDER) >/dev/null

delete-builder:
	$(DOCKER) buildx rm $(BUILDX_BUILDER)

compose-up:
	$(DOCKER_COMPOSE) up -d

compose-down:
	$(DOCKER_COMPOSE) down -v --remove-orphans

compose-stop:
	$(DOCKER_COMPOSE) stop

compose-rm:
	$(DOCKER_COMPOSE) rm -sf
