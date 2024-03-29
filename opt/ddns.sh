#!/bin/bash
source /opt/ddns
dns=8.8.8.8
check() {
  ping ${dns} -c 1 -i .2 >/dev/null 2>&1
  ONLINE=$?
}
check

i=0
while [ ${i} -lt 10 ]; do
  if [[ ${ONLINE} -eq 1 ]]; then
     sleep 1m
     check
     continue
  fi
  IP=$(host $(hostname -f) ${dns} | awk '{print $4}' | tr -d '[:space:]')
  NewIP=$(curl -s https://kpu.ro/ip)
  if [[ $? -gt 0 ]]; then
    break
  fi
  if [[ ${IP} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ && -n ${NewIP} ]]; then
    break
  fi
  sleep 5
  i=$(( ${i} + 1 ))
done
if [[ ${IP} != ${NewIP} && -n ${NewIP} && -n ${IP} ]]; then
   curl -su ${ddns_user}:${ddns_pass} "https://$(dnsdomainname)/ibox.php?hostname=$(hostname)&myip=${NewIP}"
fi
