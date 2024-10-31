## <span style="color:red"> This project is migrated from：https://github.com/bindiego/local_services/tree/develop/k8s/gke/elastic</span>

# Elastic Stack on k8s/GKE

Known production environment: 40 all role nodes evenly spread over 2 zones with 200TB data pd mounted.

## Prerequisites

Suppose you already have access to Google Cloud Platform with proper permissions. We will use [Official ECK](https://www.elastic.co/guide/en/cloud-on-k8s/1.0/k8s-quickstart.html#k8s-deploy-eck) operator with [Official Containers / Dockers](https://www.docker.elastic.co) & [Docker source repo](https://github.com/elastic/dockerfiles). They are all open source and free, especially the operator can handle the Elasticsearch nodes upgrades/migrations in a graceful way, and lot more. 

Once you checked out this repo, make sure you stay in this folder as your working directory, `local_services/k8s/gke/elastic`

In case you do **not** have `gcloud` installed, you can run `./bin/gcloud.sh install` to get it. This will have the cloud SDK installed in your `$HOME/google-cloud-sdk` directory. Add the full path of `bin` folder to your `$PATH` to make it works.

Run `./bin/gcloud.sh` for other usages, but importantly, make sure you have `kubectl` properly installed, or you can run `./bin/gcloud.sh kubectl` to have it setted up.

Now we are good to go!

---

## Quickstart 快速开始（一键启动，用于测试、演示、PoC）

By default, the GKE resources will be launched in `asia-east1`, a.k.a [Taiwan](https://github.com/elasticsearch-cn/elastic-on-gke/blob/develop/bin/demo.sh#L7), region as a zonal cluster in zone-a to minimize your demo/PoC costs. Feel free to change & [choose one](https://cloud.google.com/compute/docs/regions-zones) close to you.

After that you are all set.

`./bin/demo.sh` will setup everything for you. Once completed, you should seen something similar to the following output

```
=================================

Elasticsearch status:
{
  "name" : "dingo-demo-es-zone-a-1",
  "cluster_name" : "dingo-demo",
  "cluster_uuid" : "ouod-dk1R8-o_Et1LhJ19g",
  "version" : {
    "number" : "8.15.3",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "48a287ab9497e852de30327444b0809e55d46466",
    "build_date" : "2024-02-19T10:04:32.774273190Z",
    "build_snapshot" : false,
    "lucene_version" : "9.9.2",
    "minimum_wire_compatibility_version" : "7.17.0",
    "minimum_index_compatibility_version" : "7.0.0"
  },
  "tagline" : "You Know, for Search"
}

---------------------------------

Kibana:  https://35.201.182.178:5601
Elasticsearch:  https://35.234.3.182:9200
Username:  elastic
Password:  password
=================================
```

and you could always retrieve above information by running `./bin/demo.sh status`

如果最后的output里没有正确输出连接信息，可以等待几分钟时间再次尝试手动查询集群链接状态 `./bin/demo.sh status`

### clean up

To tidy things up and release all the created cloud resources, simply run `./bin/demo.sh clean` 

---

## Get Started 详细文档

Check the [Advanced topics](https://github.com/elasticsearch-cn/elastic-on-gke#advanced-topics) if you would like to:

- Customize the size of your k8s/GKE nodes and pools
- Elasticsearch topology
- k8s/GKE & Elasticsearch node sizing
- Use your own meaningful names for workloads/services/ingress etc.

Alternatives to start the deployment

- [All-in-one scripts](https://github.com/elasticsearch-cn/elastic-on-gke/blob/develop/aio.md)
- [terraform](https://github.com/elasticsearch-cn/elastic-on-gke/tree/develop/terraform)

OK, let's get down to the business.

### Preparations 准备工作

#### Setup your `project_id` & targeting region to deploy

[Locate the project ID](https://support.google.com/googleapi/answer/7014113?hl=en). Open the [GCP console](https://console.cloud.google.com/), it's on the top-left corner "Project info" card by default.

Now, replace the `project_id` variable in [./bin/gke.sh](https://github.com/bindiego/local_services/blob/develop/k8s/gke/elastic/bin/gke.sh#L9) with your own project id.

For targeting region, you will need to update two files

- [./bin/gke.sh](https://github.com/bindiego/local_services/blob/develop/k8s/gke/elastic/bin/gke.sh#L7)
- [Makefile](https://github.com/bindiego/local_services/blob/develop/k8s/gke/elastic/Makefile#L1)

Change the `region` variable on your choice, `us-central1` by default.

#### Choose a predefined Elasticsearch deployment 选择一个预置的集群架构

You can later adjust all these settings to archieve your own goal. We will discuss more in [Advanced topics](https://github.com/elasticsearch-cn/elastic-on-gke#advanced-topics).

##### Option 1: Single node 单节点（适合研发小伙伴）

Run `make init_single` and you done.

##### Option 2: All role deployments, with shard allocation awareness (not forced) 全角色节点部署（适合小规模多用途综合集群）

| zone-a        | zone-b         |
| ------------- | -------------- |
| ES x 2        | ES x 2         |

Run `make init_allrole`

##### Option 3: Production deployments, with shard allocation awareness (not forced) 角色分离部署（适合中大规模集群，最好针对搜索或者分析场景进行集群分离和相关内存的和IO的配置调优）

| zone-a           | zone-b           |
| ---------------- | ---------------- |
| Master x 2       | Master x 1       |
| Ingest x 1       | Ingest x 1       |
| Data x 2         | Data x 2         |
| Coordinating x 1 | Coordinating x 1 |
| ML x 1 | on any available node      |

You could even further adjust this to a single zone or 3 zones with forced shared allocation awareness, let's discuss more details in the [Advanced topics](https://github.com/elasticsearch-cn/elastic-on-gke#advanced-topics) so you could configure based on your needs.

Run `make init_prod`

#### GCP service account for GCS(Snapshots)

We use this credential for Elasticsearch cluster to manage it's snapshots. On GKE, we use [GCS](https://cloud.google.com/storage) (an object store on GCP) for that purpose.

Please consult [How to create & manage service accounts](https://cloud.google.com/iam/docs/creating-managing-service-accounts). Simply download the key, a json file, then name it `gcs.client.default.credentials_file` and put it into `conf` dir. We only need the permission to manipulate GCS, so make sure it has only the minimum permissions granted.

or Run `./bin/gcs_serviceaccount.sh` to create a service account and generate the json file to `./conf/gcs.client.default.credentials_file`. Please change the varialbes in the `./bin/gcs_serviceaccount.sh` for your environment.

By now, in your *working directory*, you should be able to run `cat ./conf/gcs.client.default.credentials_file` to check the existence and the contents of the file. If you didn't do this, the auto script will later use `$GOOGLE_APPLICATION_CREDENTIALS`  environment variable to copy that file to the destination. You cannot skip this by now let's talk about how to disble in [Advanced topics](https://github.com/elasticsearch-cn/elastic-on-gke#advanced-topics) if you really have to. 

---

### Launch GKE/k8s cluster 部署 GKE/k8s 资源池

Run `./bin/gke.sh create`

#### Think about the ingress by now

You can easily change whatever you want, but you'd better think about this by now since you may need to update the deployment files.

We enabled all data security options, so all the communications are secured too.

##### Option 1: GLB with forced https (**Highly recommended** because of **security**)

The only prerequisite here is you need a domain name, let's assume it is `bindiego.com`.

Let's take an overview of the connections,

Data ---https---> Global Load Balancer ---https---> Ingest nodes

Clients ---https---> Global Load Balancer ---https---> Coordinating nodes

Kibana --https---> Global Load Balancer ---https---> Kibana(s)

As you can see, we don't terminate the `https` protocol  for the LB's backends. You can certainly do by updating the yml files accordingly, let's talk about that later.

It's the time to reserve an Internet IP address for your domain. 

Run `./bin/glb.sh reserve`, this should print out the actual IP address for you. If you missed for whatever reason, you will always be able to retrieve it by `./bin/glb.sh status`

OK, time to configure your DNS

I have added 3 sub-domains for Kibana, Elasticsearch ingest & Elasticsearch client respectively. You can do that by adding 3 **A** records 

- k8na.bindiego.com
- k8es.ingest.bindiego.com
- k8es.client.bindiego.com

all pointing to the static IP address you just reserved.

Optionally, you may want to add a DNS **CAA** record to specify the authority who sign the certificate. This is super important for China mainland users, since in this *quickstart* sample we are going to use [Google managed certificate](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs?hl=hu-HU) for simplicity. Or Google signed ones will have the keyword **Google** and potentially could be blocked by the [GFW](https://en.wikipedia.org/wiki/Great_Firewall). 

- Google `CAA 0 issue "pki.goog"`
- Letsencrypt `CAA 0 issue "letsencrypt.org"`

You will need to update 2 files now,

- `./deploy/cert.yml` consult the template [`cert.yml`](https://github.com/elasticsearch-cn/elastic-on-gke/blob/develop/templates/cert.yml)
- `./deploy/lb.yml` consult the template [`lb.yml`](https://github.com/elasticsearch-cn/elastic-on-gke/blob/develop/templates/lb.yml)

Better do a quick `find & replace` in the text editor of your choice to have those domains configured properly according to your environment.

Once you done, it's the time to run `./bin/glb.sh cert`, wait the last step to deploy the GLB.

##### Option 2: Regional TCP LB

This one is really simple, depends on which service you would like to expose, simply uncomment the `spec.http` sections in either [`./deploy/es.yml`](https://github.com/elasticsearch-cn/elastic-on-gke/blob/develop/templates/es.all_role.yml#L7-L10) or [`./deploy/kbn.yml`](https://github.com/elasticsearch-cn/elastic-on-gke/blob/develop/templates/kbn.yml#L8-L11) or both. And you **do not** need to deploy the GLB in the end as you will do for option 1.

This will setup up regional TCP LB for your deployments respectively. Make sure you access the `ip:port` by using **`https`** protocol.

Be cautious if you didn't setup the certificates properly or used the default custom ones, when you try to connect to this secured (ssl enabled) cluster. You could simply bypass the verification in curl by using `curl --insecure` option. But for encrypted communication in code, here let's use java as an example, you could consult the [official docs](https://www.elastic.co/guide/en/elasticsearch/client/java-rest/current/_encrypted_communication.html)

这里要非常注意的就是如果你自己生成的证书，或者使用默认的证书，你应该会遇到下面的问题，我们这里提供了解决方法。

As you could see in the [sample code](https://github.com/elastic/elasticsearch/blob/master/client/rest/src/test/java/org/elasticsearch/client/documentation/RestClientDocumentation.java#L406), you will need to **craft** an [`SSLContext`](https://docs.oracle.com/en/java/javase/11/docs/api/java.base/javax/net/ssl/SSLContext.html), something like this:

```java
try {
    // SSLContext context = SSLContext.getInstance("SSL");
    SSLContext context = SSLContext.getInstance("TLS");

    context.init(null, new TrustManager[] {
        new X509TrustManager() {
            public void checkClientTrusted(X509Certificate[] chain, String authType) {}

            public void checkServerTrusted(X509Certificate[] chain, String authType) {}

            public X509Certificate[] getAcceptedIssuers() { return null; }
        }
    }, null);

    httpAsyncClientBuilder.setSSLContext(context)
        .setSSLHostnameVerifier(NoopHostnameVerifier.INSTANCE);
} catch (NoSuchAlgorithmException ex) {
    logger.error("Error when setup dummy SSLContext", ex);
} catch (KeyManagementException ex) {
    logger.error("Error when setup dummy SSLContext", ex);
} catch (Exception ex) {
    logger.error("Error when setup dummy SSLContext", ex);
}
```

Basically, the above code does two things

- A Dummy SSL context
- Turn off the Hostname verifier

##### Option 3: Internal access only

[infini gateway](https://hub.docker.com/r/medcl/infini-gateway)

### Deploy Elasticsearch Cluster

`./bin/es.sh deploy`

Services may take a little while (1min or 2) to in a ready status. Check it in the GCP console or by `kubectl` commands.

#### Get user *elastic* credentials

`./bin/es.sh password`

You will need this credential to login to Kibana or talking to Elasticsearch cluster. For the latest version, when interacting with Elasticsearch, you may want a [token based authentication](https://www.elastic.co/guide/en/elasticsearch/reference/master/token-authentication-services.html) rather than embeded usernname & password.

### Deploy Kibana

`./bin/kbn.sh deploy`

#### Kibana health check

[Proposed fix](https://github.com/bindiego/local_services/commit/c1bf7d51a7fa9e90e7e8b113628f49e7d17f04bd#diff-17354ce2a6ce77a7239a4a671ef0308a)

Or manually edit the Health Check, replace `/` with `/login` after you deployed the *ingress*.

### Deploy the GLB for ingress

`./bin/glb.sh deploy`

After this you should be able to test your cluster, assume the domain is `bindiego.com`

1. Access Kibana via `k8na.bindiego.com` with username `elastic` and password from `./bin/es.sh password`

2. Test Elasticsearch ingest nodes

```
curl -u "elastic:<passwd>" -k "https://k8es.ingest.bindiego.com"
```

3. Test Elasticsearch coordinating nodes

```
curl -u "elastic:<passwd>" -k "https://k8es.client.bindiego.com"
```

Feel free to remove `-k` option since your certificate is managed by Google.

We done by now. Further things todo:

- Setup the file repo & snapshots to backup your data 
- Go to [Advanced topics](https://github.com/bindiego/local_services/tree/develop/k8s/gke/elastic#advanced-topics) for more complex setups, mostly about manipulating yml files.

### Setup file repository & snapshots

Configure GCS (Google Cloud Storage) bucket

```
PUT /_snapshot/dingo_gcs_repo
{
    "type": "gcs",
    "settings": {
      "bucket": "bucket_name",
      "base_path": "es_backup",
      "compress": true
    }
}
```

or

```
curl -X PUT \
  -u "elastic:<password>" \
  "https://k8es.client.bindiego.com/_snapshot/dingo_gcs_repo" \
  -H "Content-Type: application/json" -d '{
    "type": "gcs",
      "settings": {
        "bucket": "bucket_name",
        "base_path": "es_backup",
        "compress": true
      }
  }' 
```

Test snapshot

```
PUT /_snapshot/dingo_gcs_repo/test-snapshot
```

or, take a daily snapshot with date as part of the name

```
curl -X PUT \
  -u "elastic:<password>" \
  "https://k8es.client.bindiego.com/_snapshot/dingo_gcs_repo/test-snapshot_`date +'%Y_%m_%d'`" \
  -H "Content-Type: application/json" -d '{}'
```

More details about [Snapshot & restore](https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshot-restore.html) and lifecycle policies etc.

## Kibana

### Connect an Elasticsearch somewhere else

```
kubectl create secret generic kibana-elasticsearch-credentials --from-literal=elasticsearch.password=$PASSWORD
```

```
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kbn
  spec:
    version: 8.15.3
    count: 1
    config:
      elasticsearch.hosts:
        - https://elasticsearch.example.com:9200
      elasticsearch.username: elastic
    secureSettings:
      - secretName: kibana-elasticsearch-credentials
```

or the Elasticsearch cluster is using a slef-signed certificate, create a k8s secret containing the CA certificate and mount to the Kibana container as follows

```
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kbn
spec:
  version: 8.15.3
  count: 1
  config:
    elasticsearch.hosts:
      - https://elasticsearch-sample-es-http:9200
    elasticsearch.username: elastic
    elasticsearch.ssl.certificateAuthorities: /etc/certs/ca.crt
  secureSettings:
    - secretName: kibana-elasticsearch-credentials
  podTemplate:
    spec:
      volumes:
        - name: elasticsearch-certs
          secret:
            secretName: elasticsearch-certs-secret
      containers:
        - name: kibana
          volumeMounts:
            - name: elasticsearch-certs
              mountPath: /etc/certs
              readOnly: true
```

## APM Server

Use the `./bin/apm.sh` script for `deploy`, `clean`, `password`

---

## Utils 工具

### Retrieve Elasticsearch `elastic` user password 查询 `elastic` 用户密码

`./bin/es.sh pw`

### Reset / Rotate `elastic` user password 重制 `elastic` 用户密码

`./bin/es.sh pwreset`

## Advanced topics

### Storage 存储选项

We have predefined 4 different types of storage, you could refer to the `./deploy/es.yml`  file, section `spec.nodeSets[].volumeClaimTemplates.spec.storageClassName` to find out what we used for each different ES node.

[Detailed information](https://cloud.google.com/compute/docs/disks)

可以根据上面的链接各个磁盘的性能，对不同角色的节点选取相应的存储来实现资源的最佳利用。下面针对每个存储也给出了一些适合的建议。

1. dingo-pdssd 高性能

type: zonal SSD

best for: Data nodes (hot/warm), Master nodes, ML nodes

2. dingo-pdssd-ha 高性能高可用

type: regional SSD

best for: Master nodes, Data nodes (hot/warm)

3. dingo-pdssd-balanced 中等性能

type: zonal balanced SSD

best for: Data nodes (warm/cold), Master nodes, ML nodes

4. dingo-pdssd-blanced-ha 中等性能高可用

type: regional balanced SSD

best for: Master nodes, Data nodes (warm/cold)

5. dingo-pdhdd 磁盘

type: zonal HDD

best for: ML nodes, Ingest nodes, Coordinating nodes, Kibana, APM, Data nodes (cold)

6. dingo-pdhdd-ha 高可用磁盘

type: regional HDD

best for: Data nodes (cold)

### Elasticsearch nodes topology, affinity & node/pool selection

Topology is defined by `spec.nodeSets`, you may adjust accordingly to your design apart from the [predefined ones](https://github.com/elasticsearch-cn/elastic-on-gke#choose-a-predefined-elasticsearch-deployment)

Affnity is controlled in [deployment yaml](https://github.com/elasticsearch-cn/elastic-on-gke/blob/develop/templates/es.prod.yml#L85), used to do shard allocation awareness etc. 

GKE specific **node pool** selection is configured in [deployment yaml](https://github.com/elasticsearch-cn/elastic-on-gke/blob/develop/templates/es.prod.yml#L83), this could speparate different roles with different k8s/GKE nodes. E.g. Kibana, APM server and various Elasticsearch nodes.

### k8s/GKE cluster node & Elasticsearch node sizing

This could be a long topic to discuss, we actually want to hide the size of GKE node under the hood, let it depends on the Elasticsearch node's size. Let's skip the details and directly draw the conclusion,

- We have set the ES nodeSet affinity so data nodes will try to avoid host on the same machine (VM)
- If we can limit the GKE node size slightly larger than ES node, then we may avoid sharing compute resources across different nodeSets / roles
- For all role ES nodes, [Pod Topology Spread Constraints](https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/) is another way to evenly ditribute ES nodes rather than set `affinity`. In that way we may not be able to do the *shared allocation awarenness* by using current version of ECK.

#### Scale GKE cluster default-pool

`./bin/gke.sh scale <number>`

NOTE: the `<nubmer>` here is number of nodes in **each zone**

#### Scale the workloads

1. Elasticsearch

Update `spec.nodeSets.count` for the specific group of nodes, then `./bin/es.sh deploy`

2. All others

Update `spec.count`, then `./bin/kbn.sh deploy` for Kibana and so on so forth.

#### Workloads sizing

1. Elasticsearch

Node memory: `spec.nodeSets.podTemplate.spec.containers.resources.requests.memory` & `spec.nodeSets.podTemplate.spec.containers.resources.limits.memory`

JVM heap size: `spec.nodeSets.podTemplate.spec.containers.env`for variable `ES_JAVA_OPTS`

We generally double the total memory upon JVM heap for `Data nodes` with 64GB maximum. [Here](https://gist.github.com/bindiego/3a0e73aa2e7ec17188f1c9c4cc8b7198) is the reason and why you should keep the heap size between 26GB and 31GB.

Other nodes we only add 1GB extra above the heap size, hence uaually 32GB maxinum. Very occasionally, you may need your coordinating nodes beyond that, consult our ES experts you could reach out :)

2. All others

Memory: `spec.podTemplate.spec.containers.resources.requests.memory` & `spec.podTemplate.spec.containers.resources.limits.memory`

### Upgrade Elastic Stack 升级Elasticsearch

Simply update `spec.version` in yaml and `make <your choice of topology>`, then run `./deploy/es.sh deploy` and you done. All other services, e.g. Kibana, APM are the same.

只要把部署yaml文件里的版本升级到目标版本，再次 deploy 就可以了。整个升级动作会由operator自动操作完成，过程根据情况可能很快也会比较漫长。

NOTE: downgrade is **NOT** supported 降级是不支持的

We have always set `spec.nodeSets.updateStrategy.changeBudget.maxUnavailable` smaller than `spec.nodeSets.count`, usually `N - 1`. If the `count` is `1`, then set the `maxUnavailable` to `-1`.

In case if you have 3 master nodes across 3 zones and defined in 3 nodeSets, you do not have to worry about they may offline at the same time. The ECK operator could handle that very well :)

#### Troubleshooting 升级过程中的问题排查

1. In case the pod is stucking in "Terminating" status, you could force delete it. Use command `kubectl get pod` to check the status and name of the pod. Then delete with `kubectl delete pods <pod> --grace-period=0 --force`. [More details](https://kubernetes.io/docs/tasks/run-application/force-delete-stateful-set-pod/).

### Upgrade ECK 升级ECK operator

This will trigger a rolling restart on all managed pods.

```
git pull
./bin/upgrade_ECK.sh
```

### Miscs

#### Delete unassigned shards to restore cluster health

**Cautious:** deleteing the unassigned shard is the one last bet to fix your cluster health. You should always try to reaasign or recover the data instead. Here lets only focus on deletion.

- check unassigned shards

```
curl --user elastic:<passwod> -XGET http://<elastichost>:9200/_cluster/health?pretty | grep unassigned_shards
```

- retriev unassigned shards

```
curl -XGET http://<elastichost>:9200/_cat/shards | grep UNASSIGNED | awk {'print $1'}
```

- do it :)

```
curl -XGET http://<elastichost>:9200/_cat/shards | grep UNASSIGNED | awk {'print $1'} | xargs -i curl -XDELETE "http://<elastichost>:9200/{}"
```

#### Clean up
