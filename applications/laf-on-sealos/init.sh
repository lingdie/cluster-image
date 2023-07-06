helm repo add bitnami https://charts.bitnami.com/bitnami
helm pull bitnami/etcd -d charts/ --untar

helm repo add apisix https://charts.apiseven.com
helm pull apisix/apisix -d charts/ --untar