# Apache APISIX High Availability Setup

**[English](README_EN.md)** | **Bahasa Indonesia**

Setup Docker Compose untuk Apache APISIX dengan konfigurasi High Availability (HA).

## Arsitektur

Setup ini mencakup:
- **3 Node APISIX** - untuk load balancing dan high availability
- **3 Node ETCD** - cluster untuk menyimpan konfigurasi
- **1 APISIX Dashboard** - untuk manajemen via UI
- **1 HAProxy** - load balancer untuk mendistribusikan traffic ke APISIX nodes
- **Grafana Stack** - monitoring dan visualization
  - **Grafana Loki** - log aggregation
  - **Prometheus** - metrics collection
  - **Grafana** - visualization dashboard

## ✨ Features

- ✅ **High Availability** - 3 APISIX nodes dengan load balancing
- ✅ **Distributed Configuration** - ETCD cluster 3 nodes
- ✅ **Admin API Audit Logging** - Native APISIX audit logs untuk tracking semua perubahan
- ✅ **Monitoring & Metrics** - Prometheus + Grafana untuk real-time monitoring
- ✅ **Log Aggregation** - Loki untuk centralized logging
- ✅ **Alert Rules** - Automated alerts untuk performance issues
- ✅ **Grafana Embedding** - Dashboard dapat di-embed di APISIX Dashboard
- ✅ **HAProxy Stats** - Built-in Prometheus exporter

## 🚀 Roadmap & Future Enhancements

**✅ Implemented:**
- [x] **Prometheus & Grafana** - Advanced monitoring and metrics visualization
  - APISIX metrics collection (port 9091-9093)
  - ETCD cluster monitoring
  - HAProxy performance metrics with Prometheus exporter
  - Custom dashboards for API Gateway analytics
  - Alert rules for critical events (latency, errors, node health)
  - See [Grafana Logging Documentation](docs/GRAFANA_LOGGING.md)
  
- [x] **Audit Logging & Configuration Tracking** - Comprehensive logging system
  - Native Admin API audit logging
  - Request/response audit trail
  - Configuration change tracking
  - Multiple logger options (File, HTTP, Syslog, Kafka, Elasticsearch)
  - Request ID for distributed tracing
  - See [Audit Logging Documentation](docs/AUDIT_LOGGING.md)

- [x] **Grafana Embedding** - Dashboard integration
  - CSP headers configured for iframe embedding
  - Anonymous access enabled untuk embedded panels
  - See [Grafana Embedding Guide](docs/GRAFANA_EMBEDDING.md)

## Struktur Direktori

```
apisix/
├── docker-compose.yml
├── config/
│   ├── apisix_conf/
│   │   ├── config.yaml              # Konfigurasi APISIX
│   │   └── apisix-entrypoint.sh     # Custom entrypoint
│   ├── dashboard_conf/
│   │   └── conf.yaml                # Konfigurasi Dashboard
│   ├── haproxy/
│   │   └── haproxy.cfg              # Konfigurasi HAProxy
│   ├── grafana/
│   │   ├── grafana.ini              # Grafana config
│   │   └── provisioning/            # Auto-provisioning
│   │       ├── datasources/         # Loki & Prometheus
│   │       └── dashboards/          # Dashboard definitions
│   ├── loki/
│   │   └── loki-config.yaml         # Loki configuration
│   └── prometheus/
│       ├── prometheus.yml           # Prometheus config
│       └── alert_rules.yml          # Alert rules
├── data/                            # (gitignored)
│   ├── etcd1/                       # Data ETCD node 1
│   ├── etcd2/                       # Data ETCD node 2
│   ├── etcd3/                       # Data ETCD node 3
│   ├── grafana/                     # Grafana data
│   ├── loki/                        # Loki data
│   └── prometheus/                  # Prometheus data
├── logs/                            # (gitignored)
│   ├── apisix1/                     # Logs APISIX node 1
│   ├── apisix2/                     # Logs APISIX node 2
│   ├── apisix3/                     # Logs APISIX node 3
│   ├── dashboard/                   # Logs Dashboard
│   └── haproxy/                     # Logs HAProxy
├── docs/
│   ├── AUDIT_LOGGING.md             # Audit logging guide
│   ├── GRAFANA_LOGGING.md           # Grafana integration
│   └── GRAFANA_EMBEDDING.md         # Embedding guide
└── .env                             # Environment variables
```

## Ports yang Digunakan

### Akses Publik (melalui HAProxy)
- **8070** - HTTP traffic (load balanced ke 3 APISIX nodes)
- **7443** - HTTPS traffic (load balanced ke 3 APISIX nodes)
- **8404** - HAProxy Statistics & Prometheus metrics

### Dashboard & Monitoring
- **9000** - APISIX Dashboard
- **3000** - Grafana Dashboard
- **9090** - Prometheus UI
- **3100** - Loki API

