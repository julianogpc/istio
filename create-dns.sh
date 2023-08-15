#!/bin/bash

hosts=($(kubectl get virtualservices.networking.istio.io -A -o json | jq -r '.items[] | .spec.hosts[]'))

for host in ${hosts[@]}; do
    dns_record=$(echo ${host/.*/})
    make cloudflare DNS_IP=192.168.1.70 DNS_RECORD=${dns_record}
done