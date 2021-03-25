# /usr/bin/env python3

# Author: Kasen <kasen@outlook.com>

# pip install PyYAML
# pip install deepdiff
import yaml
import os
import re
import copy
import aio_temp as temp
from deepdiff import DeepDiff
from pprint import pprint
import argparse


parser = argparse.ArgumentParser()

parser.add_argument('--debug', '-d', help='打印修改的内容',action='store_true', default=False)

args = parser.parse_args()


pwd = os.getenv('PWD', '.')
config_file = pwd + '/conf/' + 'configure.ini'
deploy_path = pwd + '/deploy/'

if not os.path.isdir(deploy_path):
    os.mkdir(deploy_path)


config = {}
with open(config_file) as myfile:
    for line in myfile.readlines():
        if re.search(r'^\w', line) is not None:
            name, var = line.partition('=')[::2]
            config[name.strip()] = var.strip()

# 包含_COUNT转换为数字类型
for k in config.keys():
    if k.find('_COUNT') != -1:
        config[k] = int(config.get(k))

templates_path = pwd + '/' + 'templates' + '/'


def load(f):
    with open(f) as fd:
        temp_load = yaml.load(fd, Loader=yaml.FullLoader)
    return temp_load


def load_all(f):
    t = []
    with open(f) as fd:
        temp_load = yaml.load_all(fd, Loader=yaml.FullLoader)
        for i in temp_load:
            t.append(i)
    return t


def dump(f, s):
    with open(f, 'w') as fd:
        yaml.dump(s, fd)


def dump_all(f, s):
    with open(f, 'w') as fd:
        yaml.dump_all(s, fd)


def print_diff(old_dict, new_dict, desc):
    diff = DeepDiff(old_dict, new_dict)
    if args.debug:
        print(desc)
        pprint(diff)


def generate_apm():
    fp = templates_path + 'apm.yml'
    s = load(fp)
    s['spec']['version'] = config.get('ES_VERSION')
    s['spec']['elasticsearchRef']['name'] = config.get('ES_CLUSTER_NAME')
    dump(deploy_path + 'apm.yml', s)
    print_diff(load(fp), s, '对比 apm.yml 修改的部分')


def generate_cert():
    fp = templates_path + 'cert.yml'
    s = load(fp)
    s['metadata']['name'] = config.get('K8S_CERT_NAME')

    s['spec']['domains'] = [config.get('K8S_ES_INGRESS_DOMAINS'), config.get(
        'K8S_ES_COODR_DOMAINS'), config.get('K8S_ES_KIBANA_DOMAINS')]

    dump(deploy_path + 'cert.yml', s)
    print_diff(load(fp), s, '对比 cert.yml 修改的部分')


def generate_es_all_role():

    fp = templates_path + 'es.all_role.yml'
    s = load(fp)

    s['metadata']['name'] = config.get('ES_CLUSTER_NAME')

    s['spec']['version'] = config.get('ES_VERSION')

    s['spec']['secureSettings'][0]['secretName'] = config.get(
        'K8S_SECRENAME_NAME')

    # set mutile zone
    m_zone = copy.deepcopy(s['spec']['nodeSets'][0])
    s['spec']['nodeSets'] = []

    GKE_NODE_ZONE = config.get('GKE_NODE_ZONE')

    if GKE_NODE_ZONE != None:
        if GKE_NODE_ZONE.find('$') != -1:
            GKE_NODE_ZONE.replace('$', '')
            GKE_NODE_ZONE = re.sub(r'\$', '', GKE_NODE_ZONE)
            config['GKE_NODE_ZONE'] = config.get(GKE_NODE_ZONE)

    for z in config.get('GKE_NODE_ZONE').split(','):
        t_zone = copy.deepcopy(m_zone)
        t_zone['name'] = 'zone-' + z

        t_zone['count'] = config.get('ES_CLUSTER_SIZE_COUNT', 1)

        t_zone['config']['node.attr.zone'] = z
        # set disk size
        t_zone['volumeClaimTemplates'][0]['spec']['resources']['requests']['storage'] = config.get(
            'ES_ALL_ROLE_DISK_SIZE', '100Gi')

        t_zone['podTemplate']['spec']['affinity']['podAntiAffinity']['preferredDuringSchedulingIgnoredDuringExecution'][0][
            'podAffinityTerm']['labelSelector']['matchLabels']['elasticsearch.k8s.elastic.co/cluster-name'] = config.get('ES_CLUSTER_NAME')

        t_zone['podTemplate']['spec']['affinity']['nodeAffinity']['requiredDuringSchedulingIgnoredDuringExecution']['nodeSelectorTerms'][0]['matchExpressions'][0]['values'][0] = z

        s['spec']['nodeSets'].append(t_zone)

    dump(deploy_path + 'es.all_role.yml', s)
    print_diff(load(fp), s, '对比 es.all_role.yml 修改的部分')


