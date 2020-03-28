CLUSTER_NAME=k8splayground
IMAGE=kindest/node:v1.16.4@sha256:b91a2c2317a000f3a783489dfb755064177dbc3a0b2f4147d50f04825d016f55

.PHONY: kind_create
kind_create:
	kind create cluster --config=kind/config.yaml --name $(CLUSTER_NAME) --image $(IMAGE)

.PHONY: kind_destroy
kind_destroy:
	kind delete cluster --name $(CLUSTER_NAME)

.PHONY: apply_all
apply_all: npd_apply mock_apply nginx_apply prometheus_apply
	@echo 'Everything applied'

.PHONY: npd_apply
npd_apply:
	helm install node-problem-detector apps/node-problem-detector --namespace kube-system || helm upgrade node-problem-detector \
	apps/node-problem-detector --namespace kube-system

.PHONY: npd_delete
npd_delete:
	helm uninstall node-problem-detector --namespace kube-system

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
	find apps/prometheus-operator/rules -type f -name '*_test.yaml' -exec promtool test rules {} +

.PHONY: mock_apply
mock_apply:
	docker build -t mock-server:0.0.1 apps/mock-server/server
	kind load docker-image mock-server:0.0.1 --name $(CLUSTER_NAME)
	helm install mock-server apps/mock-server || helm upgrade mock-server apps/mock-server

.PHONY: mock_delete
mock_delete:
	helm uninstall mock-server

.PHONY: nginx_apply
nginx_apply:
	helm dependency update apps/nginx-ingress
	helm install nginx-ingress apps/nginx-ingress || helm upgrade nginx-ingress apps/nginx-ingress

.PHONY: nginx_delete
nginx_delete:
	helm uninstall nginx-ingress

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
