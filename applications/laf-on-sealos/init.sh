#!/bin/bash
set -e

helm repo add bitnami https://charts.bitnami.com/bitnami
helm pull bitnami/etcd -d charts/ --untar

helm repo add apisix https://charts.apiseven.com
helm pull apisix/apisix -d charts/ --untar

helm repo add minio https://operator.min.io/
helm pull minio/operator -d charts --untar

git clone https://github.com/labring/laf.git
cp -r laf/build/charts charts/laf-server