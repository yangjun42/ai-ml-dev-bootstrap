.PHONY: mac-core mac-restricted mac-ai mac-conda mac-mlsys mac-build mac-containers mac-all mac-config mac-minimal mac-developer mac-workstation mac-personal mac-enterprise verify verify-macos verify-project docker-cpu docker-gpu

mac-core:
	./scripts/bootstrap-macos.sh

mac-restricted:
	./scripts/bootstrap-macos.sh --profile restricted

mac-ai:
	./scripts/bootstrap-macos.sh --features ai

mac-conda:
	./scripts/bootstrap-macos.sh --features conda

mac-mlsys:
	./scripts/bootstrap-macos.sh --features mlsys

mac-build:
	./scripts/bootstrap-macos.sh --features build

mac-containers:
	./scripts/bootstrap-macos.sh --features containers

mac-all:
	./scripts/bootstrap-macos.sh --features all

# Apply only managed Ghostty/zsh/Starship configuration.
mac-config:
	bash ./scripts/configure-macos-shell.sh --profile core

# Backward-compatible aliases from the previous profile design.
mac-minimal mac-developer mac-personal: mac-core

mac-workstation:
	./scripts/bootstrap-macos.sh --features build,containers

mac-enterprise: mac-restricted

verify: verify-macos

verify-macos:
	bash ./scripts/verify-macos-bootstrap.sh

verify-project:
	./scripts/verify.sh

docker-cpu:
	docker build -f containers/Dockerfile.cpu -t ai-ml-dev:cpu .

docker-gpu:
	docker build -f containers/Dockerfile.gpu-wheel -t ai-ml-dev:gpu .
