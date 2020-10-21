#!/usr/bin/python

import os
import sys

import yaml

ansible_shell = "/usr/localcw/bin/eksh"

# List of host profiles from site manifests containing 'cp'
CONTROL_PROFILES = [
    'cd-cp-master-primary',
    'cd-cp-master-secondary',
    'cd-cp-worker-data',
    'cd-cp-worker-search',
    'ch-cp-master-primary',
    'ch-cp-master-secondary',
    'ch-cp-worker',
    'ch-cp-worker-data',
    'ch-cp-worker-search',
    'cloudharbor-cp-primary',
    'cloudharbor-cp-secondary',
    'cp_master',
    'cp_r640-primary',
    'cp_r640-secondary',
    'cp_r740-primary',
    'cp_r740-secondary',
    'cp_rack04',
    'cp_rack05dell',
    'cp_rack05hp',
    'cp_rack10dell_master',
    'cp_rack10hp_worker',
    'cp_rack11_master',
    'cp_rack11_worker',
    'cp_worker',
    'cp-cab24',
    'cp-master',
    'cp-master-dell',
    'cp-master-hp',
    'cp-rack07-master',
    'cp-rack07-worker',
    'cp-rack07-worker-r630',
    'cp-rack08-master',
    'cp-rack09-master',
    'cp-rack09-worker',
    'cp-rack10-master',
    'cp-rack10-worker',
    'cp-rack11-master',
    'cp-rack11-worker',
    'cp-worker-dell',
    'nc-cp-primary',
    'nc-cp-primary-730-adv',
    'nc-cp-primary-adv',
    'nc-cp-secondary',
    'nc-cp-secondary-730-adv',
    'nc-cp-secondary-adv',
]

# compute buckets we create groups for
GENESIS = "genesis"
CONTROL = "control"
COMPUTE = "compute"
BUCKETS = [GENESIS, CONTROL, COMPUTE]

site_dir = sys.argv[1]
ansible_user = sys.argv[2]

nodes_file = "%s/baremetal/nodes.yaml" % site_dir
rack_file = "%s/baremetal/rack.yaml" % site_dir
common_addresses_file = "%s/network/common-addresses.yaml" % site_dir
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


def extract_site_domain(fpath):
    # process common_addresses to get site domain
    domain = ""
    r = yaml.load_all(open(fpath).read())
    docs = [d for d in r]
    for d in docs:
        if "data" not in d or "dns" not in d["data"]:
            continue
        domain = d["data"]["dns"]["node_domain"]

    if domain == "":
        print("Site domain was not found. Expected in format of "
              "${SITE}.cci.att.com")
        print("Please update common-addresses.data.dns.node_domain "
              "with the Site domain.")
        sys.exit(1)
    return domain


# Determine domain name of the site to construct FQDN for each node
site_domain = extract_site_domain(common_addresses_file)

# determine whether this is an NC1.x or 5EC type file layout

# Some 5EC sites have nodes file instead of rack file but no
# control address file.
# Precedence - rack file over nodes file
#            - control address file over common address file

if os.path.exists(rack_file):
    nodes.update(process_baremetalnode_file(rack_file))
else:
    nodes.update(process_baremetalnode_file(nodes_file))

if os.path.exists(control_address_file):
    nodes.update(process_control_address_file(control_address_file))
else:
    nodes.update(process_common_addresses_file(common_addresses_file))
"""
# 5EC
if os.path.exists(rack_file):

    nodes.update(process_baremetalnode_file(rack_file))
    nodes.update(process_common_addresses_file(common_addresses_file))

# NC
else:
    nodes.update(process_baremetalnode_file(nodes_file))
    nodes.update(process_control_address_file(control_address_file))
"""

print("[all_control:children]")
print("genesis")
print("control")
for bucket in BUCKETS:
    print("")
    print("[%s]" % bucket)
    for n in nodes.keys():
        if nodes[n]["profile"] == bucket:
            fqdn = n + "." + site_domain

            print("%s ansible_host=%s ansible_port=22 ansible_user=%s "
                  "profile=%s ansible_shell_executable=%s" %
                  (n, fqdn, ansible_user, nodes[n]["oprofile"], ansible_shell))
