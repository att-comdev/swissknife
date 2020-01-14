#!/bin/bash

# Removes previously generated documents if applicable
# Regenerates the TARGET_PATH and clones SITE_REPO and GLOBAL_REPO into the TARGET_PATH
# Must be run as user with SSH access to GIT_URL and GIT_SECRETS_URL

set -ex

export TARGET_PATH=/home/${SSH_USER}/oob_certs
export SITE_MANIFEST=${TARGET_PATH}/${SITE_REPO}
export SECRETS_MANIFEST=${TARGET_PATH}/${SECRETS_REPO}
export GLOBAL_MANIFEST=${TARGET_PATH}/${GLOBAL_REPO}

# Clean TARGET_PATH directory from previous run if applicable
rm -r ${TARGET_PATH} || true
mkdir -p ${TARGET_PATH}
cd ${TARGET_PATH}

# Clone necessary repositories
git clone ssh://${SSH_USER}@${GIT_SITE_URL}/${SITE_REPO}
git clone ssh://${SSH_USER}@${GIT_SECRETS_URL}/${SECRETS_REPO}
git clone ssh://${SSH_USER}@${GIT_GLOBAL_URL}/${GLOBAL_REPO}
cd ${GLOBAL_REPO}
git checkout ${GLOBAL_BRANCH}
