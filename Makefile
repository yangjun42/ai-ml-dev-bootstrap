.PHONY: mac-core mac-enterprise mac-ml mac-containers mac-all mac-config verify verify-macos verify-project docker-cpu docker-gpu

mac-core:
	./scripts/bootstrap-macos.sh

mac-enterprise:
	./scripts/bootstrap-macos.sh --profile enterprise

mac-ml:
	./scripts/bootstrap-macos.sh --features ml

mac-containers:
	./scripts/bootstrap-macos.sh --features containers

mac-all:
	./scripts/bootstrap-macos.sh --features all

# Apply only managed Ghostty/zsh/Starship configuration.
mac-config:
	bash ./scripts/configure-macos-shell.sh --profile core

verify: verify-macos

verify-macos:
	bash ./scripts/verify-macos-bootstrap.sh

verify-project:
	./scripts/verify.sh

docker-cpu:
	docker build -f containers/Dockerfile.cpu -t ai-ml-dev:cpu .

docker-gpu:
	docker build -f containers/Dockerfile.gpu-wheel -t ai-ml-dev:gpu .
