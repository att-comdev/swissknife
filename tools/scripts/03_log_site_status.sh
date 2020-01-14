#!/bin/bash

# Needs to run as root
# From command line ./03_log_site_status.sh

sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml get pods --all-namespaces -o wide | sudo tee site_status
sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml get nodes --all-namespaces -o wide | sudo tee -a site_status
sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml get jobs --all-namespaces | sudo tee -a site_status