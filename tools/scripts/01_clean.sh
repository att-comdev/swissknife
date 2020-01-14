#!/bin/bash

# Removes previously generated documents if applicable
# Regenerates the TARGET_PATH and clones SITE_REPO and GLOBAL_REPO into the TARGET_PATH
# Must be run as user with SSH access to GIT_URL and GIT_SECRETS_URL

set -ex

export SITE_MANIFEST=/home/${SSH_USER}/oob_certs/${SITE_REPO}
export TARGET_PATH=/home/${SSH_USER}/oob_certs

# Clean TARGET_PATH directory from previous run if applicable
rm -r ${TARGET_PATH} || true
mkdir -p ${TARGET_PATH}
cd ${TARGET_PATH}

# Clone necessary repositories
git clone ssh://${SSH_USER}@${GIT_URL}/${SITE_REPO}
cd ${GLOBAL_REPO}
git checkout ${GLOBAL_BRANCH}
