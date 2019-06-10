#!/bin/bash
# manual run
# /usr/sbin/iptables -t nat -A POSTROUTING -s 172.17.0.2/32 -d 172.17.0.2/32 -p tcp -m tcp --dport 443 -j MASQUERADE
# /usr/sbin/iptables -t nat -A POSTROUTING -s 172.17.0.2/32 -d 172.17.0.2/32 -p udp -m udp --dport 443 -j MASQUERADE
RULER1=$(/usr/sbin/iptables -t filter -nvL DOCKER --line-number | grep "dpt:443" | awk '{print $1}')
build_iptables(){
 /usr/sbin/iptables -t filter -A FORWARD -d 172.17.0.0/24 -i docker0 -j ACCEPT
 /usr/sbin/iptables -t filter -A DOCKER -d 172.17.0.2/32 ! -i docker0 -o docker0 -p tcp -m tcp --dport 443 -j ACCEPT
 /usr/sbin/iptables -t nat -A DOCKER ! -i docker0 -p tcp -m tcp --dport 443 -j DNAT --to-destination 172.17.0.2:443
 /usr/sbin/iptables -t filter -A DOCKER -d 172.17.0.2/32 ! -i docker0 -o docker0 -p udp -m udp --dport 443 -j ACCEPT
 /usr/sbin/iptables -t nat -A DOCKER ! -i docker0 -p udp -m udp --dport 443 -j DNAT --to-destination 172.17.0.2:443
}
echo ${RULER1}
if [[ -z $RULER1 ]]; then
 echo "rebuild"
 build_iptables
fi 
