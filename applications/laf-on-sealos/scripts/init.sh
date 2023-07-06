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
MONGO_URI=$mongodb_uri

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


APISIX_ETCD_ROOT_PASSWORD=$(kubectl get secret laf-cluster-config -o jsonpath='{.data.APISIX_ETCD_ROOT_PASSWORD}' | base64 -d)
helm install -i apisix-etcd charts/etcd \
	--namespace ingress-apisix --create-namespace \
	--set replicaCount=3 \
	--set auth.rbac.rootPassword=${APISIX_ETCD_ROOT_PASSWORD}