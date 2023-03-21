VGO=go
GOFILES := $(shell find cmd internal -name '*.go' -print)
GOBIN := $(shell $(VGO) env GOPATH)/bin
LINT := $(GOBIN)/golangci-lint
MOCKERY := $(GOBIN)/mockery

.DELETE_ON_ERROR:

all: build test go-mod-tidy
test: deps
		$(VGO) test ./internal/... ./cmd/... -cover -coverprofile=coverage.txt -covermode=atomic -timeout=30s
coverage.html:
		$(VGO) tool cover -html=coverage.txt
coverage: test coverage.html
lint: ${LINT}
		$(LINT) run -v --timeout 5m
${MOCKERY}:
		$(VGO) install github.com/vektra/mockery/v2@v2.23.0
${LINT}:
		$(VGO) install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.47.3
mockpaths:
		$(eval FFTM_PATH := $(shell $(VGO) list -f '{{.Dir}}' github.com/hyperledger/firefly-transaction-manager/pkg/fftm))
		$(eval FF_SIGNER_PATH := $(shell $(VGO) list -f '{{.Dir}}' github.com/hyperledger/firefly-signer/pkg/rpcbackend))

define makemock
mocks: mocks-$(strip $(1))-$(strip $(2))
mocks-$(strip $(1))-$(strip $(2)): ${MOCKERY} mockpaths
	${MOCKERY} --case underscore --dir $(1) --name $(2) --outpkg $(3) --output mocks/$(strip $(3))
endef

$(eval $(call makemock, $$(FF_SIGNER_PATH), Backend, rpcbackendmocks))
$(eval $(call makemock, $$(FFTM_PATH), Manager, fftmmocks))

firefly-tezosconnect: ${GOFILES}
		$(VGO) build -o ./firefly-tezosconnect -ldflags "-X main.buildDate=`date -u +\"%Y-%m-%dT%H:%M:%SZ\"` -X main.buildVersion=$(BUILD_VERSION)" -tags=prod -v ./tezosconnect
go-mod-tidy: .ALWAYS
		$(VGO) mod tidy
build: firefly-tezosconnect
.ALWAYS: ;
clean:
		$(VGO) clean
deps:
		$(VGO) get ./tezosconnect
reference:
		$(VGO) test ./cmd -timeout=10s -tags docs
docker:
		docker build --build-arg BUILD_VERSION=${BUILD_VERSION} ${DOCKER_ARGS} -t oneof/firefly-tezosconnect .