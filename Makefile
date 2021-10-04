CLUSTER_NAME=k8splayground
IMAGE=kindest/node:v1.18.2
RANCHER_CONTAINER_NAME=$(CLUSTER_NAME)-rancher
RANCHER_HOST=$$(docker inspect $(RANCHER_CONTAINER_NAME) -f '{{ json .NetworkSettings.Networks.bridge.IPAddress }}')
RANCHER_PORT=444
POSTGRES_CONTAINER_NAME=$(CLUSTER_NAME)-postgres
POSTGRES_PORT=5432

define preload_images
	cat $(1)/images | while read line ; do \
	  docker pull $$line; \
	  if ! test -z "$(PRELOAD)" ; then \
	    kind load docker-image $$line --name $(CLUSTER_NAME); \
	  fi; \
	done
endef

.PHONY: kind_create
kind_create: kind_destroy
	kind create cluster --config=kind/config.yaml --name $(CLUSTER_NAME) --image $(IMAGE)
	kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.47.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
	make etcd_cert

.PHONY: kind_destroy
kind_destroy: users_clear etcd_clear
	kind delete cluster --name $(CLUSTER_NAME)

.PHONY: apply_all
apply_all: prometheus_apply nginx_apply airflow_apply npd_apply mock_apply distributor_apply logging_apply
	@echo 'Everything applied'

.PHONY: npd_apply
npd_apply:
	$(call preload_images,apps/node-problem-detector)
	helm install node-problem-detector apps/node-problem-detector -n kube-system || helm upgrade node-problem-detector \
	apps/node-problem-detector -n kube-system

.PHONY: npd_delete
npd_delete:
	helm uninstall node-problem-detector -n kube-system

.PHONY: prometheus_apply
prometheus_apply:
	$(call preload_images,apps/kube-prometheus-stack)
	helm dependency update apps/kube-prometheus-stack
	helm install kube-prometheus-stack apps/kube-prometheus-stack || helm upgrade kube-prometheus-stack apps/kube-prometheus-stack

.PHONY: prometheus_delete
prometheus_delete:
	helm uninstall kube-prometheus-stack
	kubectl delete service kube-prometheus-stack-kubelet -n kube-system

.PHONY: prometheus_test_rules
prometheus_test_rules:
	find apps/kube-prometheus-stack/rules -type f -name '*.yaml' -not -name '*_test.yaml' -exec promtool check rules {} +
	find apps/kube-prometheus-stack/rules -type f -name '*_test.yaml' -exec promtool test rules {} +

.PHONY: mock_build
mock_build:
	docker build -t mock-server:0.0.1 apps/mock-server/server
	kind load docker-image mock-server:0.0.1 --name $(CLUSTER_NAME)

.PHONY: mock_apply
mock_apply: mock_build
	-kubectl delete deployment mock-server
	helm install mock-server apps/mock-server || helm upgrade mock-server apps/mock-server

.PHONY: mock_delete
mock_delete:
	helm uninstall mock-server

.PHONY: nginx_apply
nginx_apply:
	$(call preload_images,apps/nginx-ingress)
	helm dependency update apps/nginx-ingress
	helm install nginx-ingress apps/nginx-ingress -n kube-system || helm upgrade nginx-ingress apps/nginx-ingress -n kube-system

.PHONY: nginx_delete
nginx_delete:
	helm uninstall nginx-ingress -n kube-system

.PHONY: conftest_deprek8
conftest_deprek8:
	for app_path in $(sort $(dir $(wildcard apps/*/))) ; do \
	  echo $$app_path; \
	  helm template $(echo $$app_path | cut -d "/" -f2) $$app_path | conftest test -p conftest-checks/deprek8.rego -; \
	done

.PHONY: conftest_all
conftest_all:
	for check_path in $(wildcard conftest-checks/*.rego) ; do \
	  echo "*** $$check_path ***"; \
	  for app_path in $(sort $(dir $(wildcard apps/*/))) ; do \
	    echo $$app_path; \
	    helm template $(echo $$app_path | cut -d "/" -f2) $$app_path | conftest test -p $$check_path -; \
	  done; \
	  echo '***'; \
	done

.PHONY: rancher_start
rancher_start:
	$(call preload_images,auth)
	docker run -d --name $(RANCHER_CONTAINER_NAME) -p 127.0.0.1:$(RANCHER_PORT):443 rancher/rancher:v2.4.3
	@echo "Docker network IP: $(RANCHER_HOST)"

.PHONY: rancher_stop
rancher_stop:
	-docker rm -f $(RANCHER_CONTAINER_NAME)

INIT_PATH=auth/terraform/init
MANAGE_PATH=auth/terraform/manage

.PHONY: rancher_tf_init
rancher_tf_init: terraform_clear rancher_start
	docker run -d --name $(POSTGRES_CONTAINER_NAME) -e POSTGRES_PASSWORD=password -e POSTGRES_DB=terraform_backend -p \
	127.0.0.1:$(POSTGRES_PORT):5432 postgres:11.8-alpine
	@echo 'Waiting for 30s for the Postgres and Rancher containers to initialize'
	sleep 30
	-cd $(INIT_PATH) && terraform init
	cd $(INIT_PATH) && terraform workspace new default
	cd $(INIT_PATH) && terraform init
	cd $(INIT_PATH) && terraform apply -var="rancher_docker_ip=$(RANCHER_HOST)" -auto-approve -no-color | grep admin_token | \
	cut -d' ' -f3 > ../manage/token
	sed "s|REPLACE_TOKEN|$$(cat $(MANAGE_PATH)/token)|g" $(MANAGE_PATH)/provider.template > $(MANAGE_PATH)/provider.tf
	rm $(MANAGE_PATH)/token

