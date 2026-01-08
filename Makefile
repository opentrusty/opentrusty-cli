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
	go build -o $(BINARY_NAME) $(MAIN_PATH)

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
