#!/bin/bash

# Author: Bin Wu <binwu@google.com>

pwd=`pwd`
cluster_name=elastic-demo
region=asia-east1
# zone=asia-east1-a
project_id=du-hast-mich
default_pool=default-pool
nodes_per_zone=5 # per zone
machine_type=e2-standard-2
release_channel=None # None -> static, e.g. rapid, regular, stable
gke_version=1.25.5-gke.1500
eck_version=2.6.1
es_cluster_name=dingo-demo

__create_gke() {
        #--zone "${zone}" \
        #--node-locations "${region}-a,${region}-b,${region}-c"
        #--num-nodes "1" for regional/multi-zone cluster, this is the number in each zone
    gcloud beta container \
        --project "${project_id}" clusters create "$cluster_name" \
        --zone "${region}-a" \
        --node-locations "${region}-a" \
        --no-enable-basic-auth \
        --enable-dataplane-v2 \
        --release-channel "${release_channel}" \
        --cluster-version "${gke_version}" \
        --machine-type "$machine_type" \
        --image-type "COS_CONTAINERD" \
        --disk-type "pd-ssd" \
        --disk-size "20" \
        --metadata disable-legacy-endpoints=true \
        --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
        --num-nodes "$nodes_per_zone" \
        --logging=SYSTEM,WORKLOAD \
        --monitoring=SYSTEM \
        --enable-managed-prometheus \
        --enable-ip-alias \
        --network "projects/${project_id}/global/networks/default" \
        --subnetwork "projects/${project_id}/regions/$region/subnetworks/default" \
        --default-max-pods-per-node "110" \
        --no-enable-master-authorized-networks \
        --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
        --no-enable-autoupgrade \
        --max-surge-upgrade 1 \
        --max-unavailable-upgrade 0 \
        --enable-autorepair

    __init
}

# setup the deployment enviroment for Elastic Stack
__init() {
    # Set kubectl to target the created cluster
    gcloud container clusters get-credentials $cluster_name \
        --zone "${region}-a" \
        --project ${project_id}

    # sysctl -w vm.max_map_count=262144 for every GKE node
    # Option 1
    # $pwd/bin/gke_sysctl_vmmaxmapcount.sh
    # Option 2
    kubectl apply -f $pwd/conf/node-daemon.yml

    # Install ECK
    [ -f $pwd/conf/crds.yaml ] || \
        curl https://download.elastic.co/downloads/eck/$eck_version/crds.yaml --output $pwd/conf/crds.yaml
    kubectl create -f $pwd/conf/crds.yaml

    [ -f $pwd/conf/operator.yaml ] || \
        curl https://download.elastic.co/downloads/eck/$eck_version/operator.yaml --output $pwd/conf/operator.yaml
    kubectl apply -f $pwd/conf/operator.yaml

    # create storage class
    kubectl create -f $pwd/conf/storage.yml

    ## make it default

    # 1. switch default class to false
    #kubectl patch storageclass standard \
        #-p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

    # 2. switch the default class to true for custom storage class
    #kubectl patch storageclass dingo-pdssd \
        #-p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
}

__init_gcp_credentials() {
    # FIXME: you may want a minimum privilege service account here just for GCS
    [ -f $pwd/conf/gcs.client.default.credentials_file ] || \
        cp $GOOGLE_APPLICATION_CREDENTIALS $pwd/conf/gcs.client.default.credentials_file

    # Optional: setup a GCP service account that can manipulate GCS for snapshots
    kubectl create secret generic gcs-credentials \
        --from-file=$pwd/conf/gcs.client.default.credentials_file
}

__deploy_elastic() {
    __init_gcp_credentials

    kubectl apply -f $pwd/templates/es.demo.yml
    kubectl apply -f $pwd/templates/kbn.demo.yml
}

__deploy_demo() {
    __create_gke

    __deploy_elastic
}

__password() {
    # kubectl get secret ${es_cluster_name}-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode
    kubectl get secret ${es_cluster_name}-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'
}

__password_reset() {
    kubectl delete secret ${es_cluster_name}-es-elastic-user
}

__status() {
    passwd=$(__password)
    lb_ip=`kubectl get services ${es_cluster_name}-es-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`

    kbn_ip=`kubectl get service dingo-demo-kbn-kb-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
    kbn_port=5601
    kbn_url=https://${kbn_ip}:${kbn_port}

    echo; echo "================================="; echo
    echo "Elasticsearch status: "
    curl -u "elastic:$passwd" -k "https://$lb_ip:9200"

    echo; echo "---------------------------------"; echo

    echo "Kibana: " ${kbn_url}
    echo "Elasticsearch: " "https://$lb_ip:9200"
    echo "Username: " elastic
    echo "Password: " ${passwd}
    echo "================================="; echo
}

__clean() {
    echo "Y" | gcloud container clusters delete $cluster_name \
        --zone "${region}-a"
}

__main() {
    if [ $# -eq 0 ]
    then
        __deploy_demo
        sleep 120
        __status
    else
        case $1 in
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
                __deploy_demo
                sleep 120
                __status
                ;;
        esac
    fi
}

__main $@
