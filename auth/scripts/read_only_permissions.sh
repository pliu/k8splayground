#!/bin/bash

NAMESPACE=$1
IFS=',' read -ra NAMES <<< "$2"
TYPE=$3

for i in "${NAMES[@]}" ; do
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $NAMESPACE-$TYPE-$i-ro
  namespace: $NAMESPACE
  labels:
    k8splayground-selector: permissions
subjects:
- kind: $TYPE
  name: $i
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
EOF
done
