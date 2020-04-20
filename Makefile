CLUSTER_NAME=k8splayground
IMAGE=kindest/node:v1.16.4@sha256:b91a2c2317a000f3a783489dfb755064177dbc3a0b2f4147d50f04825d016f55
RANCHER_CONTAINER_NAME=k8splayground-rancher
RANCHER_PORT=444

.PHONY: kind_create
kind_create: users_clear
	kind create cluster --config=kind/config.yaml --name $(CLUSTER_NAME) --image $(IMAGE)

.PHONY: kind_destroy
kind_destroy: users_clear
	kind delete cluster --name $(CLUSTER_NAME)

.PHONY: apply_all
apply_all: npd_apply mock_apply nginx_apply prometheus_apply
	@echo 'Everything applied'

.PHONY: npd_apply
npd_apply:
	helm install node-problem-detector apps/node-problem-detector -n kube-system || helm upgrade node-problem-detector \
	apps/node-problem-detector -n kube-system

.PHONY: npd_delete
npd_delete:
	helm uninstall node-problem-detector --n kube-system

.PHONY: prometheus_apply
prometheus_apply:
	helm dependency update apps/prometheus-operator
	helm install prometheus-operator apps/prometheus-operator || helm upgrade prometheus-operator apps/prometheus-operator

.PHONY: prometheus_delete
prometheus_delete:
	helm uninstall prometheus-operator
	kubectl delete service prometheus-operator-kubelet -n kube-system

.PHONY: prometheus_test_rules
prometheus_test_rules:
	find apps/prometheus-operator/rules -type f -name '*.yaml' -not -name '*_test.yaml' -exec promtool check rules {} +
	find apps/prometheus-operator/rules -type f -name '*_test.yaml' -exec promtool test rules {} +

.PHONY: mock_build
mock_build:
	docker build -t mock-server:0.0.1 apps/mock-server/server
	kind load docker-image mock-server:0.0.1 --name $(CLUSTER_NAME)

.PHONY: mock_apply
mock_apply: mock_build
	helm install mock-server apps/mock-server || helm upgrade mock-server apps/mock-server

.PHONY: mock_delete
mock_delete:
	helm uninstall mock-server

.PHONY: nginx_apply
nginx_apply:
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
	docker run -d --restart=unless-stopped --name $(RANCHER_CONTAINER_NAME) -p 127.0.0.1:$(RANCHER_PORT):443 rancher/rancher:latest
	@echo "Docker network IP: $$(docker inspect $(RANCHER_CONTAINER_NAME) -f '{{ json .NetworkSettings.Networks.bridge.IPAddress }}')"

.PHONY: rancher_stop
rancher_stop:
	docker rm -f $(RANCHER_CONTAINER_NAME)

.PHONY: user_create
user_create:
	auth/scripts/create_user.sh $(USER) $(GROUPS)

.PHONY: users_clear
users_clear:
	-rm auth/config/*

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

.PHONY: argo_apply
argo_apply:
	-kubectl create namespace argo-cd
	helm install -n argo-cd argo-cd apps/argo-cd || helm upgrade -n argo-cd argo-cd apps/argo-cd

.PHONY: apps_apply
apps_apply: mock_build
	helm install -n argo-cd argo-apps apps/argo-apps || helm upgrade -n argo-cd argo-apps apps/argo-apps

.PHONY: argo_delete
argo_delete:
	helm uninstall -n argo-cd argo-cd
	kubectl delete namespace argo-cd
