#!/bin/bash
set -e
update() {
    curl -sf https://raw.githubusercontent.com/zanerv/ibox/master/opt/martor.sh -o /opt/martor.sh&&chmod +x /opt/martor.sh
    #curl -sf https://raw.githubusercontent.com/zanerv/ibox/master/opt/ddns.sh -o /opt/ddns.sh&&chmod +x /opt/ddns.sh
    #curl -sf https://raw.githubusercontent.com/zanerv/ibox/master/opt/docker-compose.yml -o /opt/docker-compose.yml
    curl -sf https://raw.githubusercontent.com/zanerv/ibox/master/opt/successrate.sh -o /opt/successrate.sh&&chmod +x /opt/successrate.sh
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
adisk_util=( $(iostat -dx|grep sd|awk '{print $1, $16}'|sed 's| |_util\=|'|tr '\n' ',') )
temperature=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp)
ps=$(ps -ef|wc -l)
echo "Sys,Host=${HOSTNAME} cpu=${cpu},memory=${memory},disk=${disk},${adisk_util[@]}temperature=${temperature::2},\
last_boot=$(date -d "$(uptime -s)" +"%s"),iowait=${iowait},ps=${ps} $(date +%s%N)"
latency=$(ping -U -c3 europe-west-1.tardigrade.io | grep avg | awk -F'/' '{print int($5+0.5)}')
noti=$(curl -s "localhost:14002/api/notifications/list?page=1&limit=100" | jq -r .unreadCount)
est=$(curl -s localhost:14002/api/sno/estimated-payout | jq -r .currentMonthExpectations | awk '{printf ("%'\''d\n", $0/100)}')
satellites=$(curl -s localhost:14002/api/sno/satellites 2>/dev/null)
dashboard=$(curl -s localhost:14002/api/sno/ 2>/dev/null)
bandwidthSummary=$(echo ${satellites}| jq -r .bandwidthSummary 2>/dev/null)
egressSummary=$(echo ${satellites}| jq -r '.bandwidthDaily[].egress'\
    | jq -n 'reduce (inputs | to_entries[]) as {$key,$value} ({}; .[$key] += $value)'\
| jq -r .[]| paste -s -d+ - | bc)
egressDaily=$(echo ${satellites}| jq -r .bandwidthDaily[-1].egress[] 2>/dev/null| paste -s -d+ - | bc)
ingressDaily=$(echo ${satellites}| jq -r .bandwidthDaily[-1].ingress[] 2>/dev/null| paste -s -d+ - | bc)
diskSpace=$(echo ${dashboard}| jq -r .diskSpace.used 2>/dev/null)
error=$(echo ${dashboard}| jq .error)
lastPinged=$(echo ${dashboard}| jq .lastPinged)
upToDate=$(echo ${dashboard}| jq .upToDate)
nodeID=$(echo ${dashboard}| jq -r .nodeID)
nodeID=${nodeID::7}
wallet=$(echo ${dashboard}| jq -r .wallet)
auditScore=($(echo $satellites |jq -r ".audits[].auditScore"))
auditScore=$(awk 'BEGIN {t=0; for (i in ARGV) t+=ARGV[i]; print t}' "${auditScore[@]}")
suspensionScore=($(echo $satellites |jq -r ".audits[].suspensionScore"))
suspensionScore=$(awk 'BEGIN {t=0; for (i in ARGV) t+=ARGV[i]; print t}' "${suspensionScore[@]}")
onlineScore=($(echo $satellites |jq -r ".audits[].onlineScore"))
onlineScore=$(awk 'BEGIN {t=0; for (i in ARGV) t+=ARGV[i]; print t}' "${onlineScore[@]}")
if [[ ${error} != 'null'  ]]; then
 error=", error=${error} "
else
 error=""
fi

echo "SMART,NodeId=${nodeID} ${aSMART[0]}=${aSMART[1]},${aSMART[2]}=${aSMART[3]},${aSMART[4]}=${aSMART[5]},\
${aSMART[6]}=${aSMART[7]} $(date +%s%N)"
echo "Storj,NodeId=${nodeID} bandwidthSummary=${bandwidthSummary},egressSummary=${egressSummary},\
egressDaily=${egressDaily},ingressDaily=${ingressDaily},diskSpace=${diskSpace},lastPinged=${lastPinged},\
upToDate=${upToDate},wallet=\"${wallet}\",auditScore=${auditScore},suspensionScore=${suspensionScore},\
onlineScore=${onlineScore},latency=${latency},noti=${noti},est=${est} ${error} $(date +%s%N)"
