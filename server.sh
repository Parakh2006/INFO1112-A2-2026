#!/bin/bash
server_port=1234
trap 'kill "$nc_pid" 2>/dev/null' EXIT
ip_address=$(ifconfig eth0 | grep "inet " | awk '{print $2}')
echo "The server is running at Link addr:$ip_address, port=$server_port"
nc -lk -p "$server_port" &
nc_pid=$!
listening_port=$(ss -ltn | awk -v p="$server_port" '$1 == "LISTEN" && $4 ~ ":" p "$" {print $4}' | cut -d ':' -f 2)
echo "Listening on port: $listening_port"
wait