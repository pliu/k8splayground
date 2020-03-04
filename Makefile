CLUSTER_NAME=k8splayground-cluster
CONFIG_PATH=./kind/$(CLUSTER_NAME).conf
KUBECTL_CMD=kubectl --kubeconfig $(CONFIG_PATH)
IMAGE=kindest/node:v1.16.4@sha256:b91a2c2317a000f3a783489dfb755064177dbc3a0b2f4147d50f04825d016f55

kind_create:
	kind create cluster --config ./kind/config.yaml --name $(CLUSTER_NAME) --image $(IMAGE)
	kind get kubeconfig --name $(CLUSTER_NAME) > $(CONFIG_PATH)

kind_destroy:
	kind delete cluster --name $(CLUSTER_NAME)

apply_npd:
	kubectl apply -f apps/node-problem-detector/templates

delete_npd:
	kubectl delete -f apps/node-problem-detector/templates
