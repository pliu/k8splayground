#!/bin/bash

USER=$1
if [[ -n "$2" ]] ; then
    IFS=',' read -ra GROUPS <<< "$2"
fi

GROUP_STR=""
if [[ ! -z "$GROUPS" ]] ; then
    for i in "${GROUPS[@]}" ; do
        GROUP_STR=${GROUP_STR}/O=$i
    done
fi

# Create user key and certificate signing request
openssl req -new -newkey rsa:4096 -nodes -keyout user.key -out user.csr -subj "/CN=$USER$GROUP_STR"

# Create Kubernetes CertificateSigningRequest object and clean up certificate signing request
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: $USER
spec:
  username: $USER
  request: $(cat user.csr | base64 | tr -d '\n')
  usages:
  - client auth
EOF
rm user.csr

# Approve CertificateSigningRequest
kubectl certificate approve $USER

# Retrieve signed user certificate, clean up CertificateSigningRequest, and test that it matches the user key
kubectl get csr $USER -o jsonpath='{.status.certificate}' | base64 --decode > user.crt
kubectl delete csr $USER
if [[ $(openssl x509 -in user.crt -pubkey -noout -outform pem | sha256sum) != $(openssl pkey -in user.key -pubout -outform pem \
| sha256sum) ]] ; then
  echo "Key and certificate don't match"
  echo "Key:         $(openssl pkey -in user.key -pubout -outform pem | sha256sum)"
  echo "Certificate: $(openssl x509 -in user.crt -pubkey -noout -outform pem | sha256sum)"
  rm user.key
  rm user.crt
  exit 1
fi

# Retrieve k8s certificate
kubectl config view -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --raw | base64 --decode - > k8s.crt

# Create kubeconfig
kubectl config set-cluster $(kubectl config view -o jsonpath='{.clusters[0].name}') \
--server=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}') --certificate-authority=k8s.crt \
--kubeconfig=auth/config/$USER --embed-certs
kubectl config set-credentials $USER --client-certificate=user.crt --client-key=user.key --embed-certs --kubeconfig=auth/config/$USER
kubectl config set-context $USER --cluster=$(kubectl config view -o jsonpath='{.clusters[0].name}') --user=$USER \
--kubeconfig=auth/config/$USER

# Clean up
rm user.key
rm user.crt
rm k8s.crt