### APISIX Metrics
- **9091** - APISIX Node 1 Prometheus metrics
- **9092** - APISIX Node 2 Prometheus metrics
- **9093** - APISIX Node 3 Prometheus metrics

### Akses Direct ke APISIX Nodes (opsional)
- **9180** - APISIX Node 1 HTTP
- **9280** - APISIX Node 1 Admin API
- **9543** - APISIX Node 1 HTTPS
- **9181** - APISIX Node 2 HTTP
- **9281** - APISIX Node 2 Admin API
- **9544** - APISIX Node 2 HTTPS
- **9182** - APISIX Node 3 HTTP
- **9282** - APISIX Node 3 Admin API
- **9545** - APISIX Node 3 HTTPS

## Cara Menggunakan

### 1. Persiapan Awal

Buat direktori yang diperlukan:
```bash
# Config directories
mkdir -p config/{apisix_conf,dashboard_conf,haproxy,grafana/provisioning/{datasources,dashboards/json},loki,prometheus}

# Data directories (akan di-gitignore)
mkdir -p data/{etcd1,etcd2,etcd3,grafana,loki,prometheus}

# Log directories (akan di-gitignore)
mkdir -p logs/{apisix1,apisix2,apisix3,dashboard,haproxy}

# Set permissions
chmod -R 777 data/
```

### 2. Konfigurasi Environment Variables

Copy file `.env.example` ke `.env` dan sesuaikan:
```bash
cp .env.example .env
```

**PENTING**: Ganti admin key dan password di production!

### 3. Start Services

Jalankan semua services:
```bash
docker-compose up -d
```

Cek status services:
```bash
docker-compose ps
```

Lihat logs:
```bash
# Semua services
docker-compose logs -f

# Service tertentu
docker-compose logs -f apisix1
docker-compose logs -f etcd1
docker-compose logs -f haproxy
```

### 4. Akses Dashboard

Buka browser dan akses:
```
http://localhost:9000
```

Default credentials:
- Username: `admin`
- Password: `admin`

### 5. Akses Monitoring & Dashboard

**APISIX Dashboard:**
```
http://localhost:9000
```
Default credentials: `admin` / `admin`

**Grafana Dashboard:**
```
http://localhost:3000
```
Default credentials: `admin` / `admin`

Dashboards available:
- APISIX Simple Dashboard - Real-time API gateway metrics
- APISIX Official Dashboard (ID: 17957)

**Prometheus UI:**
```
http://localhost:9090
```
- Metrics explorer
- Alert rules
- Target status

**HAProxy Stats:**
```
http://localhost:8404/stats
```
- Backend health
- Connection stats
- Traffic metrics

### 6. Testing

Test koneksi ke APISIX:
```bash
# Via load balancer
curl http://localhost:8070/

# Direct ke node tertentu
curl http://localhost:9180/
curl http://localhost:9181/
curl http://localhost:9182/

# Check Prometheus metrics
curl http://localhost:9091/apisix/prometheus/metrics | head -20
```

Response yang diharapkan (tanpa route yang dikonfigurasi):
```json
{"error_msg":"404 Route Not Found"}
```

Test ETCD cluster:
```bash
docker exec apisix-etcd1 etcdctl endpoint health --cluster
docker exec apisix-etcd1 etcdctl member list
```

Verify Prometheus targets:
```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
```

Semua targets harus status `"health": "up"`:
- apisix (3 nodes)
- etcd (3 nodes)
- haproxy (1 node)
- prometheus (1 node)

## Konfigurasi

### APISIX Configuration (`config/apisix_conf/config.yaml`)

File ini berisi konfigurasi utama APISIX:
- Node listen ports
- ETCD connection settings
- Plugin configuration
- Nginx configuration
- Admin API settings

Untuk memodifikasi:
1. Edit file `config/apisix_conf/config.yaml`
2. Restart APISIX nodes: `docker-compose restart apisix1 apisix2 apisix3`

### Dashboard Configuration (`config/dashboard_conf/conf.yaml`)

Konfigurasi APISIX Dashboard:
- Listen port
- ETCD endpoints
- Authentication settings
- Enabled plugins
- CSP policy untuk Grafana embedding

### HAProxy Configuration (`config/haproxy/haproxy.cfg`)

Konfigurasi load balancer:
- Frontend/backend settings
- Health check configuration
- Load balancing algorithm (roundrobin)
- Prometheus metrics exporter di `/metrics`

### Monitoring Stack

**Prometheus** (`config/prometheus/prometheus.yml`):
- Scrape configs untuk APISIX, ETCD, HAProxy
- Metrics retention: 15 days
- Scrape interval: 15s

**Alert Rules** (`config/prometheus/alert_rules.yml`):
- HighLatency: p95 > 2s
- SlowResponseTime: p50 > 2s per route
- VerySlowRequests: p99 > 2s
- HighErrorRate: 5xx > 10/sec
- NodeDown alerts

