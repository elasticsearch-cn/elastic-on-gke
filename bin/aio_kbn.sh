#!/bin/bash

# Author: Bin Wu <binwu@google.com>
set -e
__usage() {
    echo "Usage: ./bin/kbn.sh {deploy|status|clean}"
}

__deploy() {
    # kubectl apply -f $PWD/templates/kbn.yml
    eval "cat <<EOF
$(<"$PWD"/templates/aio/kbn.yml)
EOF
" 2>/dev/null >"$PWD"/deploy/kbn.yml
    kubectl apply -f "$PWD"/deploy/kbn.yml

}

__clean() {
    # kubectl delete -f $PWD/templates/kbn.yml
    eval "cat <<EOF
$(<"$PWD"/templates/aio/kbn.yml)
EOF
" 2>/dev/null >"$PWD"/deploy/kbn.yml
    kubectl delete -f "$PWD"/deploy/kbn.yml

}

__status() {
    lb_ip=`kubectl get services ${K8S_KIBANA_SVC_NAME}-kb-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`

    echo "http://${lb_ip}:5601"
}

__main() {
    if [ $# -eq 0 ]
    then
        __usage
    else
        case $1 in
            deploy|d)
                __deploy
                ;;
            status|s)
                __status
                ;;
            clean)
                __clean
                ;;
            *)
                __usage
                ;;
        esac
    fi
}

__main $@
