#!/bin/bash

# delete all underlying Elastic resources (pods, secrets, services etc.)
kubectl get namespaces --no-headers -o custom-columns=:metadata.name \
      | xargs -n1 kubectl delete elastic --all -n

kubectl delete -f $pwd/conf/all-in-one.yaml
