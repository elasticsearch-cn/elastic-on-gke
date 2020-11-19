#!/bin/bash

pwd=`pwd`

es_client=http://10.140.0.29:9200  
kbn_host=http://10.140.0.29:5601  
es_user=elastic
#es_pass=`make pw`
es_pass=dingoperf

# create an ES template
__create_index_template() {
    curl --insecure -X PUT \
        -u "elastic:${es_pass}" \
        "${es_client}/_template/dingoperf" \
        -H "Content-Type: application/json" \
        -d "@${pwd}/conf/index-dingoperf-template.json"
}

__create_index_and_setup() {
    # create a lifecycle pocily, edit the json data file according to your needs
    curl --insecure -X PUT \
        -u "elastic:${es_pass}" \
        "${es_client}/_ilm/policy/dingoperf-policy" \
        -H "Content-Type: application/json" \
        -d "@${pwd}/conf/index-dingoperf-policy.json"

    # create an index and assign an alias for writing
    curl --insecure -X PUT \
        -u "elastic:${es_pass}" \
        "${es_client}/dingoperf-000001" \
        -H "Content-Type: application/json" \
        -d '{"aliases": {"dingoperf-ingest": { "is_write_index": true }}}'
}

# create a Kibana index pattern
__create_index_pattern() {
    curl --insecure -X POST \
        -u "elastic:${es_pass}" \
        "${kbn_host}/api/saved_objects/index-pattern" \
        -H "kbn-xsrf: true" \
        -H "Content-Type: application/json" \
        -d '{"attributes":{"title":"dingoperf*","timeFieldName":"@timestamp","fields":"[]"}}'
}

__create_index_template
__create_index_and_setup
__create_index_pattern
