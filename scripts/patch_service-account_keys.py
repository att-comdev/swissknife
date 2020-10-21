import sys

import yaml

original_certificates_file = sys.argv[1]
new_certificates_file = sys.argv[2]


def get_certificates(filename: str) -> list:
    with open(filename, 'r') as f:
        loaded_yaml = list(yaml.load_all(f))
    return loaded_yaml


def get_service_account_keys(certificates: list) -> list:
    service_account_entries = []
    for certificate in certificates:
        if certificate['metadata']['name'] == 'service-account':
            service_account_entries.append(certificate)
    return service_account_entries


def patch_service_account_keys(certificates: list, patch_items: list) -> list:
    patched_certificates = []
    for certificate in certificates:
        if certificate['metadata']['name'] != 'service-account':
            patched_certificates.append(certificate)
    patched_certificates.extend(patch_items)
    return patched_certificates


def save_certificates(certificates: list, path: str):
    with open(path, 'w') as f:
        yaml.safe_dump_all(certificates,
                           f,
                           default_flow_style=False,
                           explicit_start=True,
                           explicit_end=True)


if __name__ == '__main__':
    original_certificates = get_certificates(original_certificates_file)
    new_certificates = get_certificates(new_certificates_file)
    service_account_keys = get_service_account_keys(original_certificates)
    new_certificates = patch_service_account_keys(new_certificates,
                                                  service_account_keys)
    save_certificates(new_certificates, new_certificates_file)
