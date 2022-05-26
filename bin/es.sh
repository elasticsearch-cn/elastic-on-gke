#!/bin/bash

# Author: Bin Wu <binwu@google.com>

pwd=`pwd`

es_cluster_name=dingo

__usage() {
    echo "Usage: ./bin/es.sh {deploy|password|status}"
}

__init_gcp_credentials() {
    # FIXME: you may want a minimum privilege service account here just for GCS
    [ -f $pwd/conf/gcs.client.default.credentials_file ] || \
        cp $GOOGLE_APPLICATION_CREDENTIALS $pwd/conf/gcs.client.default.credentials_file

    # Optional: setup a GCP service account that can manipulate GCS for snapshots
    kubectl create secret generic gcs-credentials \
        --from-file=$pwd/conf/gcs.client.default.credentials_file
}

__deploy() {
    __init_gcp_credentials

    kubectl apply -f $pwd/deploy/es.yml
}

__clean() {
    kubectl delete -f $pwd/deploy/es.yml
}

__status() {
    passwd=$(__password)
    lb_ip=`kubectl get services ${es_cluster_name}-es-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`

    curl -u "elastic:$passwd" -k "https://$lb_ip:9200"
}

__password() {
    # kubectl get secret ${es_cluster_name}-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode
    kubectl get secret ${es_cluster_name}-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'
}

__password_reset() {
    kubectl delete secret ${es_cluster_name}-es-elastic-user
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
