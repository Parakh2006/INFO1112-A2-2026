# INFO1112 Assignment 2

### Environment
Bash TCP server running in Alpine Linux (Docker), using port `1234`.

Requires Bash, BusyBox Netcat, curl, html2text, Python 3, Matplotlib, net-tools and iproute2.

### Run the server

The Alpine container must be running with port `1234` mapped to the host.

```bash
docker cp server.sh myserver:/root/server.sh
docker exec -it myserver bash /root/server.sh
```

### Client requests

Run these in a separate host terminal.

**Assignment information**
```bash
echo "assignment" | nc localhost 1234
```

**NSW population**
```bash
echo "population" | nc localhost 1234
```

**Nearby points of interest**
```bash
echo "where am I? -33.8886 151.1873" | nc localhost 1234
```

### Generated files

The following files are saved inside the Alpine container under `/root/`.

| File | Contents |
|---|---|
| `assignment.json` | Assignment details |
| `population.png` | NSW population graph |
| `pois.json` | Nearby cafés in JSON format |

To view the population graph on the host:

```bash
docker cp myserver:/root/population.png ./population_graph.png
```

To inspect the JSON files:

```bash
docker exec myserver cat /root/assignment.json
docker exec myserver cat /root/pois.json
```

Replace `myserver` with the container name used in your environment.

### Testing

`testA_server_offline.png` contains the offline-server test evidence.

`gitCommit.log` contains the Git commit history.