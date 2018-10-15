#!/bin/bash

# set -e
set -u
set -o pipefail


function usage {
    echo "Usage: kversions [-k] file+" >&2
    echo "   -k - kinds (default: deploy,sts,job)" >&2
    echo "   -c - The name of the kubeconfig cluster to use"
    echo "   -x - The name of the kubeconfig context to use"
    echo "   -n - If present, the namespace scope for this CLI request"
    echo "   -h - show this help" >&2
    echo "" >&2
    echo "Lists container's versions." >&2
}


function process_args {
    while getopts ":hk:x:c:n:" opt; do
        case $opt in
            k)
                KINDS="$OPTARG"
                ;;
            x)
                CTX=$OPTARG
                ;;
            c)
                CLUSTER=$OPTARG
                ;;
            n)
                NAMESPACE=$OPTARG
                ;;
            h)
                usage
                exit 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                usage
                exit 1
                ;;
            ?)
            echo "Invalid option: ${OPTARG}" >&2
            exit 1
            ;;
        esac
    done
    KINDS=${KINDS:-deploy,sts,job}
    CONTEXT=${CONTEXT:-}
    CLUSTER=${CLUSTER:-}
    NAMESPACE=${NAMESPACE:-}
}


process_args "$@"
shift $((${OPTIND}-1))

QRY_VER='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}'
QRY_VER_STS='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.template.spec.containers[*]}{.image}{", "}{end}{end}'


kversions=$(mktemp /tmp/kversions.XXXXXX)

cmd="kubectl"
if [[ ! -z "${CTX}" ]]; then
    cmd="$cmd --context=${CTX}"
fi
if [[ ! -z "${CLUSTER}" ]]; then
    cmd="$cmd --cluster=${CLUSTER}"
fi
if [[ ! -z "${NAMESPACE}" ]]; then
    cmd="$cmd --namespace=${NAMESPACE}"
fi


IFS=',' read -ra kinds <<< "$KINDS"
for i in "${kinds[@]}"; do
    # process "$i"
    ${cmd} get "$i" -o=jsonpath="${QRY_VER_STS}" $@ >> ${kversions}
done

sort ${kversions} | uniq
