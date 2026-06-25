.PHONY: mac-personal mac-enterprise verify docker-cpu docker-gpu

mac-personal:
	./scripts/bootstrap-macos.sh --profile personal

mac-enterprise:
	./scripts/bootstrap-macos.sh --profile enterprise

verify:
	./scripts/verify.sh

docker-cpu:
	docker build -f containers/Dockerfile.cpu -t ai-ml-dev:cpu .

docker-gpu:
	docker build -f containers/Dockerfile.gpu-wheel -t ai-ml-dev:gpu .
