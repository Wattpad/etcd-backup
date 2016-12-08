.PHONY: build push run test

REPO=wattpad/etcd
ETCD_VERSION=2.3.7

BUILD_VERSION=build-$(shell git rev-parse --short HEAD)
ALPINE_VERSION=alpine-$(shell grep '^FROM alpine' Dockerfile  | cut -d ':' -f 2)

ifndef TAG
	TAG := $(ETCD_VERSION)_$(ALPINE_VERSION)_$(BUILD_VERSION)
endif

IMAGE=$(REPO):$(TAG)

build:
	docker build -t $(IMAGE) --build-arg ETCD_VERSION=$(ETCD_VERSION) .
	docker tag $(IMAGE) $(REPO):latest

push: build
	docker push $(IMAGE)

test: build
	cd test && ETCD_VERSION=$(ETCD_VERSION) ./test.sh
