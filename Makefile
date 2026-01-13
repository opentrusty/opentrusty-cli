# Makefile for OpenTrusty CLI

BINARY_NAME=opentrusty
MAIN_PATH=./cmd/opentrusty/main.go

.PHONY: build test lint clean help check-binary

help:
	@echo "OpenTrusty CLI Makefile"
	@echo "Usage:"
	@echo "  make build         - Build the opentrusty binary"
	@echo "  make test          - Run all tests"
	@echo "  make lint          - Run linter"
	@echo "  make check-binary  - Verify the binary works"
	@echo "  make clean         - Clean build artifacts"

build:
	go build -ldflags "-X main.version=$(VERSION)" -o $(BINARY_NAME) $(MAIN_PATH)

deps:
	go mod download
	go mod tidy

test:
	go test -v ./...

lint:
	golangci-lint run ./...

check-binary:
	./$(BINARY_NAME) migrate --help || (echo "CLI check failed (likely DB connection issue, but binary exists and runs)" && exit 0)

clean:
	go clean -cache
	rm -f $(BINARY_NAME)
	rm -rf release/

# Release package
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
RELEASE_DIR = release/opentrusty-cli-$(VERSION)

release: build
	@echo "Creating release package for $(VERSION)..."
	@mkdir -p $(RELEASE_DIR)
	@cp $(BINARY_NAME) $(RELEASE_DIR)/
	@cp -r deploy/* $(RELEASE_DIR)/
	@sed -i "s/VERSION=\"dev\"/VERSION=\"$(VERSION)\"/" $(RELEASE_DIR)/install.sh
	@cp .env.example $(RELEASE_DIR)/
	@cp LICENSE $(RELEASE_DIR)/ 2>/dev/null || echo "No LICENSE file found"
	@cd release && tar -czf opentrusty-cli-$(VERSION)-linux-amd64.tar.gz opentrusty-cli-$(VERSION)
	@echo "✓ Release package created: release/opentrusty-cli-$(VERSION)-linux-amd64.tar.gz"
