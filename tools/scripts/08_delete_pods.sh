#!/bin/bash

# Deletes and restarts pods by order of label in LABELS to accept new configmaps and secrets from previous step
# Run on command line with ./08_delete_pods.sh

set -ex

LABELS="component=coredns \
    component=etcd-anchor \
    component=kubernetes-apiserver-anchor \
    component=kubernetes-controller-manager-anchor \
    component=kubernetes-scheduler-anchor \
    k8s-app=calico-node \
    k8s-app=calico-kube-controllers \
    component=calicoctl-util \
    application=ingress \
    component=neutron-ovs-agent \
    application=libvirt \
    component=neutron-sriov-agent \
    component=compute"
export KUBECONFIG=/etc/kubernetes/admin/kubeconfig.yaml

for label in $LABELS;
do
  sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml get pods --all-namespaces -l $label | \
    awk 'NR>1{print $1,$2}' | \
    xargs -L 1 sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml delete pod --grace-period=0 --force -n \
    || true
done
