#!/bin/bash

# Needs to run as root
# export SITE=<SITE_NAME>
# From command line ./06_generate_configmaps.sh ${SWISSKNIFE_IMAGE_URL}

set -ex

export TARGET_PATH=/home/${SSH_USER}/oob_certs
export GLOBAL_MANIFEST=${TARGET_PATH}/${GLOBAL_REPO}
export SITE_MANIFEST=${TARGET_PATH}/${SITE_REPO}/site/${SITE}
export SECRETS_MANIFEST=${TARGET_PATH}/${SECRETS_REPO}
export PRIVATE_KEY=/root/.ssh/id_rsa

mkdir -p ${TARGET_PATH}
cp ${SITE_MANIFEST}/secrets/certificates/ingress.yaml ${TARGET_PATH}/certificates/ingress.yaml

docker run --net=host -u root --rm -it \
  -v ${TARGET_PATH}:/target \
  -v ${SITE_MANIFEST}:/opt/site-manifests \
  -v ${GLOBAL_MANIFEST}:/opt/global-manifests \
  -v ${SECRETS_MANIFEST}:/opt/secrets-manifests \
  -v ${PRIVATE_KEY}:/root/.ssh/id_rsa \
  -e "ansible_user=${SSH_USER}" $1 generate_config_maps
