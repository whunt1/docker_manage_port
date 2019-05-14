#!/bin/bash
#description:自动映射端口脚本
RULER=$(/usr/sbin/iptables -t nat -nvL --line-number | grep "172.17.0.2:443" | awk '{print $1}')
echo ${RULER}
if [[ -z $RULER ]]; then
 echo "rebuild"
 /usr/sbin/iptables -t filter -A DOCKER -d 172.17.0.2/32 ! -i docker0 -o docker0 -p tcp -m tcp --dport 443 -j ACCEPT
 /usr/sbin/iptables -t nat -A POSTROUTING -s 172.17.0.2/32 -d 172.17.0.2/32 -p tcp -m tcp --dport 443 -j MASQUERADE
 /usr/sbin/iptables -t nat -A DOCKER ! -i docker0 -p tcp -m tcp --dport 443 -j DNAT --to-destination 172.17.0.2:443
fi
