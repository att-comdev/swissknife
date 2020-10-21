#!/bin/bash

# Deletes and restarts pods by order of label in LABELS to accept new configmaps and secrets from previous step
# Run on command line with ./delete_pods.sh

set -x

APP="calico \
    kubernetes"
LABELS="component=coredns \
    component=etcd-anchor \
    component=kubernetes-apiserver-anchor \
    component=kubernetes-controller-manager-anchor \
    component=kubernetes-scheduler-anchor \
    k8s-app=calico-node \
    k8s-app=calico-kube-controllers \
    component=calicoctl-util \
    application=ingress \
    component=ingress
    component=neutron-ovs-agent \
    application=libvirt \
    component=neutron-sriov-agent \
    component=compute \
    release_group=clcp-kubernetes-proxy \
    release_group=clcp-ucp-armada \
    release_group=clcp-ucp-tiller \
    application=kube-state-metrics \
    application=postgresql"

for label in $LABELS;
do
  if [[ $label == "component=etcd-anchor" ]]; then
    for app in $APP;
    do
      readycount=1
      for pod in $(kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml get pods --all-namespaces -l $label,application=$app|awk 'NR>1{print $2}')
      do
        kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml delete pods -n kube-system $pod --grace-period=0 --force
        while true
        do
          readypods=$(kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml get ds -n kube-system $app-etcd-anchor \
            -o jsonpath='{.status.numberReady}')
          if [[ $readypods -ge $readycount ]]; then
            break
          else
            echo "Ready pods $readypods less than Desired pods $readycount, waiting..."
            sleep 15
          fi
        done
      done
    done
  else
    kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml get pods --all-namespaces -l $label | grep -v tenant-ceph | \
      awk 'NR>1{print $1,$2}' | \
      xargs -L 1 kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml delete pod --grace-period=0 --force -n \
    || true
  fi
done
