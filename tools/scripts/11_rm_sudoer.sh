#!/bin/bash

# Removes root keys in every node in the cluster.
# Divingbell must be running in order for this to be successful.
# export root user key SSH_KEY=$(cat /root/.ssh/id_rsa.pub)
# Run as ./11_rm_sudoer.sh ${SSH_USER}

set -ex

export KUBECONFIG=/etc/kubernetes/admin/kubeconfig.yaml

for POD in $(sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml get -n ucp pods -o wide | grep divingbell-exec | awk '{ print $1 }'); do
  echo $POD
  if sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "test -f /home/$1/.ssh/authorized_keys" ; then
    ssh_key_clean=${SSH_KEY//\//\\/}  # replaces / with \/
    sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "sed -i.bak \"0,/$ssh_key_clean/{/$ssh_key_clean/d;}\" /home/$1/.ssh/authorized_keys"
    echo "root key removed"
  else
    echo "authorized_keys file not found at /home/$1/.ssh/authorized_keys"
  fi
  if sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "ls /usr/localcw/opt/sudo/sudoers.d | grep -q $1_swissknife" ; then
    sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec $POD -- nsenter -t1 -m -u -n -i sh -c "rm /usr/localcw/opt/sudo/sudoers.d/$1_swissknife"
  else
    echo "User not in /usr/localcw/opt/sudo/sudoers.d/$1_swissknife"
  fi
done
