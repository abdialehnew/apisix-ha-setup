# Apache APISIX High Availability Setup

**English** | **[Bahasa Indonesia](README.md)**

Docker Compose setup for Apache APISIX with High Availability (HA) configuration.

## Architecture

This setup includes:
- **3 APISIX Nodes** - for load balancing and high availability
- **3 ETCD Nodes** - cluster for configuration storage
- **1 APISIX Dashboard** - for UI-based management
- **1 HAProxy** - load balancer to distribute traffic across APISIX nodes

## 🚀 Roadmap & Future Enhancements

**Coming Soon:**
- [ ] **Prometheus & Grafana** - Advanced monitoring and metrics visualization
  - APISIX metrics collection
  - ETCD cluster monitoring
  - HAProxy performance metrics
  - Custom dashboards for API Gateway analytics
  - Alert rules for critical events

## Directory Structure

```
apisix/
├── docker-compose.yml
├── config/
│   ├── apisix_conf/
│   │   └── config.yaml          # APISIX configuration
│   ├── dashboard_conf/
│   │   └── conf.yaml             # Dashboard configuration
│   └── haproxy/
│       └── haproxy.cfg           # HAProxy configuration
├── data/
│   ├── etcd1/                    # ETCD node 1 data
│   ├── etcd2/                    # ETCD node 2 data
│   └── etcd3/                    # ETCD node 3 data
├── logs/
│   ├── apisix1/                  # APISIX node 1 logs
│   ├── apisix2/                  # APISIX node 2 logs
│   ├── apisix3/                  # APISIX node 3 logs
│   ├── dashboard/                # Dashboard logs
│   └── haproxy/                  # HAProxy logs
└── .env                          # Environment variables
```

## Port Mappings

### Public Access (via HAProxy)
- **8070** - HTTP traffic (load balanced to 3 APISIX nodes)
- **7443** - HTTPS traffic (load balanced to 3 APISIX nodes)
- **9000** - APISIX Dashboard
- **8404** - HAProxy Statistics

### Direct Access to APISIX Nodes (optional)
- **9180** - APISIX Node 1 HTTP
- **9543** - APISIX Node 1 HTTPS
- **9181** - APISIX Node 2 HTTP
- **9544** - APISIX Node 2 HTTPS
- **9182** - APISIX Node 3 HTTP
- **9545** - APISIX Node 3 HTTPS

## Getting Started

### 1. Initial Setup

Create required directories:
```bash
# mkdir -p config/apisix_conf config/dashboard_conf config/haproxy
mkdir -p data/etcd1 data/etcd2 data/etcd3
mkdir -p logs/apisix1 logs/apisix2 logs/apisix3 logs/dashboard logs/haproxy
```

### 2. Configure Environment Variables

Copy `.env.example` to `.env` and customize:
```bash
cp .env.example .env
```

**IMPORTANT**: Change admin keys and passwords in production!

### 3. Start Services

Launch all services:
```bash
docker-compose up -d
```

Check service status:
```bash
docker-compose ps
```

View logs:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f apisix1
docker-compose logs -f etcd1
docker-compose logs -f haproxy
```

### 4. Access Dashboard

Open your browser and navigate to:
```
http://localhost:9000
```

Default credentials:
- Username: `admin`
- Password: `admin`

### 5. Testing

Test APISIX connection:
```bash
# Via load balancer
curl http://localhost:8070/

# Direct to specific node
curl http://localhost:9180/
curl http://localhost:9181/
curl http://localhost:9182/
```

Expected response (with no configured routes):
```json
{"error_msg":"404 Route Not Found"}
```

Test ETCD cluster:
```bash
docker exec apisix-etcd1 etcdctl endpoint health --cluster
docker exec apisix-etcd1 etcdctl member list
```

Access HAProxy stats:
```
http://localhost:8404/stats
```

Verify all backends are UP in HAProxy:
```bash
curl -s "http://localhost:8404/stats;csv" | grep "apisix_http_backend,apisix" | cut -d',' -f1,2,18
```

Expected output:
```
apisix_http_backend,apisix1,UP
apisix_http_backend,apisix2,UP
apisix_http_backend,apisix3,UP
```

## Configuration

### APISIX Configuration (`config/apisix_conf/config.yaml`)

This file contains the main APISIX configuration:
- Node listen ports
- ETCD connection settings
- Plugin configuration
- Nginx configuration
- Admin API settings

To modify:
1. Edit `config/apisix_conf/config.yaml`
2. Restart APISIX nodes: `docker-compose restart apisix1 apisix2 apisix3`

### Dashboard Configuration (`config/dashboard_conf/conf.yaml`)

APISIX Dashboard configuration:
- Listen port
- ETCD endpoints
- Authentication settings
- Enabled plugins

### HAProxy Configuration (`config/haproxy/haproxy.cfg`)

Load balancer configuration:
- Frontend/backend settings
- Health check configuration
- Load balancing algorithm (roundrobin)

## Admin API

APISIX Admin API can be accessed at:
- Node 1: `http://localhost:9180/apisix/admin`
- Node 2: `http://localhost:9181/apisix/admin`
- Node 3: `http://localhost:9182/apisix/admin`

