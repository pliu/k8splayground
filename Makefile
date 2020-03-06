CLUSTER_NAME=k8splayground-cluster
CONFIG_PATH=./kind/$(CLUSTER_NAME).conf
KUBECTL_CMD=kubectl --kubeconfig $(CONFIG_PATH)
IMAGE=kindest/node:v1.16.4@sha256:b91a2c2317a000f3a783489dfb755064177dbc3a0b2f4147d50f04825d016f55

.PHONY: kind_create
kind_create:
	kind create cluster --config ./kind/config.yaml --name $(CLUSTER_NAME) --image $(IMAGE)
	kind get kubeconfig --name $(CLUSTER_NAME) > $(CONFIG_PATH)
	kubectl patch configmap kube-proxy --patch "$(cat kind/kube-proxy-patch.yaml)" -n kube-system
	kubectl rollout restart daemonset kube-proxy -n kube-system

.PHONY: kind_destroy
kind_destroy:
	kind delete cluster --name $(CLUSTER_NAME)

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

.prometheus_pf:
	{ kubectl port-forward svc/prometheus-operator-prometheus 9000:9090 >> /dev/null 2>&1 & echo $$! >> .prometheus_pf; }
	{ kubectl port-forward svc/prometheus-operator-grafana 9001:80 >> /dev/null 2>&1 & echo $$! >> .prometheus_pf; }
	{ kubectl port-forward svc/prometheus-operator-alertmanager 9002:9093 >> /dev/null 2>&1 & echo $$! >> .prometheus_pf; }

.PHONY: .prometheus_stop_pf
.prometheus_pf_stop:
	cat .prometheus_pf | while read line ; do \
		kill $$line; \
	done
	rm .prometheus_pf

.PHONY: prometheus_test_rules
prometheus_test_rules:
	find apps/prometheus-operator/tests -type f -name '*.yaml' -exec promtool test rules {} 
