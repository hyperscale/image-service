.PHONY: all clean deps fmt vet test docker

EXECUTABLE ?= hyperpic
IMAGE ?= hyperscale/$(EXECUTABLE)
IMAGE_TEST ?= $(IMAGE)-test
IMAGE_DEV ?= $(IMAGE)-dev
VERSION ?= $(shell git describe --match 'v[0-9]*' --dirty='-dev' --always)
COMMIT ?= $(shell git rev-parse --short HEAD)

LDFLAGS = -X "main.Revision=$(COMMIT)" -X "main.Version=$(VERSION)"
PACKAGES = $(shell go list ./... | grep -v /vendor/)

release:
	@echo "Release v$(version)"
	@git pull
	@git checkout master
	@git pull
	@git checkout develop
	@git flow release start $(version)
	@echo "$(version)" > .version
	@git add .version
	@git commit -m "feat(project): update version file" .version
	@git flow release finish $(version) -p -m "Release v$(version)"
	@git checkout develop
	@echo "Release v$(version) finished."

all: deps build test

clean:
	@go clean -i ./...

deps:
	@glide install

fmt:
	@go fmt $(PACKAGES)

vet:
	@go vet $(PACKAGES)

test:
	@for PKG in $(PACKAGES); do go test -ldflags '-s -w $(LDFLAGS)' -cover -coverprofile $$GOPATH/src/$$PKG/coverage.out $$PKG || exit 1; done;

travis:
	@for PKG in $(PACKAGES); do go test -ldflags '-s -w $(LDFLAGS)' -cover -covermode=count -coverprofile $$GOPATH/src/$$PKG/coverage.out $$PKG || exit 1; done;

cover: test
	@echo ""
	@for PKG in $(PACKAGES); do go tool cover -func $$GOPATH/src/$$PKG/coverage.out; echo ""; done;

docker:
	@sudo docker build --no-cache=true --rm -t $(IMAGE) .

dev-test-docker:
	@sudo docker build -f Dockerfile.test --rm -t $(IMAGE_TEST) .

dev-run-docker:
	@sudo docker build -f Dockerfile.dev --rm -t $(IMAGE_DEV) .

publish: docker
	@sudo docker tag $(IMAGE) $(IMAGE):latest
	@sudo docker push $(IMAGE)

bindata.go: docs/index.html docs/swagger.yaml
	@echo "Bin data..."
	@go-bindata docs/

$(EXECUTABLE): $(wildcard *.go)
	@echo "Building $(EXECUTABLE)..."
	@CGO_ENABLED=1 go build -ldflags '-s -w $(LDFLAGS)'

build: $(EXECUTABLE)

run: docker
	@sudo docker run -e "HYPERPIC_AUTH_SECRET=c8da8ded-f9a2-429c-8811-9b2a07de8ede" -p 8574:8080 -v $(shell pwd)/var/lib/hyperpic:/var/lib/hyperpic --rm $(IMAGE)

dev: $(EXECUTABLE)
	@./$(EXECUTABLE)

dev-test: dev-test-docker
	@sudo docker run --rm $(IMAGE_TEST)

dev-run: dev-run-docker
	@sudo docker run --rm $(IMAGE_DEV)
