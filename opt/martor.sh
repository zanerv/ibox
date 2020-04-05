#!/bin/bash
set -e
update() {
    wget -q https://raw.githubusercontent.com/zanerv/ibox/master/opt/martor.sh -O /opt/martor.sh&&chmod +x /opt/martor.sh
    wget -q https://github.com/zanerv/ibox/raw/master/opt/ddns.sh -O /opt/ddns.sh&&chmod +x /opt/ddns.sh
    wget -q https://raw.githubusercontent.com/zanerv/ibox/master/opt/docker-compose.yml -O /opt/docker-compose.yml
    wget -q https://github.com/zanerv/ibox/raw/master/opt/successrate.sh -O /opt/successrate.sh&&chmod +x /opt/successrate.sh
    
    /usr/bin/docker-compose -f /opt/docker-compose.yml pull >/dev/null 2>&1 &&\
    /usr/bin/docker-compose -f /opt/docker-compose.yml up -d >/dev/null 2>&1
}
trap "update $(($LINENO + 14))" ERR

HOSTNAME=$(hostname)
aSMART=( $(/usr/sbin/smartctl -a /dev/sda -d sat|egrep -i "^  5|^187|^188|^197|^198|^194"|awk '{print $2, $10}') )
echo "SMART,Host=${HOSTNAME} ${aSMART[0]}=${aSMART[1]},${aSMART[2]}=${aSMART[3]},${aSMART[4]}=${aSMART[5]},\
${aSMART[6]}=${aSMART[7]} $(date +%s%N)"

cpu=$(uptime | awk '{print $10+0}')
memory=$(free -m | awk 'NR==2{printf "%.0f", $3*100/$2 }')
disk=$(df -h|grep /$|awk '{print $5}'|tr -d %)
temperature=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp)
echo "Sys,Host=${HOSTNAME} cpu=${cpu},memory=${memory},disk=${disk},temperature=${temperature::2},\
last_boot=$(date -d "$(uptime -s)" +"%s") $(date +%s%N)"

satellites=$(curl -s localhost:14002/api/sno/satellites 2>/dev/null)
dashboard=$(curl -s localhost:14002/api/sno/ 2>/dev/null)
bandwidthSummary=$(echo ${satellites}| jq -r .bandwidthSummary)
egressSummary=$(echo ${satellites}| jq -r '.bandwidthDaily[].egress'\
    | jq -n 'reduce (inputs | to_entries[]) as {$key,$value} ({}; .[$key] += $value)'\
| jq -r .[]| paste -s -d+ - | bc)
egressDaily=$(echo ${satellites}| jq -r .bandwidthDaily[-1].egress[]| paste -s -d+ - | bc)
diskSpace=$(echo ${dashboard}| jq -r .diskSpace.used)
lastPinged=$(echo ${dashboard}| jq .lastPinged)
upToDate=$(echo ${dashboard}| jq .upToDate)
nodeID=$(echo ${dashboard}| jq -r .nodeID)
wallet=$(echo ${dashboard}| jq -r .wallet)
balance=$(curl -s "http://api.ethplorer.io/getAddressInfo/${wallet}?apiKey=freekey"|jq -r .tokens[].balance)
if [[ ${error} != 'null'  ]]; then
 error=", error=${error} "
else
 error=""
fi

echo "Storj,NodeId=${nodeID::7} bandwidthSummary=${bandwidthSummary},egressSummary=${egressSummary},\
egressDaily=${egressDaily},diskSpace=${diskSpace},lastPinged=${lastPinged},\
upToDate=${upToDate},wallet=\"${wallet}\",balance=${balance::4} ${error} $(date +%s%N)"
