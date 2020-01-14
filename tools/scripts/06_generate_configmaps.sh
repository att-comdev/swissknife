#!/bin/bash

# Needs to run as root
# export SITE=<SITE_NAME>
# From command line ./06_generate_configmaps.sh ${SWISSKNIFE_IMAGE_URL}

set -ex

export TARGET_PATH=/home/${SSH_USER}/oob_certs
export SITE_MANIFEST=/home/${SSH_USER}/oob_certs/${SITE_REPO}/site/${SITE}
export PRIVATE_KEY=/root/.ssh/id_rsa

mkdir -p ${TARGET_PATH}
cp ${SITE_MANIFEST}/secrets/certificates/ingress.yaml ${TARGET_PATH}/certificates/ingress.yaml

docker run --net=host -u root --rm -it \
  -v ${TARGET_PATH}:/target \
  -v ${SITE_MANIFEST}:/opt/site-manifests \
  -v ${PRIVATE_KEY}:/root/.ssh/id_rsa \
  -e "ansible_user=${SSH_USER}" $1 generate_config_maps
