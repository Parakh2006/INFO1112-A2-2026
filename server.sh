
#!/bin/bash

server_port=1234

ip_address=$(ifconfig eth0 | grep "inet " | awk '{print $2}')

echo "The server is running at Link addr:$ip_address"

show_port() {
    sleep 1

    listening_port=$(ss -ltn | awk -v p="$server_port" '$1 == "LISTEN" && $4 ~ ":" p "$" {print $4}' | cut -d ':' -f 2)

    if [ -n "$listening_port" ]; then
        echo "Listening on 0.0.0.0 $listening_port"
    fi
}

show_client() {
    while true
    do
        client_ip=$(ss -tn | awk -v p=":$server_port" '$1 == "ESTAB" && $4 ~ p "$" {print $5}' | cut -d ':' -f 4 | tr -d ']')

        if [ -n "$client_ip" ]; then
            echo "Client connected from: $client_ip"
            break
        fi

        sleep 1
    done
}

show_port &
show_client &

# Keep the server listening for connections
while true
do
    nc -l -p "$server_port" -e /root/handler.sh || break
done
