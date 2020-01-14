import json
import logging
import os
import sys

import yaml

logging.basicConfig(filename='generate_cert.log',
                    format='%(asctime)s:%(levelname)s:%(message)s',
                    level=logging.DEBUG)

# import site_dir_inventory

# site_dir = sys.argv[3]
# ansible_user = sys.argv[4]

node_group = sys.argv[1]
mappings_file = sys.argv[2]

GENESIS = "genesis"
CONTROL = "control"
COMPUTE = "compute"
BUCKETS = [GENESIS, CONTROL, COMPUTE]

CONTROL_PROFILES = [
    "cp_master", "cp_worker", "cp_r720-primary",
    "cp_r640-primary", "cp_r640-secondary", "cp_r740-primary",
    "cp_r740-secondary"
]


def process_baremetalnode_file(fpath):
    # process nodes_file
    nodes = {}
    r = yaml.load_all(open(fpath).read())
    docs = [d for d in r]
    for d in docs:
        if "data" not in d or "addressing" not in d["data"]:
            continue
        for record in d["data"]["addressing"]:
            if record["network"] == "oam":
                hostname = d["metadata"]["name"]
                profile = d["data"]["host_profile"]
                if profile in CONTROL_PROFILES:
                    profile = CONTROL
                else:
                    profile = COMPUTE
                nodes[hostname] = {
                    'address': record["address"],
                    'profile': profile,
                }
    return nodes


nodes_file = "/opt/site-manifests/baremetal/nodes.yaml"
rack_file = "/opt/site-manifests/baremetal/rack.yaml"
if os.path.exists(rack_file):
    nodes_file = rack_file

baremetal_nodes = process_baremetalnode_file(nodes_file)
if not node_group:
    logging.error(
        "node_group argument not found. Valid options are 'control', 'compute'"
    )

if not mappings_file:
    logging.error("mappings_file argument not found.")

certs = []

with open('/target/certificates/certificates.yaml', 'r') as input_file:
    data = yaml.load_all(input_file)
    for value in data:
        certs.append(value)

map_file = open(mappings_file, 'r')
mappings = json.loads(map_file.read())

nodes_mappings = {}

if os.path.exists(
        '/opt/site-manifests/network/control-plane-addresses.yaml'):
    control_plane_nodes_file = open(
        '/opt/site-manifests/network/control-plane-addresses.yaml',
        'r')
    controle_plane_nodes_raw = control_plane_nodes_file.read()
    control_plane_nodes_file.close()
    controle_plane_nodes = yaml.load(controle_plane_nodes_raw)

    nodes_mappings['genesis'] = controle_plane_nodes['data']['genesis'][
        'hostname']
    for index, node in enumerate(controle_plane_nodes['data']['masters']):
        nodes_mappings['master-%s' % index] = node['hostname']

    for index, node in enumerate(baremetal_nodes):
        if baremetal_nodes[node]['profile'] == "compute":
            nodes_mappings['compute-%s' % index] = node
else:
    with open('/opt/site-manifests/networks/common-addresses.yaml',
              'r') as genesis_node_file:
        # Need to change yaml load to safe methods
        genesis_node = yaml.load(genesis_node_file.read())
        nodes_mappings['genesis'] = genesis_node['data']['genesis']['hostname']
        nodes_mappings['master-0'] = genesis_node['data']['genesis'][
            'hostname']

    index_controller = 1
    index_compute = 0
    for index, node in enumerate(baremetal_nodes):
        if baremetal_nodes[node]['profile'] == "control":
            nodes_mappings['master-%s' % index_controller] = node
            index_controller += 1
        elif baremetal_nodes[node]['profile'] == "compute":
            nodes_mappings['compute-%s' % index_compute] = node
            index_compute += 1

for map in mappings:
    for cert in certs:
        if cert['schema'] == map['schema'] and cert['metadata']['name'] in map:

            if len(map[cert['metadata']['name']]) > 0:

                for path in map[cert['metadata']['name']]:
                    node_name = node_group
                    # print(nodes_mappings)
                    for name in nodes_mappings:
                        if name in cert['metadata']['name'] \
                                or nodes_mappings[name] \
                                in cert['metadata']['name']:
                            node_name = nodes_mappings[name]
                            break

                    target_path = "%s/certs/%s%s" % (os.getcwd(), node_name,
                                                     path)
                    target_dir = os.path.dirname(target_path)
                   os.makedirs(target_dir, exist_ok=True)
                    if os.path.exists(target_path):
                        append_write = 'a'
                    else:
                        append_write = 'w'
                    cert_file = open(target_path, append_write)
                    cert_file.write(cert['data'])
