# Docker 增加端口映射与管理端口转发教程

首先执行`docker inspect $container | grep IPAddress`查看运行中的容器所分配的IP，其中 $container 为你容器的名称或者 ID（运行`docker ps -a`可以看到所有运行中的容器列表），运行结果如下：
```bash
[root@localhost ~]# docker inspect ssr_ssh | grep IPAddress
"SecondaryIPAddresses": null,
"IPAddress": "172.17.0.2",
"IPAddress": "172.17.0.2",
```
然后执行如下命令增加端口转发映射，需要把IP和端口改成你需要的，其中`172.17.0.2`处为你的容器分配的IP，注意前两行`--dport 443`处为你容器内所要使用的端口，最后一行`--dport 8022`处为你宿主机想要对外开放到公网的端口，`--to-destination 172.17.0.2:22`处则填写你的容器IP和端口，示例如下：
```bash
iptables -t filter -A DOCKER -d 172.17.0.2/32 ! -i docker0 -o docker0 -p tcp -m tcp --dport 22 -j ACCEPT
iptables -t nat -A POSTROUTING -s 172.17.0.2/32 -d 172.17.0.2/32 -p tcp -m tcp --dport 22 -j MASQUERADE
iptables -t nat -A DOCKER ! -i docker0 -p tcp -m tcp --dport 8022 -j DNAT --to-destination 172.17.0.2:22
```
如果想要映射5000-10000端口段，则示例命令如下：
```bash
iptables -t filter -A DOCKER -d 172.17.0.2/32 ! -i docker0 -o docker0 -p tcp -m tcp --dport 5000:10000 -j ACCEPT
iptables -t nat -A POSTROUTING -s 172.17.0.2/32 -d 172.17.0.2/32 -p tcp -m tcp --dport 5000:10000 -j MASQUERADE
iptables -t nat -A DOCKER ! -i docker0 -p tcp -m tcp --dport 5000:10000 -j DNAT --to-destination 172.17.0.2:5000-10000
```
如需管理端口映射，首先执行`iptables -t filter -nvL --line-number`查看 filter 表的映射，Chain 后的 DOCKER 为链名，左边的数字为行号，这两项一会儿会用到：
```bash
[root@localhost ~]# iptables -t filter -nvL --line-number
··· ···
Chain DOCKER (1 references)
num   pkts bytes target     prot opt in     out     source               destination         
1        5   296 ACCEPT     tcp  --  !docker0 docker0  0.0.0.0/0            172.17.0.2           tcp dpt:22
2       40  2080 ACCEPT     tcp  --  !docker0 docker0  0.0.0.0/0            172.17.0.2           tcp dpt:543
3       74  4628 ACCEPT     tcp  --  !docker0 docker0  0.0.0.0/0            172.17.0.2           tcp dpt:443
··· ···
```
然后执行`iptables -t filter -D DOCKER 2`删除对应映射条目，其中 filter 为表名，DOCKER 为链名，2为所要删除的行号。   
   
同样需要删除 nat 表中的映射，执行`iptables -t nat -nvL --line-number`查看 filter 表，同样记住链名和行号：
```bash
[root@localhost ~]# iptables -t nat -nvL --line-number
··· ···
Chain POSTROUTING (policy ACCEPT 170 packets, 11244 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1      308 18460 MASQUERADE  all  --  *      !docker0  172.17.0.0/16        0.0.0.0/0           
2      253 16368 POSTROUTING_direct  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
3      253 16368 POSTROUTING_ZONES_SOURCE  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
4      253 16368 POSTROUTING_ZONES  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
5        0     0 MASQUERADE  tcp  --  *      *       172.17.0.2           172.17.0.2           tcp dpt:22
6        0     0 MASQUERADE  tcp  --  *      *       172.17.0.2           172.17.0.2           tcp dpt:543
7        0     0 MASQUERADE  tcp  --  *      *       172.17.0.2           172.17.0.2           tcp dpt:443

Chain DOCKER (2 references)
num   pkts bytes target     prot opt in     out     source               destination         
1        4   240 RETURN     all  --  docker0 *       0.0.0.0/0            0.0.0.0/0           
2        6   356 DNAT       tcp  --  !docker0 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:444 to:172.17.0.2:22
3       40  2080 DNAT       tcp  --  !docker0 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:543 to:172.17.0.2:543
4      114  7188 DNAT       tcp  --  !docker0 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:443 to:172.17.0.2:443
··· ···
```
然后执行`iptables -t nat -D POSTROUTING 6`和`iptables -t nat -D DOCKER 3`删除对应映射条目。 

---------

附：服务器开放对应端口命令
```bash
# tcp
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
# udp
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 33233 -j ACCEPT
```
自动映射容器端口脚本，使用方法
下载脚本
```bash
wget -N -no-check-certificate https://raw.githubusercontent.com/whunt1/docker_manage_port/master/autocheckdockerport.sh
```
然后执行`vim autocheckdockerport.sh`编辑好脚本，编辑内容如下，其中 "172.17.0.2:443" 为你要检测的容器IP及端口，iptables配置参见上文
```
RULER1=$(iptables -t nat -nvL --line-number | grep "172.17.0.2:443" | awk '{print $1}')
echo ${RULER1}
if [[ -z $RULER1 ]]; then
 echo "rebuild"
 iptables -t filter -A DOCKER -d 172.17.0.2/32 ! -i docker0 -o docker0 -p tcp -m tcp --dport 443 -j ACCEPT
 iptables -t nat -A POSTROUTING -s 172.17.0.2/32 -d 172.17.0.2/32 -p tcp -m tcp --dport 443 -j MASQUERADE
 iptables -t nat -A DOCKER ! -i docker0 -p tcp -m tcp --dport 443 -j DNAT --to-destination 172.17.0.2:443
fi
```
最后执行`chmod +x autocheckdockerport.sh`修改脚本权限，并执行`crontab -e`设定定时任务如下，注意修改为你存放脚本的位置
> * * * * * /bin/bash /root/autocheckdockerport.sh
