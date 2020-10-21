import argparse
import base64
import glob
import json
import logging
import os

import yaml

logging.basicConfig(filename='generate_cm_secrets.log',
                    format='%(asctime)s:%(levelname)s:%(message)s',
                    level=logging.DEBUG)


def clean_output_dir(output_dir):
    filelist = glob.glob(os.path.join(output_dir, "*"))
    for f in filelist:
        os.remove(f)


def get_certificates_from_manifests(fpath):
    with open(fpath, "r") as rf:
        manifests = yaml.safe_load_all(rf.read())
        certs = {(cert.get('schema'), cert.get('metadata').get('name')):
                 cert.get('data')
                 for cert in manifests}
        logging.info("Successfully loaded certs from:{0}".format(fpath))
        return certs


def generate_cm_secrets_from_mapping(mappingfile, output_dir):
    with open(mappingfile, "r") as rf:
        k = yaml.safe_load(rf.read())

        for dest_type, details in k.items():
            for namespace, cert_details in details.items():
                for cm_or_secret in cert_details:
                    template = {}
                    template['data'] = {}

                    for keys in cm_or_secret.get('keys'):
                        data = certs.get(
                            (keys.get("schema"), keys.get("cert_name")))
                        if not data:
                            logging.info(
                                "Certificate not found for schema: {0}, "
                                "cert_name: {1}".format(
                                    keys.get("schema"), keys.get("cert_name")))
                            continue
                        if dest_type == 'configmap':
                            template['data'][keys.get('key_name')] = data
                        elif dest_type == 'secret':
                            template['data'][keys.get(
                                'key_name')] = base64.b64encode(
                                    data.encode('utf-8')).decode('utf-8')

                    output_file = "{}_{}_{}_patch.json".format(
                        dest_type, namespace, cm_or_secret['name'])
                    dest_file = "{}/{}".format(output_dir, output_file)

                    with open(dest_file, "a") as wf:
                        if template['data']:
                            json.dump(template, wf)


if __name__ == '__main__':
    certs = {}
    parser = argparse.ArgumentParser()
    parser.add_argument("mapping_yaml",
                        type=str,
                        help='Enter Mapping yaml path')
    parser.add_argument("output_dir",
                        type=str,
                        help='Enter the folder for output yaml to store')
    args = parser.parse_args()
    dir_name = os.path.dirname(__file__)
    cert_dir = os.path.join(dir_name, '../../certificates')
    mapping_yaml = args.mapping_yaml
    output_dir = args.output_dir

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    else:
        clean_output_dir(output_dir)

    if os.path.exists(cert_dir):
        for files in os.listdir(cert_dir):
            file_name = cert_dir + '/' + files
            if os.path.isfile(file_name):
                certs.update(get_certificates_from_manifests(file_name))
        generate_cm_secrets_from_mapping(mapping_yaml, output_dir)
