#!/bin/bash
set -e

update() {
  echo "Updating..."
  wget -q https://raw.githubusercontent.com/zanerv/ibox/master/opt/martor.sh -O /opt/martor.sh&&chmod +x /opt/martor.sh
}

trap "update" ERR

HOSTNAME=$(hostname)
aSMART=( $(/usr/sbin/smartctl -a /dev/sda -d sat|egrep -i "^  5|^187|^188|^197|^198|^194"|awk '{print $2, $10}') )
echo "SMART,Host=${HOSTNAME} ${aSMART[0]}=${aSMART[1]},${aSMART[2]}=${aSMART[3]},${aSMART[4]}=${aSMART[5]},\
${aSMART[6]}=${aSMART[7]},${aSMART[8]}=${aSMART[9]},${aSMART[10]}=${aSMART[11]} $(date +%s%N)"

cpu=$(uptime | awk '{print $10+0}')
memory=$(free -m | awk 'NR==2{printf "%.0f", $3*100/$2 }')
disk=$(df -h|grep /$|awk '{print $5}'|tr -d %)
temperature=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp)
echo "Sys,Host=${HOSTNAME} cpu=${cpu},memory=${memory},disk=${disk},temperature=${temperature::2},\
last_boot=$(stat -c %Z /proc/) $(date +%s%N)"

satellites=$(/usr/bin/docker exec storagenode curl -s localhost:14002/api/sno/satellites)
dashboard=$(/usr/bin/docker exec storagenode curl -s localhost:14002/api/sno/)
bandwidthSummary=$(echo ${satellites}| jq -r .bandwidthSummary)
egressSummary=$(echo ${satellites}| jq -r '.bandwidthDaily[].egress'\
    | jq -n 'reduce (inputs | to_entries[]) as {$key,$value} ({}; .[$key] += $value)'\
    | jq -r .[]| paste -s -d+ - | bc)
egressDaily=$(echo ${satellites}| jq -r .bandwidthDaily[-1].egress[]| paste -s -d+ - | bc)
diskSpace=$(echo ${dashboard}| jq -r .diskSpace.used)
error=$(echo ${dashboard}| jq .error)
lastPinged=$(echo ${dashboard}| jq .lastPinged)
upToDate=$(echo ${dashboard}| jq .upToDate)
nodeID=$(echo ${dashboard}| jq -r .nodeID)
wallet=$(echo ${dashboard}| jq .wallet)

echo "Storj,nodeID=${nodeID::7} bandwidthSummary=${bandwidthSummary},egressSummary=${egressSummary},\
egressDaily=${egressDaily},diskSpace=${diskSpace},lastPinged=${lastPinged},\
upToDate=${upToDate},wallet=${wallet} $(date +%s%N)"

if [[ -n ${error} ]]; then
echo "Storj,nodeID=${nodeID::7} error=${error} $(date +%s%N)"
fi
