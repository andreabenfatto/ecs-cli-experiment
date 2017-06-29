ECR_REPOSITORY_URL = 159802860893.dkr.ecr.eu-west-1.amazonaws.com
IMAGE_NAME?=$(ECR_REPOSITORY_URL)/redpineapplemedia/repository-app-andreaecstest
CONTAINER_NAME?=container-app-andreaecstest

.PHONY: help build clean login push

help:	          ## This help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile \
	| sort \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

login:          ## Login to AWS ECR
	@$(shell aws ecr get-login --region eu-west-1)

build:	        ## Build the Docker image.
	@docker build \
	-t $(IMAGE_NAME) \
	./

run:
	@docker run \
  --name $(CONTAINER_NAME) \
  -p 3000:3000 \
  $(IMAGE_NAME)

push: TAG_NAME=latest
push: login	
	@docker push $(IMAGE_NAME):$(TAG_NAME)

clean:
	-@docker rm -f $(CONTAINER_NAME)
	-@docker rmi -f $(IMAGE_NAME)
