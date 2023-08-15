#!/bin/bash

DOMAIN_WITHOUT_DOT=$(echo ${DOMAIN} | tr -d '.')

kubectl create namespace ns-sre-${ENVIRONMENT} --dry-run=client --output yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: vs-sre-${ENVIRONMENT}
  namespace: ns-sre-${ENVIRONMENT}
  labels:
    app: sre-${ENVIRONMENT}
spec:
  hosts:
  - "httpbin.${DOMAIN}"
  gateways:
  - istio-system/ingressgateway
  - istio-system/external-ingressgateway
  http:
  - match:
    - uri:
        regex: ".*"
    rewrite:
      authority: httpbin.org
    route:
      - destination:
          port:
            number: 443
          host: httpbin.org
  - route:
    - destination:
        port:
          number: 80
        host: httpbin.org
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: dr-sre-${ENVIRONMENT}
  namespace: ns-sre-${ENVIRONMENT}
  labels:
    app: sre-${ENVIRONMENT}
spec:
  host: httpbin.org
  trafficPolicy:
    tls:
      mode: SIMPLE
---
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: se-sre-${ENVIRONMENT}
  namespace: ns-sre-${ENVIRONMENT}
  labels:
    app: sre-${ENVIRONMENT}
spec:
  hosts:
    - httpbin.org
  ports:
    - number: 443
      name: tls
      protocol: tls
  resolution: DNS
  location: MESH_EXTERNAL
EOF