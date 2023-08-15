#!/bin/bash

kubectl create namespace $1 --dry-run=client --output yaml | kubectl apply -f -

services=( dotnet-sample
  nginx
)

ports=( 80
  80
)

images=( mcr.microsoft.com/dotnet/samples:aspnetapp
  nginx:latest
)

replicas=( 2
  2
)

for i in ${!services[@]}; do
  service="${services[$i]}"
  port="${ports[$i]}"
  image="${images[$i]}"
  replica="${replicas[$i]}"

  if [ $ENVIRONMENT = "prd" ]; then
      FQDN="${service}.${DOMAIN}"
  else
      FQDN="${service}-${ENVIRONMENT}.${DOMAIN}"
  fi

  echo "$i" "$1" "${FQDN}" "${port} "${image} "${replica}"

  kubectl apply -n $1 -f - <<EOF
  apiVersion: v1
  kind: Service
  metadata:
    name: sn-${service}-${ENVIRONMENT}
    labels:
      app: ${service}-${ENVIRONMENT}
      service: ${service}-${ENVIRONMENT}
  spec:
    ports:
    - port: ${port}
      name: http
    selector:
      app: ${service}-${ENVIRONMENT}
---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: dpl-${service}-${ENVIRONMENT}
    labels:
      app: ${service}-${ENVIRONMENT}
      version: v1
  spec:
    replicas: ${replica}
    selector:
      matchLabels:
        app: ${service}-${ENVIRONMENT}
        version: v1
    template:
      metadata:
        labels:
          app: ${service}-${ENVIRONMENT}
          version: v1
          sidecar.istio.io/inject: "true"
      spec:
        containers:
        - name: cn-${service}-${ENVIRONMENT}
          image: ${image}
          imagePullPolicy: IfNotPresent
          ports:
          - containerPort: ${port}
          env:
          - name: DOTNET_HOSTBUILDER__RELOADCONFIGONCHANGE
            value: "false"
---
    apiVersion: networking.istio.io/v1alpha3
    kind: VirtualService
    metadata:
      name: vs-${service}-${ENVIRONMENT}
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
              host: sn-${service}-${ENVIRONMENT}
---
    apiVersion: networking.istio.io/v1alpha3
    kind: DestinationRule
    metadata:
      name: dr-${service}-${ENVIRONMENT}
    spec:
      host: sn-${service}-${ENVIRONMENT}
      trafficPolicy:
        tls:
          mode: DISABLE
EOF
done



kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: ap-dotnet-sample-${ENVIRONMENT}
  namespace: $1
spec:
  selector:
    matchLabels:
      app: dotnet-sample-${ENVIRONMENT}
  action: ALLOW
  rules:
    - to:
        - operation:
            methods:
              - GET
      from:
        - source:
            remoteIpBlocks:
              - 172.19.0.5/32
EOF

kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: ap-nginx-${ENVIRONMENT}
  namespace: $1
spec:
  selector:
    matchLabels:
      app: nginx-${ENVIRONMENT}
  action: ALLOW
  rules:
    - to:
        - operation:
            methods:
              - GET
              - POST
      from:
        - source:
            remoteIpBlocks:
              - 172.19.0.5/32
EOF