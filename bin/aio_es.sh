#!/bin/bash

# Author: Bin Wu <binwu@google.com>
set -e

__usage() {
    echo "Usage: ./bin/es.sh {deploy|password|status|clean}"
}

__init_gcp_credentials() {
    # FIXME: you may want a minimum privilege service account here just for GCS
    [ -f $PWD/conf/gcs.client.default.credentials_file ] || \
        cp $GOOGLE_APPLICATION_CREDENTIALS $PWD/conf/gcs.client.default.credentials_file
}

__deploy() {
    __init_gcp_credentials

    kubectl apply -f "$PWD"/deploy/es."$ES_CLUSTER_TYPE".yml
}

__clean() {

    kubectl delete -f "$PWD"/deploy/es."$ES_CLUSTER_TYPE".yml
}

__status() {
    passwd=$(__password)
    lb_ip=`kubectl get services ${ES_CLUSTER_NAME}-es-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`

    curl -u "elastic:$passwd" -k "https://$lb_ip:9200"
}

__password() {
    kubectl get secret ${ES_CLUSTER_NAME}-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode
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
