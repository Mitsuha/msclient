BINARY      := mstages
BUILD_DIR   := bin
PREFIX      ?= $(HOME)/.local
INSTALL_DIR := $(PREFIX)/bin
PERSONAS    := mcodex mclaude

.PHONY: all build install uninstall test vet fmt tidy clean

all: build

build:
	@mkdir -p $(BUILD_DIR)
	go build -o $(BUILD_DIR)/$(BINARY) ./cmd/mstages

# Install the binary and create mcodex/mclaude symlinks pointing at it.
install: build
	@mkdir -p $(INSTALL_DIR)
	install -m 0755 $(BUILD_DIR)/$(BINARY) $(INSTALL_DIR)/$(BINARY)
	@for name in $(PERSONAS); do \
		ln -sf $(INSTALL_DIR)/$(BINARY) $(INSTALL_DIR)/$$name; \
		echo "linked $(INSTALL_DIR)/$$name -> $(BINARY)"; \
	done

uninstall:
	rm -f $(INSTALL_DIR)/$(BINARY)
	@for name in $(PERSONAS); do rm -f $(INSTALL_DIR)/$$name; done

test:
	NO_PROXY=127.0.0.1,localhost go test ./...

vet:
	go vet ./...

fmt:
	gofmt -w .

tidy:
	go mod tidy

clean:
	rm -rf $(BUILD_DIR)
