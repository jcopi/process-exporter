DOCKER_IMAGE_NAME       ?= ncabatoff/process-exporter

SOURCE_DATE_EPOCH ?= $(shell git log -1 --pretty=%ct)

BRANCH      ?= $(shell git rev-parse --abbrev-ref HEAD)
BUILDUSER   ?= "CI"
REVISION    ?= $(shell git rev-parse HEAD)
VERSION_TAG ?= $(shell git describe --always)

VERSION_LDFLAGS := \
  -X github.com/prometheus/common/version.Branch=$(BRANCH) \
  -X github.com/prometheus/common/version.BuildDate=$(SOURCE_DATE_EPOCH) \
  -X github.com/prometheus/common/version.BuildUser=$(BUILDUSER) \
  -X github.com/prometheus/common/version.Revision=$(REVISION) \
  -X main.version=$(VERSION_TAG)

SMOKE_TEST = -config.path packaging/conf/all.yaml -once-to-stdout-delay 1s |grep -q 'namedprocess_namegroup_memory_bytes{groupname="process-exporte",memtype="virtual"}'

all: format vet test build smoke

test:
	@echo ">> running short tests"
	go test -race -coverprofile=/tmp/cover.out -covermode=atomic ./...
	go tool cover -func=/tmp/cover.out

format:
	@echo ">> formatting code"
	go fmt ./...

vet:
	@echo ">> vetting code"
	go vet ./...

build:
	@echo ">> building code"
	CGO_ENABLED=0 go build -ldflags "$(VERSION_LDFLAGS)" -o process-exporter -tags netgo -trimpath -buildvcs=false ./cmd/process-exporter

smoke:
	@echo ">> smoke testing process-exporter"
	./process-exporter $(SMOKE_TEST)

integ:
	@echo ">> integration testing process-exporter"
	go build -o integration-tester cmd/integration-tester/main.go
	go build -o load-generator cmd/load-generator/main.go
	./integration-tester -write-size-bytes 65536

install:
	@echo ">> installing binary"
	cd cmd/process-exporter; CGO_ENABLED=0 go install -a -tags netgo

docker:
	@echo ">> building docker image"
	docker build -t "$(DOCKER_IMAGE_NAME):$(TAG_VERSION)" .
	docker rm configs
	docker create -v /packaging --name configs alpine:3.4 /bin/true
	docker cp packaging/conf configs:/packaging/conf
	docker run --rm --volumes-from configs "$(DOCKER_IMAGE_NAME):$(TAG_VERSION)" $(SMOKE_TEST)

dockertest:
	docker run --rm -it -v `pwd`:/go/src/github.com/ncabatoff/process-exporter golang:1.23.8  make -C /go/src/github.com/ncabatoff/process-exporter test

dockerinteg:
	docker run --rm -it -v `pwd`:/go/src/github.com/ncabatoff/process-exporter golang:1.23.8  make -C /go/src/github.com/ncabatoff/process-exporter build integ

.PHONY: update-go-deps
update-go-deps:
	@echo ">> updating Go dependencies"
	@for m in $$(go list -mod=readonly -m -f '{{ if and (not .Indirect) (not .Main)}}{{.Path}}{{end}}' all); do \
		go get $$m; \
	done
	go mod tidy

.PHONY: all style format test vet build integ docker
