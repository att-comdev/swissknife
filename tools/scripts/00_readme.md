# Airship Certificate Rotation

SwissKnife is a utility to rotate the certificates in an Airship kubernetes 
cluster. It performs the following actions:

  - Makes use of Airship Promenade to generate new certificates
  - Distributes certs to other nodes using an Ansible playbook
  - Generates new ConfigMaps and Secrets for kubernetes
  - Patches existing ConfigMaps and Secrets with new versions
  - Restarts necessary pods to accept the changes that have been made

# Usage

Ansible playbooks use the local IPs in the cluster to communicate. So it is
recommended to run the below scripts from the genesis node.

##  Prerequisites

  - SSH key for ansible to login to the nodes
  - Root access to execute the scripts

# Corridor 1-4

## Export required variables

```
export GIT_URL="opendev.org/airship"
export SSH_USER=<SYSTEM USERNAME>
export SITE_REPO="treasuremap"
export GLOBAL_BRANCH="master"
export SWISSKNIFE_IMAGE=<IMAGE IDENTIFIER>
export SITE=<SITE_NAME>  # Example: seaworthy
export PEGLEG_PASSPHRASE=<SITE PEGLEG PASSPHRASE>
export PEGLEG_SALT=<SITE PEGLEG SALT>
```

## Pull the scripts to your home directory

```
git clone ssh://${SSH_USER}@${GIT_URL}/${SITE_REPO}@${SITE_BRANCH}
cd aic-clcp-manifests
```

## Run Clean-up

This script will remove any data from previous runs of certificate rotation.
It will then download and pre-process the necessary repositories to run
certificate rotation.

```
./01_clean.sh
```

## Decrypt site secrets

Run this script to decrypt the site secrets if applicable.

```
./02_pegleg_decrypt.sh
```

## Set up SSH keys

Check if ssh keys exist for root and yourself. Take note if they exist or not,
you will remove anything that is generated for this process.

```
cat /home/${SSH_USER}/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub
```

### Create SSH keys if necessary

**NOTE:** Do not copy your keys from your localhost.

As root, run ssh-keygen (Leave everything as default when prompted)
As ${SSH_USER}, run ssh-keygen (Leave everything as default when prompted)

### Export the public keys

```
export MY_SSH_KEY=$(cat /home/${SSH_USER}/.ssh/id_rsa.pub)
export SSH_KEY=$(cat /root/.ssh/id_rsa.pub)
export EXT_SSH_KEY=<YOUR_LOCAL_PUBLIC_KEY>
```

## Verify site is stable

```
./03_log_site_status.sh
```

`cat site_status` to make sure everything is in stable condition.

## Run the add_sudoer script

**NOTICE:** Before running this script, check for and disable any cron jobs
(such as `/usr/localcw/uam/uam_auto.pl`) that overwrite user's authorized keys
file or the sudoers file.

This script uses divingbell to put public keys into authorized_keys files on
all hosts and add the ${SSH_USER} to the sudoers file. Divingbell must be
shown as Running in the previous step in order for this to work.

```
./04_add_sudoer.sh ${SSH_USER}
```

## Run certificate rotation script

```
./05_rotate_certs.sh ${SWISSKNIFE_IMAGE}
```

During this script, there will be a number of pauses. During these pauses, 
you can check to make sure certificates and temporary files are generated 
correctly.

To continue, simply press enter.

When the script completes, the logs will be found in
`/home/${SSH_USER}/oob_certs/ansible.log`.

At this point we are waiting for kubectl to come back successfully, pods will
begin to Crash at this point, this is expected.  If you are seeing NodeLost,
the site needs to be investigated before proceeding.

If you do not see any NodeLost, run `sudo -i kubectl get nodes`. If it comes
back successful, proceed to the next step. Otherwise, the site will need to be
investigated before proceeding.

## Generate ConfigMaps (& Secrets)

```
./06_generate_configmaps.sh ${SWISSKNIFE_IMAGE}
```

This will generate files in `/home/${SSH_USER}/oob_certs/cm_secrets`.

## Apply patches using the generated ConfigMap and Secrets

```
./07_patch_configmaps_and_secrets.sh
```

This applies the ConfigMap and Secrets patches generated in the previous step.

## Delete pods

```
./08_delete_pods.sh
```

Wait for the pods to come back up, ~25 minutes.  If they do not all come
back up, escalate to t5 support.

## Unlock certificates

During the rotation of the certificates, we set the certificates and manifests
to have an immutable flag. Now that we have rotated certificates and restarted
the required pods successfully, we can now remove those flags.

```
./09_run_unlock_files.sh
```

## Restart Kubelet services

Run this script to restart kubelet at any point after certificates have been
successfully rotated.

```
./10_run_restart_kubelet.sh ${SWISSKNIFE_IMAGE}
```

## Clean-up

Verify that the site is still stable.

```
sudo -i kubectl get nodes
sudo -i kubectl get pods --all-namespaces
sudo -i kubectl get jobs --all-namespaces
```

### Push the new certificates

Take the certificates generated by Promenade in
`oob_certs/certificates/certificates.yaml` and submit a patchset for ${SITE} in
airship/treasuremap.

### Remove root key from nodes

Run the the last script to remove the root key from the other nodes and reset
the sudoers file.

```
./11_rm_sudoer.sh ${SSH_USER}
```

### Reenable cron jobs

If any cron jobs were disabled earlier, such as `/usr/localcw/uam/uam_auto.pl`,
those jobs should now be reenabled.