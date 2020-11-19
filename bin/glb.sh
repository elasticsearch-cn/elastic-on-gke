#!/bin/bash

# Author: Bin Wu <binwu@google.com>

pwd=`pwd`
glb_name=elk-static-ip

__usage() {
    echo "Usage: ./bin/glb.sh {reserve|release|status|deploy|clean}"
}

__reserve_ip() {
    gcloud compute addresses create $glb_name --global

    gcloud compute addresses describe $glb_name --global | grep "address:" | cut -d ' ' -f 2
}

__release_ip() {
    echo "Y" | gcloud compute addresses delete $glb_name --global
}

__cert() {
    # delete the certificate
    kubectl delete -f $pwd/deploy/cert.yml

    # create the certificate
    kubectl apply -f $pwd/deploy/cert.yml
}

__status() {
    # gcloud compute addresses list --filter="name=$glb_name"
    gcloud compute addresses describe $glb_name --global
}

__deploy() {
    kubectl apply -f $pwd/deploy/lb.yml
}

__clean() {
    kubectl delete -f $pwd/deploy/lb.yml
}

__main() {
    if [ $# -eq 0 ]
    then
        __usage
    else
        case $1 in
            reserve|r)
                __reserve_ip
                ;;
            release)
                __release_ip
                ;;
            status|s)
                __status
                ;;
            cert)
                __cert
                ;;
            deploy|d)
                __deploy
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