**Grafana** (`config/grafana/grafana.ini`):
- Anonymous access enabled
- CSP disabled untuk iframe embedding
- Auto-provisioned datasources (Loki + Prometheus)

**Loki** (`config/loki/loki-config.yaml`):
- Log retention: 30 days
- Storage: filesystem

## Admin API

APISIX Admin API dapat diakses melalui docker exec atau dari host (jika port di-expose):

**Via Docker Exec (Recommended):**
```bash
# List all routes
docker exec apisix-node1 curl -s http://127.0.0.1:9180/apisix/admin/routes \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1"

# Create a route
docker exec apisix-node1 curl http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -X PUT -d '{
    "uri": "/api/*",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "httpbin.org:80": 1
      }
    }
  }'
```

**Via Host (if exposed):**
```bash
curl "http://localhost:9280/apisix/admin/routes" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1"
```

Admin API ports:
- Node 1: 9280
- Node 2: 9281
- Node 3: 9282

## Monitoring & Healthcheck

Semua services memiliki healthcheck:
- **ETCD**: `etcdctl endpoint health`
- **APISIX**: HTTP request menggunakan `/dev/tcp` dengan bash
- **Dashboard**: HTTP request ke port 9000
- **HAProxy**: config validation

Cek status healthcheck semua services:
```bash
docker-compose ps
```

Output yang diharapkan (semua healthy):
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

Untuk menambah APISIX node:

1. Edit `docker-compose.yml`, tambahkan node baru:
```yaml
apisix4:
  image: apache/apisix:latest
  container_name: apisix-node4
  # ... (sama seperti apisix1-3)
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

### Backup Konfigurasi
```bash
tar -czf config-backup-$(date +%Y%m%d).tar.gz config/
```

## Troubleshooting

### APISIX tidak bisa connect ke ETCD
```bash
# Cek ETCD health
docker exec apisix-etcd1 etcdctl endpoint health --cluster

# Cek ETCD logs
docker-compose logs etcd1 etcd2 etcd3

# Cek konfigurasi ETCD endpoints di APISIX
docker exec apisix-node1 cat /usr/local/apisix/conf/config.yaml | grep -A 5 etcd
```

### HAProxy menunjukkan APISIX node DOWN
```bash
# Cek apakah APISIX benar-benar berjalan
docker-compose ps

# Test koneksi dari container lain
docker exec apisix-dashboard curl -s http://apisix2:9080/

# Restart HAProxy untuk refresh backend connections
docker-compose restart haproxy

# Verifikasi backend status
curl -s "http://localhost:8404/stats;csv" | grep "apisix_http_backend,apisix"
```

**Catatan**: Jika APISIX node di-recreate, HAProxy mungkin masih memiliki koneksi lama. 
Solusinya: `docker-compose restart haproxy`

### APISIX node stuck di "init_etcd"
```bash
# Cek logs
docker-compose logs apisix2

# Restart container yang bermasalah
docker-compose restart apisix2

# Jika masih bermasalah, recreate
docker-compose up -d --force-recreate apisix2
```

### Healthcheck menunjukkan "unhealthy"
```bash
# Cek detail healthcheck logs
docker inspect apisix-node1 | jq '.[0].State.Health'

# Test healthcheck command secara manual
docker exec apisix-node1 bash -c "exec 3<>/dev/tcp/127.0.0.1/9080 && echo -e 'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n' >&3 && cat <&3"
```

### Performance Issues
```bash
# Lihat resource usage
docker stats

# Increase worker processes di config.yaml
nginx_config:
  worker_processes: auto  # atau angka spesifik
```

## Security

**PENTING untuk Production:**

1. **Ganti Admin Keys**:
   - Edit `config/apisix_conf/config.yaml`
   - Ganti semua admin keys dengan nilai random yang kuat

2. **Ganti Dashboard Password**:
   - Edit `config/dashboard_conf/conf.yaml`
   - Ganti username/password

3. **Restrict Admin Access**:
   - Edit `allow_admin` di `config.yaml`
   - Batasi ke IP tertentu

4. **Enable HTTPS**:
   - Konfigurasi SSL certificates
   - Set `https_admin: true`

5. **ETCD Security**:
   - Enable ETCD authentication
   - Set `ALLOW_NONE_AUTHENTICATION=no`
   - Configure mTLS

## Stop Services

```bash
# Stop semua
docker-compose down

# Stop dan hapus volumes
docker-compose down -v

# Stop tanpa remove containers
docker-compose stop
```

## Referensi

- [APISIX Documentation](https://apisix.apache.org/docs/)
- [APISIX Dashboard](https://github.com/apache/apisix-dashboard)
- [HAProxy Documentation](http://www.haproxy.org/)
- [ETCD Documentation](https://etcd.io/docs/)
