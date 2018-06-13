#!/bin/bash

# Compare source Kubernetes yaml file with already deployed configuration
# - extract Kubernetes components from the source file
# - diff by using 'apply' command in dry-run mode
# - diff by using 'command' command in dry-run mode
#
# If env var DIFFER is set, use it, otherwise invoke the 'diff' command
#
#
# Usage:
#  kcompare <kubernetes-yaml-file>
#

deployed="/tmp/${1}_deployed.yml"
source_apply="/tmp/${1}_source_apply.yml"
source_create="/tmp/${1}_source_create.yml"

kubectl create --dry-run -f ${1} \
    | cut -d " " -f 1,2 | sed -e 's| |/|' | sed -e 's/\"//g' \
    | while read x; do
    kubectl get -o yaml --export $x
    echo "---"
done > ${deployed}

kubectl apply --dry-run -o yaml -f ${1} > /tmp/${1}_source_apply.yml
kubectl create --dry-run -o yaml -f ${1} > /tmp/${1}_source_create.yml

if [[ -z ${DIFFER} ]]; then
    diff ${source_apply} ${deployed}
    echo "---------------------------------------------"
    diff ${source_create} ${deployed}
else
    ${DIFFER} ${source_apply} ${deployed} &
    ${DIFFER} ${source_create} ${deployed} &
fi
