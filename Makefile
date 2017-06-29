ECR_REPOSITORY_URL = 159802860893.dkr.ecr.eu-west-1.amazonaws.com
IMAGE_NAME?=$(ECR_REPOSITORY_URL)/redpineapplemedia/repository-app-delivery
ANSIBLE_IMAGE_REPOSITORY = $(ECR_REPOSITORY_URL)/redpineapplemedia/repository-ansible
CONTAINER_NAME?=container-app-delivery

.PHONY: help build clean build-service test compose-down compose-up login push deploy build-smojure

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

build-golive:	## Build a Docker image from the current directory with golive environment
	@docker build \
		--rm \
		-t $(IMAGE_NAME):golive \
		--build-arg SMOJURE_ENV=golive \
		./

push: TAG_NAME=latest
push: login	## Push image to the docker registry. Usually done by Jenkins Pipeline. Example: make push-delivery TAG_NAME=latest | make push-delivery TAG_NAME=golive
	@docker push $(IMAGE_NAME):$(TAG_NAME)

clean: compose-down	    ## Remove containers and images related to the project.
	-@docker rm -f $(CONTAINER_NAME)
	-@docker rmi -f $(IMAGE_NAME)

test: login	    ## Run tests on a new instance of the service.
	@docker-compose -f docker-compose.test.yml down
	@docker-compose -f docker-compose.test.yml \
		run delivery forego run -e .env.test lein test
	@docker-compose -f docker-compose.test.yml down

test-golive: login	    ## Run tests with golive images. To be removed after we put this version of the Delivery code on production
	@docker-compose -f docker-compose.test.yml -f docker-compose.golive.yml down
	@docker-compose -f docker-compose.test.yml -f docker-compose.golive.yml \
		run delivery forego run -e .env.golive lein test
	@docker-compose -f docker-compose.test.yml -f docker-compose.golive.yml down

compose-down:       ## Bring down the running service
	@docker-compose \
		-f docker-compose.yml \
		down --remove-orphans

compose-up: compose-down login      ## Same of 'make login' and runs the compose file. It doesn't release the console.
	@docker-compose \
		-f docker-compose.yml \
		up -d

build-smojure: ## Build smojure for development
	@docker-compose exec -T delivery bash -c 'cd smoke/; boot development build'

start-smojure-dev:	## Start the smojure server for real-time development
	@docker-compose exec delivery bash -c 'cd smoke/; boot dev'

end2end: login	## Run tests
	@docker-compose -f docker-compose.end2end.yml down  --remove-orphans
	@docker-compose -f docker-compose.end2end.yml up -d
	@docker-compose -f docker-compose.end2end.yml exec -T cms ./scripts/grunt-end2end.sh
	@./scripts/run-end2end-tests.sh
	@docker-compose -f docker-compose.end2end.yml down --remove-orphans

end2end-golive: login 	## Run tests
	@docker-compose -f docker-compose.end2end.yml -f docker-compose.golive.yml down --remove-orphans
	@docker-compose -f docker-compose.end2end.yml -f docker-compose.golive.yml up -d
	@docker-compose -f docker-compose.end2end.yml -f docker-compose.golive.yml exec -T cms ./scripts/grunt-end2end.sh
	@./scripts/run-end2end-golive-tests.sh
	@docker-compose -f docker-compose.end2end.yml -f docker-compose.golive.yml down --remove-orphans

deploy: login	## Deploy application to ECS with the given environment. This is usually executed by Jenkins pipeline. Example: make deploy environment=[prd|golive]
	@docker pull $(ANSIBLE_IMAGE_REPOSITORY)
	@docker run -v $(HOME)/.ssh/id_rsa:/root/.ssh/id_rsa \
		-v $(PWD):/root/playbooks \
		-v $(HOME)/.aws:/root/.aws \
    -w /root/playbooks \
    $(ANSIBLE_IMAGE_REPOSITORY) \
    /bin/sh -c "ansible-galaxy install -fr scripts/requirements.yml && \
		ansible-playbook scripts/deploy.delivery.yml -e \"environment_name=$(environment_name) tag_name=$(tag_name)\" && \
		ansible-playbook scripts/deploy.tracking.yml -e \"environment_name=$(environment_name) tag_name=$(tag_name)\" && \
		ansible-playbook scripts/deploy.openrtb.yml -e \"environment_name=$(environment_name) tag_name=$(tag_name)\""

deploy-golive: login	## Deploy application to ECS with the given environment. This is usually executed by Jenkins pipeline. Example: make deploy environment=[prd|golive]
	@docker pull $(ANSIBLE_IMAGE_REPOSITORY)
	@docker run -v $(HOME)/.ssh/id_rsa:/root/.ssh/id_rsa \
		-v $(PWD):/root/playbooks \
		-v $(HOME)/.aws:/root/.aws \
    -w /root/playbooks \
    $(ANSIBLE_IMAGE_REPOSITORY) \
    /bin/sh -c "ansible-galaxy install -fr scripts/requirements.yml && \
		ansible-playbook scripts/deploy.delivery-golive.yml -e \"environment_name=$(environment_name) tag_name=$(tag_name)\" && \
		ansible-playbook scripts/deploy.tracking-golive.yml -e \"environment_name=$(environment_name) tag_name=$(tag_name)\" && \
		ansible-playbook scripts/deploy.openrtb-golive.yml -e \"environment_name=$(environment_name) tag_name=$(tag_name)\""
