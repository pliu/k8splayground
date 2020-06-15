#!/bin/bash

kubectl get namespace dangling-resources -o json | sed "s|\"kubernetes\"||g" > dangling-resources.json
kubectl replace --raw "/api/v1/namespaces/dangling-resources/finalize" -f ./dangling-resources.json
rm dangling-resources.json
