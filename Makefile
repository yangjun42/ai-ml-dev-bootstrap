.PHONY: mac-minimal mac-core mac-developer mac-workstation mac-restricted mac-personal mac-enterprise mac-config-minimal mac-config-developer verify verify-macos verify-project docker-cpu docker-gpu

mac-minimal:
	./scripts/bootstrap-macos.sh --profile minimal

mac-core: mac-minimal

mac-developer:
	./scripts/bootstrap-macos.sh --profile developer

mac-workstation:
	./scripts/bootstrap-macos.sh --profile workstation

mac-restricted:
	./scripts/bootstrap-macos.sh --profile restricted

# Apply only managed Ghostty/zsh configuration, without Homebrew installs.
mac-config-minimal:
	./scripts/configure-macos-shell.sh --profile minimal

mac-config-developer:
	./scripts/configure-macos-shell.sh --profile developer

# Backward-compatible aliases.
mac-personal: mac-minimal
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
