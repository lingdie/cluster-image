#!/bin/bash
set -e

bash scripts/upload-charts.sh

export ZOT_PORT=$(kubectl get --namespace zot -o jsonpath="{.spec.ports[0].port}" services zot)
export ZOT_IP=$(kubectl get --namespace zot -o jsonpath="{.spec.clusterIP}" services zot)

helm upgrade -i kubeblocks oci://"$ZOT_IP":"$ZOT_PORT"/helm-charts/kubeblocks --post-renderer=scripts/replace-charts.py --set image.tools.repository=labring/docker-kubeblocks-tools --insecure-skip-tls-verify  -n kb-system --create-namespace
