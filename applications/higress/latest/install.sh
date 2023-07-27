#!/bin/bash

HELM_OPTS="${HELM_OPTS:-}"

helm install higress -n higress-system charts/higress --create-namespace --render-subchart-notes ${HELM_OPTS}
