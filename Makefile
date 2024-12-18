registry ?= registry.example.net
arch ?= linux/amd64
project_path ?= /
container_tag ?= auto-update-0.0.21

docker-build:
	@docker login ${registry}
	@docker build --platform ${arch} \
								-t  ${registry}${project_path}:${container_tag} .
	@docker push  ${registry}${project_path}:${container_tag}
