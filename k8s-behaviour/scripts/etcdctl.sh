#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ETCDCTL_API=3 etcdctl --insecure-skip-tls-verify=true --key=$SCRIPT_DIR/../etcd/ca.key --cert=$SCRIPT_DIR/../etcd/ca.crt $@
