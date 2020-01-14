#!/bin/bash

# Needs to run as root
# From command line ./07_patch_configmaps_and_secrets.sh

set -ex

export TARGET_PATH=/home/${SSH_USER}/oob_certs

cd ${TARGET_PATH}/cm_secrets; bash apply_cm_secret_script.sh
