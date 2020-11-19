#!/bin/bash

PROJECT_ID="felix-development-275503"
SERVICE_ACCOUNT_NAME="es-gke-sa"
GCS_BUCKET_NAME="es-gke-snapshots"


#create bucket if required
#region="asia-east1"
#gsutil mb -c standard -l ${region} gs://${GCS_BUCKET_NAME}/ 

gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} --display-name="Service Account for es on gke snapshots"

gsutil iam ch serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com:legacyBucketOwner gs://${GCS_BUCKET_NAME}/

gcloud iam service-accounts keys create --iam-account "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" ./conf/gcs.client.default.credentials_file