#!/bin/bash
set -e

function gen_laf_config() {
    MAIN_DOMAIN=laf.cloud.sealos.run
    MINIO_DOMAIN=oss.${MAIN_DOMAIN}
    WEBSITE_DOMAIN=site.${MAIN_DOMAIN}
    MINIO_EXTERNAL_ENDPOINT="https://${MINIO_DOMAIN}"

    # get mongodb uri
    bash scripts/gen-mongodb-uri.sh

    # MongoDb conf
    MONGO_ROOT_USER=$username
    MONGO_ROOT_PASSWORD=$password
    MONGO_HOST=$headlessHost
    MONGO_URI=${mongodb_uri}/sys_db?authSource=admin&replicaSet=rs0&w=majority

    # Apisix conf
    APISIX_API_KEY=$(tr -cd 'a-z0-9' </dev/urandom |head -c32)
    APISIX_API_KEY_VIEWER=$(tr -cd 'a-z0-9' </dev/urandom |head -c32)
    APISIX_DASHBOARD_PASSWORD=$(tr -cd 'a-z0-9' </dev/urandom |head -c32)
    APISIX_ETCD_ROOT_PASSWORD=$(tr -cd 'a-z0-9' </dev/urandom |head -c32)

    # Server conf
    SERVER_JWT_SECRET=$(tr -cd 'a-z0-9' </dev/urandom |head -c32)

    # create a secret by kubectl
    kubectl create secret generic laf-cluster-config \
        --from-literal=MAIN_DOMAIN=${MAIN_DOMAIN} \
        --from-literal=MINIO_DOMAIN=${MINIO_DOMAIN} \
        --from-literal=WEBSITE_DOMAIN=${WEBSITE_DOMAIN} \
        --from-literal=MINIO_EXTERNAL_ENDPOINT=${MINIO_EXTERNAL_ENDPOINT} \
        --from-literal=MONGO_ROOT_USER=${MONGO_ROOT_USER} \
        --from-literal=MONGO_ROOT_PASSWORD=${MONGO_ROOT_PASSWORD} \
        --from-literal=MONGO_URI=${MONGO_URI} \
        --from-literal=APISIX_API_KEY=${APISIX_API_KEY} \
        --from-literal=APISIX_API_KEY_VIEWER=${APISIX_API_KEY_VIEWER} \
        --from-literal=APISIX_DASHBOARD_PASSWORD=${APISIX_DASHBOARD_PASSWORD} \
        --from-literal=APISIX_ETCD_ROOT_PASSWORD=${APISIX_ETCD_ROOT_PASSWORD} \
        --from-literal=SERVER_JWT_SECRET=${SERVER_JWT_SECRET}
}

function setup_apisix_etcd() {
    APISIX_ETCD_ROOT_PASSWORD=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.APISIX_ETCD_ROOT_PASSWORD}' | base64 -d)
    helm install apisix-etcd charts/etcd \
    	--namespace ingress-apisix --create-namespace \
    	--set replicaCount=3 \
    	--set auth.rbac.rootPassword=${APISIX_ETCD_ROOT_PASSWORD}
}


function setup_apisix() {
  APISIX_API_KEY=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.APISIX_API_KEY}' | base64 -d)
  APISIX_API_KEY_VIEWER=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.APISIX_API_KEY_VIEWER}' | base64 -d)
  APISIX_DASHBOARD_PASSWORD=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.APISIX_DASHBOARD_PASSWORD}' | base64 -d)
  APISIX_ETCD_ROOT_PASSWORD=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.APISIX_ETCD_ROOT_PASSWORD}' | base64 -d)
  helm install  apisix apisix/apisix \
      --namespace ingress-apisix  \
      --set apisix.kind=DaemonSet \
      --set apisix.hostNetwork=false \
      --set apisix.securityContext.runAsUser=0 \
      --set admin.credentials.admin=${APISIX_API_KEY} \
      --set admin.credentials.viewer=${APISIX_API_KEY_VIEWER} \
      --set dashboard.enabled=true \
      --set dashboard.config.conf.etcd.username=root \
      --set dashboard.config.conf.etcd.password=${APISIX_ETCD_ROOT_PASSWORD} \
      --set "dashboard.config.authentication.users[0].username=admin" \
      --set "dashboard.config.authentication.users[0].password=${APISIX_DASHBOARD_PASSWORD}" \
      --set ingress-controller.enabled=true \
      --set ingress-controller.config.apisix.adminKey="${APISIX_API_KEY}" \
      --set etcd.enabled=false \
      --set etcd.user=root \
      --set etcd.password=${APISIX_ETCD_ROOT_PASSWORD} \
      --set "etcd.host[0]=http://apisix-etcd.ingress-apisix.svc.cluster.local:2379" \
      --set gateway.http.containerPort=80 \
      --set gateway.stream.enabled=true \
      --set gateway.tls.enabled=true \
      --set gateway.tls.containerPort=443
}

function setup_minio_operator() {
  kubectl create namespace laf-minio
}

function setup_laf_server() {
  # common conf
  MAIN_DOMAIN=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.MAIN_DOMAIN}' | base64 -d)
  MINIO_DOMAIN=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.MINIO_DOMAIN}' | base64 -d)
  WEBSITE_DOMAIN=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.WEBSITE_DOMAIN}' | base64 -d)
  SERVER_JWT_SECRET=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.SERVER_JWT_SECRET}' | base64 -d)

  # mongo conf
  MONGO_URI=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.MONGO_URI}' | base64 -d)

  # minio conf
  MINIO_EXTERNAL_ENDPOINT=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.MINIO_EXTERNAL_ENDPOINT}' | base64 -d)
  MINIO_INTERNAL_ENDPOINT=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.MINIO_INTERNAL_ENDPOINT}' | base64 -d)
  MINIO_ROOT_ACCESS_KEY=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.MINIO_ROOT_ACCESS_KEY}' | base64 -d)
  MINIO_ROOT_SECRET_KEY=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.MINIO_ROOT_SECRET_KEY}' | base64 -d)

  # apisix conf
  APISIX_API_URL=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.APISIX_API_URL}' | base64 -d)
  APISIX_API_KEY=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.APISIX_API_KEY}' | base64 -d)

  helm install server charts/laf-server \
      --namespace laf-system --create-namespace \
      --set databaseUrl=${MONGO_URI} \
      --set jwt.secret=${SERVER_JWT_SECRET} \
      --set apiServerHost=api.${MAIN_DOMAIN} \
      --set apiServerUrl="https://api.${MAIN_DOMAIN}" \
      --set default_region.database_url=${MONGO_URI} \
      --set default_region.minio_domain=${MINIO_DOMAIN} \
      --set default_region.minio_external_endpoint=${MINIO_EXTERNAL_ENDPOINT} \
      --set default_region.minio_internal_endpoint=${MINIO_INTERNAL_ENDPOINT} \
      --set default_region.minio_root_access_key=${MINIO_ROOT_ACCESS_KEY} \
      --set default_region.minio_root_secret_key=${MINIO_ROOT_SECRET_KEY} \
      --set default_region.runtime_domain=${MAIN_DOMAIN} \
      --set default_region.website_domain=${WEBSITE_DOMAIN} \
      --set default_region.tls=true \
      --set default_region.apisix_api_url=${APISIX_API_URL} \
      --set default_region.apisix_api_key=${APISIX_API_KEY} \
      --set default_region.apisix_public_port=443
}


function init() {
    gen_laf_config
    setup_apisix_etcd
    setup_apisix
    setup_minio_operator
    setup_laf_server
}

init