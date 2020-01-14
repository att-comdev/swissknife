#!/usr/bin/python

import os
import sys

import yaml

# known control plane profiles we may find in yaml
CONTROL_PROFILES = [
    "cp_master", "cp_worker", "cp_r720-primary",
    "cp_r640-primary", "cp_r640-secondary", "cp_r740-primary",
    "cp_r740-secondary"
]

# compute buckets we create groups for
GENESIS = "genesis"
CONTROL = "control"
COMPUTE = "compute"
BUCKETS = [GENESIS, CONTROL, COMPUTE]

site_dir = sys.argv[1]
ansible_user = sys.argv[2]
ansible_ssh_password = None
if len(sys.argv) >= 4:
    ansible_ssh_password = sys.argv[3]

nodes_file = "%s/baremetal/nodes.yaml" % site_dir
rack_file = "%s/baremetal/rack.yaml" % site_dir
common_addresses_file = "%s/networks/common-addresses.yaml" % site_dir
control_address_file = "%s/network/control-plane-addresses.yaml" % site_dir

# init empty node
nodes = {}


def process_baremetalnode_file(fpath):
    # process nodes_file
    node = {}
    r = yaml.load_all(open(fpath).read())
    docs = [d for d in r]
    for d in docs:
        if "data" not in d or "addressing" not in d["data"]:
            continue
        for record in d["data"]["addressing"]:
            if record["network"] == "calico" or record["network"] == "ksn":
                hostname = d["metadata"]["name"]
                profile = d["data"]["host_profile"]
                if profile in CONTROL_PROFILES:
                    profile = CONTROL
                else:
                    profile = COMPUTE
                node[hostname] = {
                    'address': record["address"],
                    'profile': profile,
                    'oprofile': d["data"]["host_profile"]
                }
    return node


def process_control_address_file(fpath):
    # process control-plane-addresses to get genesis
    node = {}
    r = yaml.load_all(open(fpath).read())
    docs = [d for d in r]
    for d in docs:
        if "data" not in d or "genesis" not in d["data"]:
            continue
        hostname = d["data"]["genesis"]["hostname"]
        address = d["data"]["genesis"]["ip"]["ksn"]
        profile = GENESIS
        node[hostname] = {
            'address': address,
            'profile': profile,
            'oprofile': 'genesis'
        }

    return node


def process_common_addresses_file(fpath):
    # process common_addresses to get genesis ip
    node = {}
    r = yaml.load_all(open(fpath).read())
    docs = [d for d in r]
    for d in docs:
        if "data" not in d or "genesis" not in d["data"]:
            continue
        hostname = d["data"]["genesis"]["hostname"]
        address = d["data"]["genesis"]["ip"]
        profile = GENESIS
        node[hostname] = {
            'address': address,
            'profile': profile,
            'oprofile': 'genesis'
        }

    return node


if os.path.exists(rack_file):
    nodes.update(process_baremetalnode_file(rack_file))
else:
    nodes.update(process_baremetalnode_file(nodes_file))

if os.path.exists(control_address_file):
    nodes.update(process_control_address_file(control_address_file))
else:
    nodes.update(process_common_addresses_file(common_addresses_file))

print("[all_control:children]")
print("genesis")
print("control")
for bucket in BUCKETS:
    print("")
    print("[%s]" % bucket)
    for n in nodes.keys():
        if nodes[n]["profile"] == bucket:
            if ansible_ssh_password:
                print(
                    "%s ansible_host=%s ansible_port=22 ansible_user=%s "
                    "ansible_password=%s profile=%s"
                    % (
                    n, nodes[n]["address"], ansible_user, ansible_ssh_password,
                    nodes[n]["oprofile"]))
            else:
                print(
                    "%s ansible_host=%s ansible_port=22 ansible_user=%s "
                    "profile=%s"
                    % (n, nodes[n]["address"], ansible_user,
                       nodes[n]["oprofile"]))
