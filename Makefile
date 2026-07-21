BUILD_DIR=build
APPS=front-end newsfeed quotes
STATIC_BASE=front-end/api/static
STATIC_PATHS=css
STATIC_ARCHIVE=$(BUILD_DIR)/static.tgz
DOCKER_TARGETS=$(addsuffix .docker, $(APPS))
DOCKER_PUSH_TARGETS=$(addsuffix .push, $(APPS))
_DOCKER_PUSH_TARGETS=$(addprefix _, $(DOCKER_PUSH_TARGETS))
ACR_URL_FILE=infra/acr-url.txt
SSH_KEY=infra/id_rsa
PREFIX=$$(cat interview_id.txt)
RESOURCE_GROUP_NAME=news$(PREFIX)_rg_joi_interview
STORAGE_ACCOUNT_NAME=news$(PREFIX)sajoiinterview
CONTAINER_NAME=news$(PREFIX)terraformcontainerjoiinterview

az_login:
	az login

az_account:	
	az group create --name $(RESOURCE_GROUP_NAME) --location eastus	
	az storage account create --resource-group $(RESOURCE_GROUP_NAME) --name $(STORAGE_ACCOUNT_NAME) --sku Standard_LRS --encryption-services blob	
	az storage container create --name $(CONTAINER_NAME) --account-name $(STORAGE_ACCOUNT_NAME)

delete_az_account:
	az group delete --resource-group $(RESOURCE_GROUP_NAME) -y

static: $(STATIC_ARCHIVE)

test: $(addprefix _, $(addsuffix .test, $(APPS)))

clean:
	rm -rf $(BUILD_DIR)

$(STATIC_ARCHIVE): | $(BUILD_DIR)
	tar -c -C $(STATIC_BASE) -z -f $(STATIC_ARCHIVE) $(STATIC_PATHS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

%.docker:
	$(eval IMAGE_NAME = $(subst -,_,$*))	
	cd $* && docker buildx build --platform linux/amd64 --load -t $(IMAGE_NAME) .	

_%.push:
	$(eval IMAGE_NAME = $(subst -,_,$*))
	$(eval REPO_URL := $(shell cat ${ACR_URL_FILE}))	
	docker tag $(IMAGE_NAME) news$(PREFIX)$(subst _,,$(IMAGE_NAME))$(REPO_URL)/news$(PREFIX)$(subst _,,$(IMAGE_NAME))
	az acr login --name news$(PREFIX)$(subst _,,$(IMAGE_NAME)) 
	docker push news$(PREFIX)$(subst _,,$(IMAGE_NAME))$(REPO_URL)/news$(PREFIX)$(subst _,,$(IMAGE_NAME))

%.push:
	$(eval IMAGE_NAME = $(subst -,_,$*))
	$(eval REPO_URL := $(shell cat ${ACR_URL_FILE}))	
	docker tag $(IMAGE_NAME) news$(PREFIX)$(subst _,,$(IMAGE_NAME))$(REPO_URL)/news$(PREFIX)$(subst _,,$(IMAGE_NAME))
	az acr login --name news$(PREFIX)$(subst _,,$(IMAGE_NAME)) 
	docker push news$(PREFIX)$(subst _,,$(IMAGE_NAME))$(REPO_URL)/news$(PREFIX)$(subst _,,$(IMAGE_NAME))

docker: $(DOCKER_TARGETS)	

push: $(DOCKER_PUSH_TARGETS)

$(SSH_KEY):
	ssh-keygen -q -N "" -f $(SSH_KEY)
	chmod -c 0600 $(SSH_KEY)

ssh_key: $(SSH_KEY)

%.infra: ssh_key
	cd infra/$* && rm -rf .terraform && terraform init && terraform apply -auto-approve

%.deinfra: ssh_key
	cd infra/$* && terraform init && terraform destroy -auto-approve

deploy_site:
	cd build &&\
	mkdir -p static &&\
	cd static &&\
	tar xf ../static.tgz &&\
	rm ../static.tgz &&\
	cd ../../
	az storage blob upload-batch --destination news$(PREFIX)psc --account-name news$(PREFIX)psa --source build	

deploy_interview:
	$(MAKE) az_login
	$(MAKE) az_account
	$(MAKE) clean	
	$(MAKE) backend-support.infra
	$(MAKE) base.infra
	$(MAKE) docker
	$(MAKE) push
	$(MAKE) static
	$(MAKE) deploy_site	
	$(MAKE) news.infra	

destroy_interview:
	$(MAKE) news.deinfra
	$(MAKE) base.deinfra
	$(MAKE) backend-support.deinfra
	$(MAKE) delete_az_account
