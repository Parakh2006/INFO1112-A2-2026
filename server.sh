
#!/bin/bash

server_port=1234

ip_address=$(ifconfig eth0 | grep "inet " | awk '{print $2}')
echo "The server is running at Link addr:$ip_address, port=$server_port"
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
  awk -F ',' '
NR == 1 {
    for (i = 4; i <= NF; i++) {
        gsub(/\r/, "", $i)
        years[i] = $i
    }
}
$1 == "ERP_P_20" {
    for (i = 4; i <= NF; i++) {
        gsub(/\r/, "", $i)
        if ($i != "" && years[i] ~ /^20[0-9][0-9]$/)
            print years[i] "," $i
    }
}
' /root/population.csv > /root/population_data.csv
}
generate_population_graph() {
    if [ ! -s /root/population_data.csv ]; then
        echo "Error: No population data available for plotting."
        return 1
    fi

    python3 - <<'PY'
# AI acknowledgement: Python plotting code developed with ChatGPT assistance.
import csv
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

years = []
populations = []

with open("/root/population_data.csv", newline="") as file:
    for year, population in csv.reader(file):
        years.append(int(year))
        populations.append(int(population))

plt.figure(figsize=(9, 5))
plt.plot(years, populations, marker="o")
plt.xlabel("Year")
plt.ylabel("Population")
plt.title("NSW Estimated Resident Population")
plt.grid(True)
plt.tight_layout()
plt.savefig("/root/population.png")
plt.close()
PY

    if [ ! -s /root/population.png ]; then
        echo "Error: Population graph could not be generated."
        return 1
    fi

    echo "Population graph saved to /root/population.png"
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
poi_request() {
    latitude="$1"
    longitude="$2"

    # Search area approximately 500 metres around the coordinates
    north=$(awk -v lat="$latitude" 'BEGIN {print lat + 0.0045}')
    south=$(awk -v lat="$latitude" 'BEGIN {print lat - 0.0045}')
    east=$(awk -v lon="$longitude" 'BEGIN {print lon + 0.0054}')
    west=$(awk -v lon="$longitude" 'BEGIN {print lon - 0.0054}')

    viewbox="$west,$north,$east,$south"

    if ! curl -fsS --max-time 20 -G \
        "https://nominatim.openstreetmap.org/search" \
        -H "User-Agent: INFO1112-Student-Project/1.0" \
        --data-urlencode "amenity=cafe" \
        --data-urlencode "viewbox=$viewbox" \
        --data-urlencode "bounded=1" \
        --data-urlencode "format=json" \
        --data-urlencode "limit=10" \
        -o /root/pois.json; then

        echo "Error: Unable to retrieve nearby POIs."
        return 1
    fi

    if [ ! -s /root/pois.json ]; then
        echo "Error: No POI data received."
        return 1
    fi

    echo "Nearby POIs retrieved successfully."
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
    if population_request >&"${NETCAT[1]}"; then
        generate_population_graph >&"${NETCAT[1]}"
    fi

   
elif [[ "$request" == "where am I? "* ]]; then
    coordinates="${request#where am I? }"

    read -r latitude longitude <<< "$coordinates"

    if [[ "$latitude" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] &&
       [[ "$longitude" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then

        if poi_request "$latitude" "$longitude" >&"${NETCAT[1]}"; then
           python3 -m json.tool /root/pois.json >&"${NETCAT[1]}"
        fi
    else
        echo "Error: Invalid coordinates." >&"${NETCAT[1]}"
    fi

else
    echo "Error: Unknown request." >&"${NETCAT[1]}"
fi
    fi

    kill "$NETCAT_PID" 2>/dev/null
    wait "$NETCAT_PID" 2>/dev/null
done
