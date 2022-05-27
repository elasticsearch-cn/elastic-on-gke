## All in one (aio) scripts, thanks the contribution from Papaya

感谢来自木瓜移动小伙伴的贡献。这个部分会让整个部署过程的控制脚本和配置都集中在2个核心文件，极大的简化了整个流程，也让第一次使用的小伙伴更容易上手。

### 配置文件

`cp conf/example-configure.ini conf/configure.ini`

根据项目需求修改配置文件 `conf/configure.ini`

### 部署

```sh
./bin/deploy.sh -h 查看帮助

```
#### 创建gke集群

`./bin/deploy.sh -m gke -a create`

#### 生成k8s配置

`./bin/deploy.sh -m temp -a debug`
#### 部署es

`./bin/deploy.sh -m es -a deploy`

#### 部署kibana

`./bin/deploy.sh -m kbn -a deploy`

#### 部署lb

*申请lb静态IP*

`./bin/deploy.sh -m glb -a reserve`

*配置dns*

`./bin/deploy.sh -m glb -a dns`

*申请ssl证书*

`./bin/deploy.sh -m glb -a cert`

*部署lb*

`./bin/deploy.sh -m glb -a deploy`