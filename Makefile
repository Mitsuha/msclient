PROTOC_GEN_DART := $(HOME)/.pub-cache/bin/protoc-gen-dart
PROTO := proxy.proto

.PHONY: proto proxy-test flutter-test test

proto:
	protoc \
		-I protocol \
		--go_out=proxy/internal/protocol --go_opt=paths=source_relative \
		--go-grpc_out=proxy/internal/protocol --go-grpc_opt=paths=source_relative \
		--plugin=protoc-gen-dart=$(PROTOC_GEN_DART) \
		--dart_out=grpc:lib/generated/protocol \
		$(PROTO)

proxy-test:
	cd proxy && go test ./...

flutter-test:
	flutter test

test: proxy-test flutter-test
