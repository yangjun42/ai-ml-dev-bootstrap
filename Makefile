.PHONY: mac-core mac-ai mac-mlsys mac-containers mac-all mac-config verify verify-macos verify-project docker-cpu docker-gpu

mac-core:
	./scripts/bootstrap-macos.sh

mac-ai:
	./scripts/bootstrap-macos.sh --features ai

mac-mlsys:
	./scripts/bootstrap-macos.sh --features mlsys

mac-containers:
	./scripts/bootstrap-macos.sh --features containers

mac-all:
	./scripts/bootstrap-macos.sh --features all

# Apply only managed Ghostty/zsh/Starship configuration.
mac-config:
	bash ./scripts/configure-macos-shell.sh

verify: verify-macos

verify-macos:
	bash ./scripts/verify-macos-bootstrap.sh

verify-project:
	./scripts/verify.sh

docker-cpu:
	docker build -f containers/Dockerfile.cpu -t ai-ml-dev:cpu .

docker-gpu:
	docker build -f containers/Dockerfile.gpu-wheel -t ai-ml-dev:gpu .
