DOCKER_IMAGE_NAME       ?= jcopi/process-exporter

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



.PHONY: all format test vet build integ
