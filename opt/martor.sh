#!/bin/bash
set -e
update() {
    curl -sf https://raw.githubusercontent.com/zanerv/ibox/master/opt/martor.sh -o /opt/martor.sh&&chmod +x /opt/martor.sh
    #curl -sf https://raw.githubusercontent.com/zanerv/ibox/master/opt/ddns.sh -o /opt/ddns.sh&&chmod +x /opt/ddns.sh
    #curl -sf https://raw.githubusercontent.com/zanerv/ibox/master/opt/docker-compose.yml -o /opt/docker-compose.yml
    curl -sf https://raw.githubusercontent.com/zanerv/ibox/master/opt/successrate.sh -o /opt/successrate.sh&&chmod +x /opt/successrate.sh
    curl -sf https://raw.githubusercontent.com/ReneSmeekes/storj_earnings/master/earnings.py -o /opt/earnings.py
    systemctl start docker
    /usr/bin/docker-compose -f /opt/docker-compose.yml pull >/dev/null 2>&1 &&\
    /usr/bin/docker-compose -f /opt/docker-compose.yml up -d >/dev/null 2>&1
}
trap "update $(($LINENO + 14))" ERR

HOSTNAME=$(hostname)
aSMART=( $(/usr/sbin/smartctl -a /dev/sda -d sat|egrep -i "^  5|^187|^188|^197|^198|^194"|awk '{print $2, $10}') )
iowait=$(iostat -c|awk '/^ /{print $4}')
cpu=$(uptime|tail -c 5)
memory=$(free -m | awk 'NR==2{printf "%.0f", $3*100/$2 }')
disk=$(df -h|grep /$|awk '{print $5}'|tr -d %)
temperature=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp)
echo "Sys,Host=${HOSTNAME} cpu=${cpu},memory=${memory},disk=${disk},temperature=${temperature::2},\
last_boot=$(date -d "$(uptime -s)" +"%s"),iowait=${iowait} $(date +%s%N)"

satellites=$(curl -s localhost:14002/api/sno/satellites 2>/dev/null)
dashboard=$(curl -s localhost:14002/api/sno/ 2>/dev/null)
bandwidthSummary=$(echo ${satellites}| jq -r .bandwidthSummary)
egressSummary=$(echo ${satellites}| jq -r '.bandwidthDaily[].egress'\
    | jq -n 'reduce (inputs | to_entries[]) as {$key,$value} ({}; .[$key] += $value)'\
| jq -r .[]| paste -s -d+ - | bc)
egressDaily=$(echo ${satellites}| jq -r .bandwidthDaily[-1].egress[]| paste -s -d+ - | bc)
ingressDaily=$(echo ${satellites}| jq -r .bandwidthDaily[-1].ingress[]| paste -s -d+ - | bc)
diskSpace=$(echo ${dashboard}| jq -r .diskSpace.used)
error=$(echo ${dashboard}| jq .error)
lastPinged=$(echo ${dashboard}| jq .lastPinged)
upToDate=$(echo ${dashboard}| jq .upToDate)
nodeID=$(echo ${dashboard}| jq -r .nodeID)
nodeID=${nodeID::7}
wallet=$(echo ${dashboard}| jq -r .wallet)
balance_api=$(curl -s "https://api.ethplorer.io/getAddressInfo/${wallet}?apiKey=freekey")
if [[ ${balance_api} =~ "token" ]]; then
 balance=$(echo ${balance_api}|jq -r .tokens[].balance)
 balance=$((balance / 100000000))
else
 balance=0
fi
if [[ ${error} != 'null'  ]]; then
 error=", error=${error} "
else
 error=""
fi

echo "SMART,NodeId=${nodeID} ${aSMART[0]}=${aSMART[1]},${aSMART[2]}=${aSMART[3]},${aSMART[4]}=${aSMART[5]},\
${aSMART[6]}=${aSMART[7]} $(date +%s%N)"
echo "Storj,NodeId=${nodeID} bandwidthSummary=${bandwidthSummary},egressSummary=${egressSummary},\
egressDaily=${egressDaily},ingressDaily=${ingressDaily},diskSpace=${diskSpace},lastPinged=${lastPinged},\
upToDate=${upToDate},wallet=\"${wallet}\",balance=${balance} ${error} $(date +%s%N)"
