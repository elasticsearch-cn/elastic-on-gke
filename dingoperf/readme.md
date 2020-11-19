## Perf test for ES

1. init GKE

```
make init
```

2. deploy ES & Kibana, update the yaml files in `conf` dir according to your tests

```
make deploy
```

3. init the ES with best settings for ingest, you will need to update the `init_es.sh` for connection info

```
./init_es.sh
```

4. run the loader, update the `conf/config.properties` for connection info & testing parameters, then you are ready to go. 

lanch the test

```
./run.sh
```
