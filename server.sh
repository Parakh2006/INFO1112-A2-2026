
#!/bin/bash

server_port=1234

ip_address=$(ifconfig eth0 | grep "inet " | awk '{print $2}')
echo "The server is running at Link addr:$ip_address"
population_request() {
    url="https://dbr.abs.gov.au/processedData/csv/STE_1.csv"

    if ! curl -fsSL "$url" -o /root/population.csv; then
        echo "Error: Unable to download population data."
        return 1
    fi

    year_column=$(head -n 1 /root/population.csv | tr -d '\r' | tr ',' '\n' | grep -n '^2025$' | cut -d ':' -f 1)

    if [ -z "$year_column" ]; then
        echo "Error: 2025 population data not found."
        return 1
    fi

    population=$(awk -F ',' -v col="$year_column" '$1 == "ERP_P_20" {print $col; exit}' /root/population.csv)

    if [ -z "$population" ]; then
        echo "Error: NSW population not found."
        return 1
    fi

    echo "NSW population in 2025: $population"
}
show_port() {
    sleep 1
    listening_port=$(ss -ltn | awk -v p="$server_port" '$1 == "LISTEN" && $4 ~ ":" p "$" {print $4}' | cut -d ':' -f 2)

    if [ -n "$listening_port" ]; then
        echo "Listening on 0.0.0.0 $listening_port"
    fi
}

assignment_request() {
    url="https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC"

    if ! curl -fsSL "$url" -o /root/assignment.html; then
        echo "Error: Unable to download assignment webpage."
        return 1
    fi

    if ! html2text /root/assignment.html > /root/assignment.txt; then
        echo "Error: Unable to convert HTML into text."
        return 1
    fi

    assignment_info=$(grep -i -A 2 "Assignment 2" /root/assignment.txt)

    if [ -z "$assignment_info" ]; then
        echo "Error: Assignment 2 information not found."
        return 1
    fi

    echo "$assignment_info"
}

generate_assignment_json() {
    title=$(echo "$assignment_info" | grep -o "Assignment 2" | head -n 1)
    topic=$(echo "$assignment_info" | tail -n 1 | sed -E 's/^[[:space:]]*//; s/[[:space:]]+[0-9]+[[:space:]]*$//')

    points=$(echo "$assignment_info" | grep -oE '[0-9]+%' | head -n 1 | tr -d '%')
    day=$(echo "$assignment_info" | grep -oE 'Due date: [0-9]+' | awk '{print $3}')

    month_year_hour=$(echo "$assignment_info" | grep -oE '[A-Z][a-z]{2} [0-9]{4} at [0-9]{2}')
    minute=$(echo "$assignment_info" | tail -n 1 | grep -oE '[0-9]{2}' | head -n 1)

    if [ -z "$title" ] || [ -z "$topic" ] || [ -z "$points" ] || \
       [ -z "$day" ] || [ -z "$month_year_hour" ] || [ -z "$minute" ]; then
        echo "Error: Could not extract all assignment details."
        return 1
    fi

    due_date="$day $(echo "$month_year_hour" | sed 's/ at / /'):$minute"

    cat > /root/assignment.json <<EOF
{
  "title": "$title",
  "topic": "$topic",
  "due_date": "$due_date",
  "points": $points
}
EOF

    cat /root/assignment.json
}

show_port &

while true
do
    coproc NETCAT { nc -l -p "$server_port"; }
    sleep 0.1

    if IFS= read -r request <&"${NETCAT[0]}"; then
        client_address=$(ss -tn | awk -v p=":$server_port" '$4 ~ p "$" {print $5; exit}')

        if [ -n "$client_address" ]; then
            client_ip=$(echo "$client_address" | sed -E 's/^\[::ffff:([^]]+)\]:[0-9]+$/\1/')
            echo "Client connected from: $client_ip"
        else
            echo "Client connected"
        fi

        if [ "$request" = "assignment" ]; then
    if assignment_request >&"${NETCAT[1]}"; then
        generate_assignment_json >&"${NETCAT[1]}"
    fi

elif [ "$request" = "population" ]; then
    population_request >&"${NETCAT[1]}"

else
    echo "Error: Unknown request." >&"${NETCAT[1]}"
fi
    fi

    kill "$NETCAT_PID" 2>/dev/null
    wait "$NETCAT_PID" 2>/dev/null
done
