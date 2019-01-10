import yaml

argo_config_file = 'argo.yaml'
kustomized_config_file = 'kustomized.yaml'

with open(kustomized_config_file, 'r') as config_file:
  k_spec = config_file.read()

with open(argo_config_file, 'r') as argo_file:
  argo_config = yaml.safe_load(argo_file)

argo_config['spec']['templates'][0]['resource']['manifest'] = k_spec

with open(argo_config_file, 'w') as argo_file:
  yaml.safe_dump(argo_config, argo_file, default_flow_style=False)

