#!/bin/bash

services=( prometheus
  grafana
  kiali
  tracing
)

ports=( 9090
  3000
  20001
  80
)

for i in ${!services[@]}; do
  service="${services[$i]}"
  port="${ports[$i]}"

  if [ $ENVIRONMENT = "prd" ]; then
      FQDN="${service}.${DOMAIN}"
  else
      FQDN="${service}-${ENVIRONMENT}.${DOMAIN}"
  fi

  echo "$i" "${FQDN}" "${port}"

  kubectl apply -f - <<EOF
    apiVersion: networking.istio.io/v1alpha3
    kind: VirtualService
    metadata:
      name: vs-${service}-${ENVIRONMENT}
      namespace: istio-system
    spec:
      hosts:
      - "${FQDN}"
      gateways:
      - istio-system/ingressgateway
      - istio-system/external-ingressgateway
      http:
      - match:
        - uri:
            prefix: /
        route:
          - destination:
              port:
                number: ${port}
              host: ${service}
---
    apiVersion: networking.istio.io/v1alpha3
    kind: DestinationRule
    metadata:
      name: dr-${service}-${ENVIRONMENT}
      namespace: istio-system
    spec:
      host: ${service}
      trafficPolicy:
        tls:
          mode: DISABLE
EOF
done