#!/bin/bash

# Must be run as root in order to access docker daemon

export SITE_MANIFEST=/home/${SSH_USER}/oob_certs/${SITE_REPO}
export PEGLEG_IMAGE_URL="quay.io/airshipit/pegleg@sha256:83915012fb656ef7885e00ea21979c77768574e7b6002b37012eb14342982af7"

# Decrypt site secrets for use in later steps
docker run --rm -it -e PEGLEG_PASSPHRASE="${PEGLEG_PASSPHRASE}" -e PEGLEG_SALT="${PEGLEG_SALT}" \
  -v ${SITE_MANIFEST}:/opt/site-manifests \
  pegleg -v site -r /opt/site-manifests \
  secrets decrypt ${SITE} --path /opt/site-manifests/site/${SITE} -o
