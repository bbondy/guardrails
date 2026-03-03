BINARY = guardrails

.PHONY: build
build:
	cargo build --release

.PHONY: darwin-arm64
darwin-arm64:
	docker build -f Dockerfile.darwin -t $(BINARY)-$@ \
	  --build-arg TARGET=aarch64-apple-darwin .
	$(call docker-extract,$(BINARY)-$@,$@)

.PHONY: clean
clean:
	cargo clean
	rm -rf dist

define docker-extract
	mkdir -p dist
	docker rm -f tmp-$(BINARY) 2>/dev/null || true
	docker create --name tmp-$(BINARY) $(1) /dev/null
	docker cp tmp-$(BINARY):/$(BINARY) dist/$(BINARY)-$(2)
	docker rm tmp-$(BINARY)
endef
