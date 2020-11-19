#!/bin/bash

eshost=http://10.80.232.88:9200
esuser=elastic
espasswd=dingoperf

./esm \
    -x dingoperf-ingest \
    -y medcl \
    -s ${eshost} \
    -d ${eshost} \
    -m ${esuser}:${espasswd} \
    -n ${esuser}:${espasswd}  \
    -w 10  \
    -c 5000 \
    -b 5 \
    --regenerate_id  \
    --repeat_times=10 \
    --sliced_scroll_size=5
