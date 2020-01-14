#!/bin/bash

# Adds keys to every node in the cluster.  Divingbell must be running in order for this to be successful.
# export root user key SSH_KEY=$(cat /root/.ssh/id_rsa.pub) (actual key here, not directory)
# export <USERNAME> user key MY_SSH_KEY=$(cat /home/<USERNAME>/.ssh/id_rsa.pub) (actual key here, not directory)
# export external key (your localhost ssh key) EXT_SSH_KEY=<LOCAL_PUBLIC_KEY>
# Run as ./04_add_sudoers.sh <USERNAME>

set -ex

export KUBECONFIG=/etc/kubernetes/admin/kubeconfig.yaml

for POD in $(sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml get -n ucp pods -o wide | grep divingbell-exec | awk '{ print $1 }'); do
  if sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "grep -q $1 /etc/passwd" ; then
      echo "user exists on node"
          if sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "test -f /home/$1/.ssh/authorized_keys" ; then
              sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "echo ${SSH_KEY} > /home/$1/.ssh/authorized_keys"
              sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "echo ${MY_SSH_KEY} >> /home/$1/.ssh/authorized_keys"
              if [ -n "$EXT_SSH_KEY" ]; then
                sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "echo ${EXT_SSH_KEY} >> /home/$1/.ssh/authorized_keys"
              else
                echo "WARNING: EXT_SSH_KEY is undefined, you may lose SSH access to this node"
              fi
              echo "public keys added"
              echo $POD
          else
              sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "mkdir -p /home/$1/.ssh"
              sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "echo ${SSH_KEY} > /home/$1/.ssh/authorized_keys"
              sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "echo ${MY_SSH_KEY} >> /home/$1/.ssh/authorized_keys"
              if [ -n "$EXT_SSH_KEY" ]; then
                sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "echo ${EXT_SSH_KEY} >> /home/$1/.ssh/authorized_keys"
              else
                echo "WARNING: EXT_SSH_KEY is undefined, you may lose SSH access to this node"
              fi
              echo "directory created and keys added"
              echo $POD
          fi
  else
      sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "useradd -m -s /bin/bash $1 && mkdir -p /home/$1/.ssh"
      sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "echo ${SSH_KEY} > /home/$1/.ssh/authorized_keys"
      sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "echo ${MY_SSH_KEY} >> /home/$1/.ssh/authorized_keys"
      if [ -n "$EXT_SSH_KEY" ]; then
        sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "echo ${EXT_SSH_KEY} >> /home/$1/.ssh/authorized_keys"
      else
        echo "WARNING: EXT_SSH_KEY is undefined, you may lose SSH access to this node"
      fi
      echo "user $1 added and keys added"
      echo $POD
  fi
  if sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec -t $POD -- nsenter -t1 -m -u -n -i sh -c "ls /usr/localcw/opt/sudo/sudoers.d | grep -q $1_swissknife" ; then
      echo "user already exists in /usr/localcw/opt/sudo/sudoers.d/$1_swissknife"
      echo $POD
  else
      sudo -i kubectl --kubeconfig=/etc/kubernetes/admin/kubeconfig.yaml -n ucp exec $POD -- nsenter -t1 -m -u -n -i sh -c "echo '$SSH_USER ALL=(ALL) NOPASSWD:ALL' > /usr/localcw/opt/sudo/sudoers.d/$1_swissknife"
      echo "user $1 added to /usr/localcw/opt/sudo/sudoers.d/$1_swissknife"
      echo $POD
  fi
done
