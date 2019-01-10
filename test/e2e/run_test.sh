#!/bin/bash -e

VALUES_FILE=
NAMESPACE=$1

kubectl create namespace "$NAMESPACE"
pushd ship_kustomize
ship update
#ship update --helm-values-file "$VALUES_FILE"
popd
python create_configmap.py
pushd ship_kustomize/overlays/ship
kustomize build > kustomized.yaml
kubectl apply -f kustomized.yaml -n "$NAMESPACE"
popd
