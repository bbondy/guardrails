BINARY = guardrails

.PHONY: build
build:
	cargo build --release

.PHONY: darwin-arm64
darwin-arm64:
	$(call docker-build-target,$@,aarch64-apple-darwin)

.PHONY: darwin-amd64
darwin-amd64:
	$(call docker-build-target,$@,x86_64-apple-darwin)

.PHONY: linux-amd64
linux-amd64:
	$(call docker-build-target,$@,x86_64-unknown-linux-gnu)

.PHONY: linux-arm64
linux-arm64:
	$(call docker-build-target,$@,aarch64-unknown-linux-gnu)

.PHONY: windows-amd64
windows-amd64:
	$(call docker-build-target,$@,x86_64-pc-windows-gnu)

.PHONY: windows-arm64
windows-arm64:
	$(call docker-build-target,$@,aarch64-pc-windows-gnullvm)

.PHONY: all-platforms
all-platforms: darwin-arm64 darwin-amd64 linux-amd64 linux-arm64 windows-amd64 windows-arm64

.PHONY: clean
clean:
	cargo clean
	rm -rf dist

define docker-build-target
	docker build -f Dockerfile.darwin -t $(BINARY)-$(1) \
	  --build-arg TARGET=$(2) .
	$(call docker-extract,$(BINARY)-$(1),$(1))
endef

define docker-extract
	mkdir -p dist
	docker rm -f tmp-$(BINARY) 2>/dev/null || true
	docker create --name tmp-$(BINARY) $(1) /dev/null
	docker cp tmp-$(BINARY):/$(BINARY) dist/$(call artifact-name,$(2))
	docker rm tmp-$(BINARY)
endef

define artifact-name
$(BINARY)-$(1)$(if $(findstring windows,$(1)),.exe,)
endef
