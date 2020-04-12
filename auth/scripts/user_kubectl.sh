#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
kubectl --kubeconfig=$SCRIPT_DIR/../config/$1 --context=$1 ${@:2}