def generate_es_prod():
    fp = templates_path + 'es.prod.yml'
    s = load(fp)

    s['metadata']['name'] = config.get('ES_CLUSTER_NAME')

    s['spec']['version'] = config.get('ES_VERSION')

    s['spec']['secureSettings'][0]['secretName'] = config.get(
        'K8S_SECRENAME_NAME')

    es_master_node = {}
    es_data_node = {}
    es_ingest_node = {}
    es_coord_node = {}
    es_ml_node = {}
    for i in s['spec']['nodeSets']:
        if i['config']['node.master']:

            es_master_node = copy.deepcopy(i)
        elif i['config']['node.data']:

            es_data_node = copy.deepcopy(i)
        elif i['config']['node.ingest']:

            es_ingest_node = copy.deepcopy(i)
        elif i['config']['node.ml']:
            es_ml_node = copy.deepcopy(i)

        else:

            es_coord_node = copy.deepcopy(i)

    GKE_NODE_ZONE = config.get('GKE_NODE_ZONE')

    if GKE_NODE_ZONE != None:
        if GKE_NODE_ZONE.find('$') != -1:
            GKE_NODE_ZONE.replace('$', '')
            GKE_NODE_ZONE = re.sub(r'\$', '', GKE_NODE_ZONE)
            config['GKE_NODE_ZONE'] = config.get(GKE_NODE_ZONE)
    s['spec']['nodeSets'] = []
    for z in config.get('GKE_NODE_ZONE').split(','):
        # master
        es_master_node['name'] = 'zone-%s-master' % z
        es_master_node['count'] = config.get('ES_CLUSTER_MASTER_COUNT', 3)
        es_master_node['config']['node.attr.zone'] = z
        es_master_node['volumeClaimTemplates'][0]['spec']['resources']['requests']['storage'] = config.get(
            'ES_PROD_MASTER_DISK_SIZE', '80Gi')
        es_master_node['podTemplate']['spec']['affinity']['podAntiAffinity']['preferredDuringSchedulingIgnoredDuringExecution'][0][
            'podAffinityTerm']['labelSelector']['matchLabels']['elasticsearch.k8s.elastic.co/cluster-name'] = config.get('ES_CLUSTER_NAME')
        es_master_node['podTemplate']['spec']['affinity']['nodeAffinity'][
            'requiredDuringSchedulingIgnoredDuringExecution']['nodeSelectorTerms'][0]['matchExpressions'][0]['values'] = [z]

        # data
        es_data_node['name'] = 'zone-%s-data' % z
        es_data_node['count'] = config.get('ES_CLUSTER_DATA_COUNT', 3)
        es_data_node['config']['node.attr.zone'] = z
        es_data_node['volumeClaimTemplates'][0]['spec']['resources']['requests']['storage'] = config.get(
            'ES_PROD_DATA_DISK_SIZE', '512Gi')
        es_data_node['podTemplate']['spec']['affinity']['podAntiAffinity']['preferredDuringSchedulingIgnoredDuringExecution'][0][
            'podAffinityTerm']['labelSelector']['matchLabels']['elasticsearch.k8s.elastic.co/cluster-name'] = config.get('ES_CLUSTER_NAME')
        es_data_node['podTemplate']['spec']['affinity']['nodeAffinity']['requiredDuringSchedulingIgnoredDuringExecution']['nodeSelectorTerms'][0]['matchExpressions'][0]['values'] = [z]

        # ingest
        es_ingest_node['name'] = 'zone-%s-ingest' % z
        es_ingest_node['count'] = config.get('ES_CLUSTER_INGEST_COUNT', 3)
        es_ingest_node['config']['node.attr.zone'] = z
        es_ingest_node['volumeClaimTemplates'][0]['spec']['resources']['requests']['storage'] = config.get(
            'ES_PROD_INGEST_DISK_SIZE', '40Gi')
        es_ingest_node['podTemplate']['spec']['affinity']['podAntiAffinity']['preferredDuringSchedulingIgnoredDuringExecution'][0][
            'podAffinityTerm']['labelSelector']['matchLabels']['elasticsearch.k8s.elastic.co/cluster-name'] = config.get('ES_CLUSTER_NAME')
        es_ingest_node['podTemplate']['spec']['affinity']['nodeAffinity'][
            'requiredDuringSchedulingIgnoredDuringExecution']['nodeSelectorTerms'][0]['matchExpressions'][0]['values'] = [z]

        # coord
        es_coord_node['name'] = 'zone-%s-coord' % z
        es_coord_node['count'] = config.get('ES_CLUSTER_COORD_COUNT', 3)
        es_coord_node['config']['node.attr.zone'] = z
        es_coord_node['volumeClaimTemplates'][0]['spec']['resources']['requests']['storage'] = config.get(
            'ES_PROD_COORD_DISK_SIZE', '40Gi')
        es_coord_node['podTemplate']['spec']['affinity']['podAntiAffinity']['preferredDuringSchedulingIgnoredDuringExecution'][0][
            'podAffinityTerm']['labelSelector']['matchLabels']['elasticsearch.k8s.elastic.co/cluster-name'] = config.get('ES_CLUSTER_NAME')
        es_coord_node['podTemplate']['spec']['affinity']['nodeAffinity']['requiredDuringSchedulingIgnoredDuringExecution']['nodeSelectorTerms'][0]['matchExpressions'][0]['values'] = [z]

        s['spec']['nodeSets'].extend([es_master_node,    es_data_node,    es_ingest_node,
                                      es_coord_node,
                                      es_ml_node])

    # ml
    es_ml_node['name'] = 'zone-ml'
    es_ml_node['count'] = config.get('ES_CLUSTER_ML_COUNT', 3)
    es_ml_node['volumeClaimTemplates'][0]['spec']['resources']['requests']['storage'] = config.get(
        'ES_PROD_COORD_DISK_SIZE', '40Gi')
    es_ml_node['podTemplate']['spec']['affinity']['podAntiAffinity']['preferredDuringSchedulingIgnoredDuringExecution'][0][
        'podAffinityTerm']['labelSelector']['matchLabels']['elasticsearch.k8s.elastic.co/cluster-name'] = config.get('ES_CLUSTER_NAME')

    s['spec']['nodeSets'].append(es_ml_node)

    dump(deploy_path + 'es.prod.yml', s)
    print_diff(load(fp), s, '对比 es.prod.yml 修改的部分')


