#!/bin/bash
# =====================================
#     Author: sandow
#     Email: j.k.yulei@gmail.com
#     HomePage: www.gsandow.com
# =====================================
ports_dis(){
	app=$1
	pids=$(ps -ef |grep memcache|grep -v grep |awk '{printf "%s|" ,$2}'|sed 's/|$//g')
	sudo netstat -lntup|egrep $pids |egrep -v 'tcp6|udp6'|awk -F '[: ]+' '{print $5}'|sort|uniq
	#ports=$(netstat -lntup|egrep $pids |egrep -v 'tcp6|udp6'|awk -F '[: ]+' '{printf "%s\r\n",$5}'|sort|uniq)
	#export ports_name="${app}_ports"
	#to_json  $ports_name "$ports"
}
to_json(){
	key=$1
	shift
	readarray -t array_data <<< "$@"
	#array_data=("$@")
	local num=${#array_data[@]}
	printf '{'
	printf '"data":[ '
	for line in "${array_data[@]}";do
		APP_NAME=$(echo $line | awk -F '[ :\r]+' '{print $1}')
		APP_TYPE=$(printf "$line"| awk -F '[: \r]+' '{print $2}')
		APP_VALUE=$(printf "$line"| awk -F '[: \r]+' '{print $3}')
		#[ -z $APP_NAME ]   && continue
		#[ $APP_NAME == '#' ]  && continue
		#[ -z  $APP_VALUE ]  && continue
		printf '{'
		printf "\"{#$key}\":\"${APP_NAME}\", \"{#APP_TYPE}\":\"${APP_TYPE}\", \"{#APP_VALUE}\":\"${APP_VALUE}\"}"
		#printf "\"}"
       		((num--))
        	[ "$num" == 0 ] && break
        	printf ","
	done
	printf ']'
	printf '}'
}
tcp_status_fun(){
	TCP_STAT=$1
	TCP_DATA=$(ss -ant | awk 'NR>1 {++s[$1]} END {for(k in s) print k,s[k]}')
	if [ $TCP_STAT == "discovery" ];then
		to_json "$TCP_DATA"
	else
		TCP_STAT_VALUE=$(echo $TCP_DATA|sed -r 's/([0-9]) /\1\n/g' |grep "$TCP_STAT"  | cut -d ' ' -f2)
		if [ -z $TCP_STAT_VALUE ];then
			TCP_STAT_VALUE=0
		fi
		echo $TCP_STAT_VALUE
	fi
	#netstat -n | awk '/^tcp/ {++state[$NF]} END {for(key in state) print key,state[key]}' > /tmp/netstat.tmp
}
memcached_status_fun(){
	ARG=$1  # key or discovery
	PORT=$2
	TYPE=$3
	#ports=$(ports_dis memcached)
	ports=11211
	if  [ $ARG == "discovery" ];then
		for port in ${ports[@]};do
			export mem_discovery=$mem_discovery$(echo -e "stats\nquit" | nc 127.0.0.1 $port|sed '/END/d' \
			|awk -v v1=$port '{if($3 + 0 == $3) {print $2 ,"num", v1 } else {print $2, "string", v1}}')

		done
		to_json "MEM_KEY" "$mem_discovery"
	else
		#echo -e "stats\nquit" | nc 127.0.0.1 "$M_PORT" | grep "STAT $M_COMMAND " | awk '{print $3}'
		mem_status=$(echo -e "stats\nquit" | nc 127.0.0.1 $PORT|sed 's/STAT //g;/^END/d')
		echo "${mem_status[@]}"|awk -v v1=$ARG '{if ($1==v1)print $2}' 
	fi
}

redis_cluster_status_fun(){
	ARG=$1
	PORT=$2
	TYPE=$3
	[ "$@" == 1 ] && to_json "$redis_status" "redis_key"
	echo -ne "cluster info\r\n"|nc 127.0.0.1 $R_PORT|awk -F ':' -v v1=$R_COMMAND '{if($1==v1) print $NF}'
}
redis_status_fun(){
	ARG=$1
	PORT=$2
	TYPE=$3
	PORTS=6379
	opt="s/(db[0-9]+):.*([0-9]+),.*=([0-9]+),.*=([0-9]+)/\1_keys:\2\n\1_expires:\3\n\1_avg_ttl:\4/g"
	if  [ $ARG == "discovery" ];then
		for port in  ${PORTS[@]};do
			export redis_discovery=${redis_discovery}$(echo -ne "info\r\n"|nc 127.0.0.1 $port|sed -re $opt -e '/^#/d' -e '/^\r/d' -e '/^\$/d' \
			|awk -v v1=$port -F: '{if($2 + 0 == $2) {print $1 ,"num", v1 } else {print $1, "string", v1}}')
		done
		to_json "REDIS_KEY" "$redis_discovery"
	else
		echo -ne "info\r\n"|nc 127.0.0.1 $PORT| sed -re $opt -e '/^#/d' -e '/^\r/d' -e '/^\$/d' \
			|awk -F ':' -v v1=$ARG '{if($1==v1) print $NF}'
	fi
	#redis_status=$(echo -ne "info\r\n"|nc 127.0.0.1 $R_PORT|sed -re $opt -e '/^#/d' -e '/^\r/d' -e '/^\$/d')
	#[ $# -eq 1 ] && to_json "redis_key" "$redis_status"
}

nginx_status_fun(){
	NGINX_PORT=$1
	NGINX_COMMAND=$2
    NGINX_URL="http://127.0.0.1:"$NGINX_PORT"/nginx_status/"
#    NGINX_DATA=$(/usr/bin/curl $NGINX_URL 2>/dev/null)
    NGINX_DATA=$(/usr/bin/wget -q http://127.0.0.1:"$NGINX_PORT"/nginx_status -O - 2>/dev/null)
    #echo "$NGINX_DATA"
  	case $NGINX_COMMAND in
		active)    echo "$NGINX_DATA"| awk 'NR==1{print $NF}' ;;
		reading)   echo "$NGINX_DATA"| awk 'NR==4{print $2}'  ;;
		writing)   echo "$NGINX_DATA"| awk 'NR==4{print $4}'  ;;
		waiting)   echo "$NGINX_DATA"| awk 'NR==4{print $6}'  ;;
		accepts)   echo "$NGINX_DATA"| awk 'NR==3{print $1}'  ;;
		handled)   echo "$NGINX_DATA"| awk 'NR==3{print $2}'  ;;
		requests)  echo "$NGINX_DATA"| awk 'NR==3{print $3}'  ;;
		esac 
}
phpfpm_status_fun() {
	PHPFPM_COMMAND=$2
	PHPFPM_PORT=$1
	PHPFPM_URL="http://127.0.0.1:"$PHPFPM_PORT"/phpfpm_status"
	PHPFPM_DATA=$(/usr/bin/wget -q $PHPFPM_URL -O - 2>/dev/null)

	case $PHPFPM_COMMAND in
	start_since)        echo "$PHPFPM_DATA" |awk '/^start since:/ {print $NF}'  ;;
	accepted_conn)      echo "$PHPFPM_DATA" |awk '/^accepted conn:/ {print $NF}' ;;
	listen_queue)       echo "$PHPFPM_DATA" |awk '/^listen queue:/ {print $NF}' ;;
	max_listen_queue)   echo "$PHPFPM_DATA" |awk '/^max listen queue:/ {print $NF}' ;;
	listen_queue_len)   echo "$PHPFPM_DATA" |awk '/^listen queue len:/ {print $NF}' ;;
	idle_processes)     echo "$PHPFPM_DATA" |awk '/^idle processes:/ {print $NF}' ;;
	active_processes)   echo "$PHPFPM_DATA" |awk '/^active processes:/ {print $NF}' ;;
	total_processes)    echo "$PHPFPM_DATA" |awk '/^total processes:/ {print $NF}';;
	max_active_processes) echo "$PHPFPM_DATA" |awk '/^max active processes:/ {print $NF}' ;;
	max_children_reached)  echo "$PHPFPM_DATA" |awk '/^max children reached:/ {print $NF}'  ;;
	slow_requests)      echo "$PHPFPM_DATA" |awk '/^slow requests:/ {print $NF}';;
	*) echo $"USAGE:$0 "
	esac

}
main(){
	case $1 in
		tcp_status)
			tcp_status_fun $2;
			;;
		nginx)
			nginx_status_fun $2 $3;
			;;
		memcached)
			memcached_status_fun $2 $3 $4;
			;;
		redis)
			redis_status_fun "$2" "$3" "$4" ;
			;;
		redis_cluster)
			redis_cluster_status_fun $2 $3 $4;
			;;
		phpfpm)
			phpfpm_status_fun $2 $3;
			;;
		*)
			echo $"Usage: $0 {tcp_status key|memcached_status key|redis_status key|nginx_status key}"
	esac
}

main $1 $2 $3 $4
