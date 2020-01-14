#!/bin/bash
set -ex

RUN_CHATTR=false

ANSIBLE_USER=${ansible_user:-ubuntu}
ANSIBLE_SSH_PASS=${ansible_ssh_pass}
ANSIBLE_LOG_FILE=${ansible_log_file:-/target/ansible.log}
GLOBAL_MANIFESTS=${GLOBAL_MANIFESTS:-global-manifests}
SITE_MANIFESTS=${SITE_MANIFESTS:-site-manifests}
SECRETS_MANIFESTS=${SECRETS_MANIFESTS:-secrets-manifests}
SITE_TYPE=${SITE_TYPE:-foundry}

function_kubectl() {
  export KUBECONFIG=/etc/kubernetes/admin/kubeconfig.yaml
  if [ ! -f $HOME/kubectl ]; then
    CONTAINER=$(docker create "$(awk '/hyperkube-amd64/ { print $1 ; exit }' /usr/local/bin/kubectl)")
    docker cp "$CONTAINER:/hyperkube" "$HOME/kubectl"
    chmod +x "$HOME/kubectl"
    docker rm "$CONTAINER"
  fi
  $HOME/kubectl $1
}

function_restart_kubelet() {
  for node in ${@:2};
  do
    echo $(ssh ${ANSIBLE_USER}@${node} sudo systemctl status kubectl)
    ssh ${ANSIBLE_USER}@${node} sudo systemctl restart kubectl
    echo $(ssh ${ANSIBLE_USER}@${node} sudo systemctl status kubectl)
  done
}

function_unlock_k8s_manifests() {
    pushd  /workdir/ansible/
    ansible-playbook -i /target/inventory.ini playbooks/unlock_k8s_manifests.yaml | tee -a $ANSIBLE_LOG_FILE
    popd
}

function_distribute_certs() {


	if [ ! -f /target/inventory.ini ]; then
		python3 /opt/bin/site-dir-inventory.py /opt/$SITE_MANIFESTS $ANSIBLE_USER  $ANSIBLE_SSH_PASS > /target/inventory.ini
	fi

	if [ ! -f /target/certificates/certificates.yaml ]; then

	    mkdir -p /workdir/gen_certs
	    pushd /workdir/gen_certs
	    cp /opt/${GLOBAL_MANIFESTS}/type/${SITE_TYPE}/pki/* ./ || true
	    cp /opt/${SITE_MANIFESTS}/network/co* ./ || true
	    cp /opt/${SITE_MANIFESTS}/baremetal/nodes.yaml ./ || true
            cp /opt/${SITE_MANIFESTS}/baremetal/rack.yaml ./ || true
	    cp /opt/${SITE_MANIFESTS}/pki/* ./ || true
	    cp /opt/${GLOBAL_MANIFESTS}/global/common/layering-policy.yaml ./ || true
	    cp /opt/${GLOBAL_MANIFESTS}/global/networks/common-addresses.yaml ./global-common-addresses.yaml || true
	    mkdir -p /target/certificates
	    promenade generate-certs -o /target/certificates ./*
	    popd

	else
	    echo "Existing certificates.yaml found. Skipping promenade generate-certs"
	fi

	#Generate mappings
	pushd  /workdir/ansible/

	mkdir -p /target/mappings
  ansible-playbook -i /target/inventory.ini  playbooks/generate_mappings.yaml | tee -a $ANSIBLE_LOG_FILE
	popd

	rm -rf /target/certs
	pushd /target
	python3 /opt/bin/generate_new_certs.py control /target/mappings/rendered_mappings_control.json
	python3 /opt/bin/generate_new_certs.py compute /target/mappings/rendered_mappings_compute.json
	popd

	pushd /workdir/ansible
	#hack to handle cp-secondary profile
	ansible-playbook -i /target/inventory.ini  playbooks/delete_secondary.yaml | tee -a $ANSIBLE_LOG_FILE

	#Removes the chattr on all the pem files
	#Workaround to handle chattr problem when re-running with same certs

  if [ $RUN_CHATTR  == true ]; then
    ansible-playbook -i /target/inventory.ini  playbooks/remove_attr.yaml | tee -a $ANSIBLE_LOG_FILE
  fi

	#Copies all the .pem files to respective nodes
        ansible-playbook -i /target/inventory.ini playbooks/distribute_certs.yaml | tee -a $ANSIBLE_LOG_FILE
	popd
}

function generate_config_maps() {
	pushd /workdir/ansible
	mkdir -p /target/cm_secrets
	if [  -f /target/certificates/ingress.yaml ]; then
            ansible-playbook -i /target/inventory.ini  playbooks/generate_configmaps.yaml | tee -a $ANSIBLE_LOG_FILE
	else
		echo "No ingress.yaml found in /target/certificates "
	fi
	popd
}

function unlock_certs() {
	pushd /workdir/ansible
  ansible-playbook -i /target/inventory.ini  playbooks/remove_attr.yaml | tee -a $ANSIBLE_LOG_FILE
	popd
}

function lock_certs() {
	echo "Place holder"
}

function print_help() {

	echo "Usage: entrypoint.sh <option>


Options:
  lock_certs          Lock the certificates file in the nodes
  unlock_certs        Unlock the certificates file in the nodes
  rotate_certs        Generate new certificates and distribute to all nodes
  generate_config_maps   Apply new config maps
  apply_config_maps   Apply new config maps

	"
}

case $1 in

'lock_certs')
  echo "Lock Certs."
  ;;
'unlock_certs')
  unlock_certs
  ;;
'rotate_certs')
  function_distribute_certs
  ;;
'generate_config_maps')
  generate_config_maps
  ;;
'apply_config_maps')
  echo "Apply Config Maps"
  ;;
'unlock_k8s_manifests')
  function_unlock_k8s_manifests
  ;;
'restart_kubelet')
  args=`echo $@ | sed 's/restart_kubelet//'`
  function_restart_kubelet "$args"
  ;;
'kubectl')
  args=`echo $@ | sed 's/kubectl//'`
  function_kubectl "$args"
  ;;
  *)
  print_help
  ;;

esac
