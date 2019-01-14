import yaml
import sys
import os

# prep input from CLI
if len(sys.argv) <= 1:
  print ("USAGE: {} <commit sha> <config dir>".format(sys.argv[0]))
  sys.exit(1)

commit_sha = str(sys.argv[1])
config_path = str(sys.argv[2])
if not os.path.exists(config_path):
  print ("config dir {} does not exist".format(sys.argv[2]))
  sys.exit(1)

anchore_config = config_path + '/config.yaml'
anchore_configmap = 'ship_kustomize/overlays/ship/engine_configmap.yaml'
anchore_values = config_path + '/values.yaml'

with open(anchore_config, 'r') as config_file:
  config_string = config_file.read()

with open(anchore_configmap, 'r') as configmap_file:
  configmap = yaml.safe_load(configmap_file)

configmap['data']['config.yaml'] = config_string

with open(anchore_configmap, 'w') as configmap_file:
  yaml.safe_dump(configmap, configmap_file, default_flow_style=False)

# with open(anchore_values, 'r') as values_file:
#   values = yaml.safe_load(values_file)

# values['anchoreGlobal']['image']['tag'] = commit_sha

# with open(anchore_values, 'w') as values_file:
#   yaml.safe_dump(values, values_file, default_flow_style=False)
