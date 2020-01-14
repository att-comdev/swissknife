#!/bin/bash

# Run on command line with ./09_run_unlock_files.sh
# Need SSH access to all nodes to run script successfully

set -ex

export TARGET_PATH=/home/${SSH_USER}/oob_certs
export SITE_MANIFEST=/home/${SSH_USER}/oob_certs/${SITE_REPO}/site/${SITE}
export PRIVATE_KEY=/root/.ssh/id_rsa

for NODE in $(sudo -i kubectl get nodes -o wide | awk '{print $6}' | sed -n '1!p' | tr "\n" " " | xargs)
do
  ssh -o StrictHostKeyChecking=no "${SSH_USER}@${NODE}" sudo systemctl restart kubelet
done
