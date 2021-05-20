#!/bin/bash

# Author: Bin Wu <binwu@google.com>

pwd=`pwd`

apm_name=dingo-apm

__usage() {
    echo "Usage: ./bin/apm.sh {deploy|status|clean}"
}

__deploy() {
    kubectl apply -f $pwd/deploy/apm.yml
}

__clean() {
    kubectl delete -f $pwd/deploy/apm.yml
}

__status() {
    kubectl get service --selector='common.k8s.elastic.co/type=apm-server'

    lb_ip=`kubectl get services ${apm_name}-apm-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`

    echo "http://${lb_ip}:8200"
}

__password() {
    kubectl get secret ${apm_name}-apm-token -o go-template='{{index .data "secret-token" | base64decode}}'
}

__password_reset() {
    kubectl delete secret ${apm_name}-apm-token
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
            password|pwd|pw|p)
                __password
                ;;
            pwdreset|pwreset)
                __password_reset
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
