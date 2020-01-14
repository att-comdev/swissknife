FROM quay.io/airshipit/promenade@sha256:4c9902c9944cee93a8e7df2d441472be7177b1e2a3076e59ab0db7af53002599

USER root
RUN apt-get update && apt-get install -y ansible vim sshpass && rm -rf /var/lib/apt/lists/*

WORKDIR /workdir/

COPY entrypoint.sh /opt/bin/entrypoint.sh
COPY site-dir-inventory.py /opt/bin/site-dir-inventory.py
COPY generate_cm_secrets.py /opt/bin/generate_cm_secrets.py
COPY generate_new_certs.py /opt/bin/generate_new_certs.py
COPY ansible /workdir/ansible
RUN  chown -R promenade:users /workdir && chmod -R 0755 /workdir && chmod 0755 /opt/bin/entrypoint.sh
RUN sed -i '/\[ssh_connection\]/a retries=3' /etc/ansible/ansible.cfg

USER promenade

ENV ANSIBLE_GATHERING smart
ENV ANSIBLE_HOST_KEY_CHECKING false
ENV ANSIBLE_RETRY_FILES_ENABLED false
ENV ANSIBLE_ROLES_PATH /workdir/ansible/playbooks/roles
ENV ANSIBLE_SSH_PIPELINING False
ENV PATH /opt/bin:$PATH
ENV PYTHONPATH /workdir/ansible/lib

ENTRYPOINT [ "/opt/bin/entrypoint.sh" ]

CMD ["rotate_certs"]
