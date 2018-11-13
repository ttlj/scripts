#!/bin/bash

# set -e
set -u
set -o pipefail


function usage {
    cat <<EOF
Usage: $0 [-k kinds] [-x context] [-c cluster] [-n namespace] [-s sep]
   -k - kinds (default: deploy,sts)
   -c - name of the kubeconfig cluster to use
   -x - name of the kubeconfig context to use
   -n - namespace scope
   -s - separator; default=:\t
   -h - show this help

Lists container's versions for specified <kinds>
EOF
}


function process_args {
    while getopts ":hk:x:c:n:s:" opt; do
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
            s)
                SEP=$OPTARG
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
    KINDS=${KINDS:-deploy,sts}
    CTX=${CTX:-}
    CLUSTER=${CLUSTER:-}
    NAMESPACE=${NAMESPACE:-}
    SEP=${SEP:-":\t"}
}


process_args "$@"
shift $((${OPTIND}-1))

QRY_VER='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}'
QRY_VER_STS='{range .items[*]}{"\n"}{.metadata.name}{"'${SEP}'"}{range .spec.template.spec.containers[*]}{.image}{";"}{end}{end}'
QRY_VER_POD='{range .items[*]}{"\n"}{.metadata.name}{", "}{range .status.containerStatuses[*]}{.image}{", "}{range .status.containerStatuses[*]}{.imageID}{"foobar"}{end}{end}{end}'


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

sort ${kversions} | uniq | sed 's/;$//'
