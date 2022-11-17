#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SERVICEACCOUNT_NAME=$1
NAMESPACE=$2
SECRET_NAME=$(kubectl get secrets -n $NAMESPACE | grep $SERVICEACCOUNT_NAME-token- | awk -F " " '{print $1}')

# Retrieve Kubernetes certificate
kubectl config view -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --raw | base64 --decode > k8s.crt

# Create kubeconfig
kubectl config set-cluster $(kubectl config view -o jsonpath='{.clusters[0].name}') \
--server=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}') \
--certificate-authority=k8s.crt \
--embed-certs \
--kubeconfig=$SCRIPT_DIR/../config/$SERVICEACCOUNT_NAME
kubectl config set-credentials $SERVICEACCOUNT_NAME \
--token=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode) \
--kubeconfig=$SCRIPT_DIR/../config/$SERVICEACCOUNT_NAME
kubectl config set-context $SERVICEACCOUNT_NAME \
--cluster=$(kubectl config view -o jsonpath='{.clusters[0].name}') \
--user=$SERVICEACCOUNT_NAME \
--kubeconfig=$SCRIPT_DIR/../config/$SERVICEACCOUNT_NAME

# Clean up
rm k8s.crt