.PHONY: rancher_tf_apply
rancher_tf_apply:
	-cd $(MANAGE_PATH) && terraform init
	cd $(MANAGE_PATH) && (terraform workspace new manage || terraform workspace select manage)
	cd $(MANAGE_PATH) && terraform init
	cd $(MANAGE_PATH) && terraform apply

.PHONY: rancher_tf_destroy
rancher_tf_destroy: terraform_clear rancher_stop
	docker rm -f $(POSTGRES_CONTAINER_NAME)

.PHONY: terraform_clear
terraform_clear:
	-rm -rf $(INIT_PATH)/.terraform
	-rm -rf $(MANAGE_PATH)/.terraform
	-rm $(MANAGE_PATH)/provider.tf

.PHONY: user_create
user_create:
	auth/scripts/create_user.sh $(USER) $(GROUPS)

.PHONY: users_clear
users_clear:
	-rm -rf auth/config

.PHONY: permissions_apply
permissions_apply:
ifdef NAMESPACE
  ifdef USERS
	auth/scripts/read_only_permissions.sh $(NAMESPACE) $(USERS) User
  else ifdef GROUPS
	auth/scripts/read_only_permissions.sh $(NAMESPACE) $(GROUPS) Group
  else
	@echo 'Must set either USERS or GROUPS'
  endif
else
	@echo 'Must set NAMESPACE'
endif

.PHONY: permissions_delete
permissions_delete:
	kubectl delete rolebindings -A -l k8splayground-selector=permissions

.PHONY: argo_notifications_apply
argo_notifications_apply:
	$(call preload_images,apps/argo-cd-notifications)
	helm install -n argo-cd argo-cd-notifications apps/argo-cd-notifications || helm upgrade -n argo-cd-notifications argo-cd apps/argo-cd-notifications

.PHONY: argo_notifications_delete
argo_notifications_delete:
	helm uninstall -n argo-cd argo-cd-notifications

.PHONY: argo_apply
argo_apply:
	-kubectl create namespace argo-cd
# make argo_notifications_apply
	$(call preload_images,apps/argo-cd)
	helm install -n argo-cd argo-cd apps/argo-cd || helm upgrade -n argo-cd argo-cd apps/argo-cd

.PHONY: apps_apply
apps_apply: mock_build distributor_build logging_build
	-kubectl create namespace distributor
	-for app_path in $(sort $(dir $(wildcard apps/*/))) ; do \
	  $(call preload_images,$$app_path); \
	done
	helm install -n argo-cd argo-apps apps/argo-apps || helm upgrade -n argo-cd argo-apps apps/argo-apps

.PHONY: argo_delete
argo_delete: # argo_notifications_delete
	helm uninstall -n argo-cd argo-cd
	kubectl delete namespace argo-cd

.PHONY: airflow_apply
airflow_apply:
	$(call preload_images,apps/airflow)
	helm dependency update apps/airflow
	helm install airflow apps/airflow || helm upgrade airflow apps/airflow

.PHONY: airflow_delete
airflow_delete:
	helm uninstall airflow

.PHONY: behaviour_build
behaviour_build:
	for file_path in $(wildcard pod-behaviour/containers/Dockerfile_*) ; do \
		docker build -t $$(echo $$file_path | cut -d "_" -f2):0.0.1 -f $$file_path pod-behaviour/containers; \
	done

.PHONY: etcd_cert
etcd_cert:
	-mkdir k8s-behaviour/etcd
	docker cp k8splayground-control-plane:/etc/kubernetes/pki/etcd/ca.crt k8s-behaviour/etcd/
	docker cp k8splayground-control-plane:/etc/kubernetes/pki/etcd/ca.key k8s-behaviour/etcd/

.PHONY: etcd_clear
etcd_clear:
	-rm -rf k8s-behaviour/etcd

.PHONY: distributor_build
distributor_build:
	cd apps/distributor/client/bin && go build client.go
	docker build -t distributor:0.0.1 apps/distributor/client
	rm apps/distributor/client/bin/client
	kind load docker-image distributor:0.0.1 --name $(CLUSTER_NAME)

.PHONY: distributor_apply
distributor_apply: distributor_build
	-kubectl create namespace distributor
	-kubectl delete deployment -n distributor distributor
	helm install -n distributor distributor apps/distributor || helm upgrade -n distributor distributor apps/distributor

.PHONY: distributor_delete
distributor_delete:
	helm uninstall -n distributor distributor
	kubectl delete namespace distributor

.PHONY: distributor_test
distributor_test:
	-cd apps/distributor/client && go test ./tests/...

.PHONY: distributor_run
distributor_run:
	-kubectl delete -f apps/distributor/templates/configmap.yaml
	kubectl apply -f apps/distributor/templates/configmap.yaml
	cd apps/distributor/client/bin && CONFIGMAP_NAME=distributor RUN_MODE=local go run client.go

.PHONY: logging_build
logging_build:
	docker build -t log-generator:0.0.1 apps/logging/log-generator
	kind load docker-image log-generator:0.0.1 --name $(CLUSTER_NAME)

.PHONY: logging_apply
logging_apply: logging_build
	$(call preload_images,apps/logging)
	-kubectl delete statefulset logging-sidecar-test
	helm dependency update apps/logging
	helm install logging apps/logging -n kube-system || helm upgrade logging apps/logging -n kube-system

.PHONY: logging_delete
logging_delete:
	helm uninstall logging -n kube-system