def generate_es_single_node():
    fp = templates_path + 'es.single_node.yml'
    s = load(fp)

    s['metadata']['name'] = config.get('ES_CLUSTER_NAME')

    s['spec']['version'] = config.get('ES_VERSION')

    s['spec']['secureSettings']['secretName'] = config.get(
        'K8S_SECRENAME_NAME')

    s['spec']['nodeSets'][0]['name'] = [config.get('ES_CLUSTER_NAME')]

    s['spec']['nodeSets'][0]['volumeClaimTemplates'][0]['spec']['resources']['requests']['storage'] = [
        config.get('ES_DISK_SIZE', '10Gi')]

    dump(deploy_path + 'es.single_node.yml', s)
    print_diff(load(fp), s, '对比 es.single_node.yml 修改的部分')


def generate_kbn():
    fp = templates_path + 'kbn.yml'
    s = load(fp)

    s['metadata']['name'] = config.get('K8S_KIBANA_METADATA_NAME')

    s['spec']['version'] = config.get('ES_VERSION')
    s['spec']['elasticsearchRef']['name'] = config.get('ES_CLUSTER_NAME')

    dump(deploy_path + 'kbn.yml', s)
    print_diff(load(fp), s, '对比 kbn.yml 修改的部分')


def generate_lb():
    fp = templates_path + 'lb.yml'
    s = load_all(fp)

    for i in s:
        if i['kind'] == 'Service':
            if i['spec']['selector'].get('ingest') == 'on':
                i['metadata']['name'] = config.get('K8S_ES_INGEST_SVC_NAME')
                i['spec']['selector']['elasticsearch.k8s.elastic.co/cluster-name'] = config.get(
                    'ES_CLUSTER_NAME')
            elif i['spec']['selector'].get('coord') == 'on':
                i['metadata']['name'] = config.get('K8S_ES_COODR_SVC_NAME')
                i['spec']['selector']['elasticsearch.k8s.elastic.co/cluster-name'] = config.get(
                    'ES_CLUSTER_NAME')
            elif i['spec']['selector'].get('k8na') == 'on':
                i['metadata']['name'] = config.get('K8S_KIBANA_SVC_NAME')
                i['metadata']['annotations']['cloud.google.com/backend-config'] = '{"ports": {"5601":"%s-bc"}}' % config.get('K8S_KIBANA_SVC_NAME')
        elif i['kind'] == 'BackendConfig':
            i['metadata']['name'] = config.get('K8S_KIBANA_SVC_NAME') + '-bc'
        elif i['kind'] == 'Ingress':
            i['metadata']['name'] = config.get('K8S_INGRESS_NAME')
            i['metadata']['annotations']['kubernetes.io/ingress.global-static-ip-name'] = config.get(
                'GCIP_NAME')
            i['metadata']['annotations']['networking.gke.io/managed-certificates'] = config.get(
                'K8S_CERT_NAME')

            for n, h in enumerate(i['spec']['rules']):
                # h = 'aa'
                if h['host'].find('ingest') != -1:
                    i['spec']['rules'][n]['host'] = config.get(
                        'K8S_ES_INGRESS_DOMAINS')
                    i['spec']['rules'][n]['http']['paths'][0]['backend']['serviceName'] = config.get(
                        'K8S_ES_INGEST_SVC_NAME')

                elif h['host'].find('client') != -1:
                    i['spec']['rules'][n]['host'] = config.get(
                        'K8S_ES_COODR_DOMAINS')
                    i['spec']['rules'][n]['http']['paths'][0]['backend']['serviceName'] = config.get(
                        'K8S_ES_COODR_SVC_NAME')

                elif h['host'].find('k8na') != -1:
                    i['spec']['rules'][n]['host'] = config.get(
                        'K8S_ES_KIBANA_DOMAINS')
                    i['spec']['rules'][n]['http']['paths'][0]['backend']['serviceName'] = config.get(
                        'K8S_KIBANA_SVC_NAME')

            # if i['spec']['tls']:
            #     i['spec']['tls'][0]['hosts'] = [config.get(
            #         'K8S_ES_INGRESS_DOMAINS'), config.get(
            #         'K8S_ES_COODR_DOMAINS'), config.get(
            #         'K8S_ES_KIBANA_DOMAINS')]

    dump_all(deploy_path + 'lb.yml', s)
    print_diff(load_all(fp), s, '对比 lb.yml 修改的部分')


def generate_snapshotter():
    fp = templates_path + 'snapshotter.yml'
    s = load(fp)

    dump(deploy_path + 'snapshotter.yml', s)
    print_diff(load(fp), s, '对比 snapshotter.yml 修改的部分')


if __name__ == "__main__":

    generate_apm()
    generate_cert()

    # select es cluster type
    if config.get('ES_CLUSTER_TYPE'):
        g = 'generate_es_' + config.get('ES_CLUSTER_TYPE')
    else:
        g = ''
    s = getattr(temp, g, 'all_role')
    s()

    generate_kbn()
    generate_lb()
    generate_snapshotter()

    print('k8s配置完成')