Example request:
```bash
curl "http://127.0.0.1:9180/apisix/admin/routes" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1"
```

## Monitoring & Healthcheck

All services have healthchecks:
- **ETCD**: `etcdctl endpoint health`
- **APISIX**: HTTP request using `/dev/tcp` with bash
- **Dashboard**: HTTP request to port 9000
- **HAProxy**: config validation

Check healthcheck status of all services:
```bash
docker-compose ps
```

Expected output (all healthy):
```
NAME               STATUS
apisix-dashboard   Up X minutes (healthy)
apisix-etcd1       Up X hours (healthy)
apisix-etcd2       Up X hours (healthy)
apisix-etcd3       Up X hours (healthy)
apisix-haproxy     Up X minutes (healthy)
apisix-node1       Up X minutes (healthy)
apisix-node2       Up X minutes (healthy)
apisix-node3       Up X minutes (healthy)
```

## Scaling

To add an APISIX node:

1. Edit `docker-compose.yml`, add a new node:
```yaml
apisix4:
  image: apache/apisix:latest
  container_name: apisix-node4
  # ... (same as apisix1-3)
```

2. Update `config/haproxy/haproxy.cfg`:
```
server apisix4 apisix4:9080 check inter 2000 rise 2 fall 3
```

3. Restart:
```bash
docker-compose up -d
docker-compose restart haproxy
```

## Backup & Restore

### Backup ETCD Data
```bash
docker exec apisix-etcd1 etcdctl snapshot save /etcd-data/backup.db
```

### Backup Logs
```bash
tar -czf logs-backup-$(date +%Y%m%d).tar.gz logs/
```

### Backup Configuration
```bash
tar -czf config-backup-$(date +%Y%m%d).tar.gz config/
```

## Troubleshooting

### APISIX cannot connect to ETCD
```bash
# Check ETCD health
docker exec apisix-etcd1 etcdctl endpoint health --cluster

# Check ETCD logs
docker-compose logs etcd1 etcd2 etcd3

# Check ETCD endpoints configuration in APISIX
docker exec apisix-node1 cat /usr/local/apisix/conf/config.yaml | grep -A 5 etcd
```

### HAProxy shows APISIX node DOWN
```bash
# Check if APISIX is actually running
docker-compose ps

# Test connection from another container
docker exec apisix-dashboard curl -s http://apisix2:9080/

# Restart HAProxy to refresh backend connections
docker-compose restart haproxy

# Verify backend status
curl -s "http://localhost:8404/stats;csv" | grep "apisix_http_backend,apisix"
```

**Note**: If APISIX nodes are recreated, HAProxy may still have stale connections.
Solution: `docker-compose restart haproxy`

### APISIX node stuck at "init_etcd"
```bash
# Check logs
docker-compose logs apisix2

# Restart problematic container
docker-compose restart apisix2

# If still problematic, recreate
docker-compose up -d --force-recreate apisix2
```

### Healthcheck shows "unhealthy"
```bash
# Check detailed healthcheck logs
docker inspect apisix-node1 | jq '.[0].State.Health'

# Test healthcheck command manually
docker exec apisix-node1 bash -c "exec 3<>/dev/tcp/127.0.0.1/9080 && echo -e 'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n' >&3 && cat <&3"
```

### Performance Issues
```bash
# View resource usage
docker stats

# Increase worker processes in config.yaml
nginx_config:
  worker_processes: auto  # or specific number
```

## Security

**IMPORTANT for Production:**

1. **Change Admin Keys**:
   - Edit `config/apisix_conf/config.yaml`
   - Replace all admin keys with strong random values

2. **Change Dashboard Password**:
   - Edit `config/dashboard_conf/conf.yaml`
   - Change username/password

3. **Restrict Admin Access**:
   - Edit `allow_admin` in `config.yaml`
   - Limit to specific IPs

4. **Enable HTTPS**:
   - Configure SSL certificates
   - Set `https_admin: true`

5. **ETCD Security**:
   - Enable ETCD authentication
   - Set `ALLOW_NONE_AUTHENTICATION=no`
   - Configure mTLS

## Stop Services

```bash
# Stop all
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Stop without removing containers
docker-compose stop
```

## References

- [APISIX Documentation](https://apisix.apache.org/docs/)
- [APISIX Dashboard](https://github.com/apache/apisix-dashboard)
- [HAProxy Documentation](http://www.haproxy.org/)
- [ETCD Documentation](https://etcd.io/docs/)

## License

This project is open source and available under the [Apache License 2.0](LICENSE).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues, questions, or contributions, please open an issue on GitHub.
