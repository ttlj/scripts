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

bname=$(basename "${1}")
deployed=$(mktemp "/tmp/${bname}__deployed.XXXXX")
source_apply=$(mktemp "/tmp/${bname}__source_apply.XXXXX")
source_create=$(mktemp "/tmp/${bname}__source_create.XXXXX")
echo $1
echo $deployed
echo $source_apply
echo $source_create

kubectl create --dry-run -f "${1}" \
    | cut -d " " -f 1,2 | sed -e 's| |/|' | sed -e 's/\"//g' \
    | while read x; do
    kubectl get -o yaml --export "${x}"
    echo "---"
done > ${deployed}

kubectl apply --dry-run -o yaml -f ${1} > "${source_apply}"
kubectl create --dry-run -o yaml -f ${1} > "${source_create}"

if [[ -z ${DIFFER} ]]; then
    diff ${source_apply} ${deployed}
    echo "---------------------------------------------"
    diff ${source_create} ${deployed}
else
    ${DIFFER} ${source_apply} ${deployed} &
    ${DIFFER} ${source_create} ${deployed} &
fi
