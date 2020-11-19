#!/bin/bash

# Author: Bin Wu <binwu@google.com>
set -e
__usage() {
    echo "Usage: ./bin/gke.sh {create|(delete,del,d)|scale|fix}"
}

__set_gke_lables() {
    if [ $GKE_LABLES ]; then
        echo "--labels $GKE_LABLES "
    fi
}

__set_gke_location_type() {

    if [ $GKE_LOCATION_TYPE = zonel ]; then
        echo "--zone ${GKE_ZONE} "
    elif [ $GKE_LOCATION_TYPE = regionl ]; then
        echo "--region ${GKE_REGION}"
    else
        echo "GKE_LOCATION_TYPE : zonel or regionl "
        exit 1
    fi
}

__create() {
    #--zone "${zone}" \
    #--node-locations "${region}-a,${region}-b,${region}-c"
    #--num-nodes "1" for regional/multi-zone cluster, this is the number in each zone
    gcloud beta container --project "${GKE_PROJECT_ID}" clusters create "$GKE_CLUSTER_NAME" $(__set_gke_location_type) --node-locations "$GKE_NODE_ZONE" --no-enable-basic-auth --enable-dataplane-v2 --cluster-version $GKE_VER --machine-type "$GKE_NODE_MACHINE_TYPE" --image-type "COS" --disk-type "pd-ssd" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "$GKE_NODE_PER_ZONE" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/${GKE_PROJECT_ID}/global/networks/default" --subnetwork "projects/${GKE_PROJECT_ID}/regions/$GKE_REGION/subnetworks/default" --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing --no-enable-autoupgrade --max-surge-upgrade 1 --max-unavailable-upgrade 0 $(__set_gke_lables) --enable-autorepair

    # Set kubectl to target the created cluster
    gcloud container clusters get-credentials $GKE_CLUSTER_NAME $(__set_gke_location_type) --project ${GKE_PROJECT_ID}

    # sysctl -w vm.max_map_count=262144 for every GKE node
    # Option 1
    # $pwd/bin/gke_sysctl_vmmaxmapcount.sh
    # Option 2
    kubectl apply -f $PWD/conf/node-daemon.yml

    # Install ECK: deploy Elastic operator
    # https://download.elastic.co/downloads/eck/1.2.1/all-in-one.yaml
    kubectl apply -f $PWD/conf/all-in-one.yaml

    # create storage class
    kubectl create -f $PWD/conf/storage.yml

    ## make it default

    # 1. switch default class to false
    #kubectl patch storageclass standard \
    #-p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

    # 2. switch the default class to true for custom storage class
    #kubectl patch storageclass dingo-pdssd \
    #-p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

    # Optional: setup a GCP service account that can manipulate GCS for snapshots
    if [ $ES_BACKUP_SERVICE_ACCOUNT_NAME ]; then
        kubectl create secret generic $ES_BACKUP_SERVICE_ACCOUNT_NAME \
            --from-file=$PWD/conf/gcs.client.default.credentials_file
    fi
}

__add_preemptible_pool() {
    gcloud beta container \
        --project "${GKE_PROJECT_ID}" node-pools create "preemptible" \
        --cluster "$GKE_CLUSTER_NAME" \
        $(__set_gke_location_type) \
        --machine-type "n2-standard-2" \
        --image-type "COS" \
        --disk-type "pd-ssd" \
        --disk-size "100" \
        --metadata disable-legacy-endpoints=true \
        --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
        --preemptible \
        --num-nodes "1" \
        --enable-autoscaling \
        --min-nodes "1" \
        --max-nodes "10" \
        --enable-autoupgrade \
        --enable-autorepair
}

__delete() {
    echo "Y" | gcloud container clusters delete $GKE_CLUSTER_NAME \
        $(__set_gke_location_type) --project "${GKE_PROJECT_ID}"
}

__scale() {
    # for a regional cluster, --num-nodes is the number for each zone
    # or you could only specify --zone here

    echo "Y" | gcloud container clusters resize $GKE_CLUSTER_NAME \
        --project "${GKE_PROJECT_ID}" \
        $(__set_gke_location_type)
    --node-pool $GKE_NODE_POOL_NAME \
        --num-nodes "$GKE_NODE_PER_ZONE"
}

__fix() {
    $PWD/bin/gke_sysctl_vmmaxmapcount.sh fix
}

__check() {
    $PWD/bin/gke_sysctl_vmmaxmapcount.sh check
}

__main() {
    if [ $# -eq 0 ]; then
        __usage
    else
        case $1 in
        create | c)
            __create
            ;;
        delete | del | d)
            __delete
            ;;
        scale | s)
            __scale
            ;;
        fix | f)
            __fix
            ;;
        check | chk)
            __check
            ;;
        *)
            __usage
            ;;
        esac
    fi
}

__main $@
