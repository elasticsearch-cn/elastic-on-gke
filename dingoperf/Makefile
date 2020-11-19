pwd := $(shell pwd)
es_cluster_name := dingo

init:
	@kubectl apply -f $(pwd)/../conf/node-daemon.yml
	@kubectl apply -f $(pwd)/../conf/all-in-one.yaml
	@kubectl create -f $(pwd)/../conf/storage.yml

deploy:
	@kubectl apply -f $(pwd)/conf/es.single_node.yml
	@kubectl apply -f $(pwd)/conf/kbn.yml

clean:
	@kubectl delete -f $(pwd)/conf/es.single_node.yml
	@kubectl delete -f $(pwd)/conf/kbn.yml

pw:
	@kubectl get secret $(es_cluster_name)-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode

stat:
	@kubectl get pod
	@kubectl get svc

.PHONY: deploy clean run pw init
