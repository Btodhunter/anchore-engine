import yaml

anchore_config = 'load_test/config.yaml'
anchore_configmap = 'ship_kustomize/overlays/ship/engine_configmap.yaml'

with open(anchore_config, 'r') as config_file:
  config_string = config_file.read()

with open(anchore_configmap, 'r') as configmap_file:
  configmap = yaml.safe_load(configmap_file)

configmap['data']['config.yaml'] = config_string

with open(anchore_configmap, 'w') as configmap_file:
  yaml.safe_dump(configmap, configmap_file, default_flow_style=False)

