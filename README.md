# Apache APISIX High Availability Setup

Setup Docker Compose untuk Apache APISIX dengan konfigurasi High Availability (HA).

## Arsitektur

Setup ini mencakup:
- **3 Node APISIX** - untuk load balancing dan high availability
- **3 Node ETCD** - cluster untuk menyimpan konfigurasi
- **1 APISIX Dashboard** - untuk manajemen via UI
- **1 HAProxy** - load balancer untuk mendistribusikan traffic ke APISIX nodes

## 🚀 Roadmap & Future Enhancements

**Coming Soon:**
- [ ] **Prometheus & Grafana** - Advanced monitoring and metrics visualization
  - APISIX metrics collection
  - ETCD cluster monitoring
  - HAProxy performance metrics
  - Custom dashboards for API Gateway analytics
  - Alert rules for critical events

## Struktur Direktori

```
apisix/
├── docker-compose.yml
├── config/
│   ├── apisix_conf/
│   │   └── config.yaml          # Konfigurasi APISIX
│   ├── dashboard_conf/
│   │   └── conf.yaml             # Konfigurasi Dashboard
│   └── haproxy/
│       └── haproxy.cfg           # Konfigurasi HAProxy
├── data/
│   ├── etcd1/                    # Data ETCD node 1
│   ├── etcd2/                    # Data ETCD node 2
│   └── etcd3/                    # Data ETCD node 3
├── logs/
│   ├── apisix1/                  # Logs APISIX node 1
│   ├── apisix2/                  # Logs APISIX node 2
│   ├── apisix3/                  # Logs APISIX node 3
│   ├── dashboard/                # Logs Dashboard
│   └── haproxy/                  # Logs HAProxy
└── .env                          # Environment variables
```

## Ports yang Digunakan

### Akses Publik (melalui HAProxy)
- **8070** - HTTP traffic (load balanced ke 3 APISIX nodes)
- **7443** - HTTPS traffic (load balanced ke 3 APISIX nodes)
- **9000** - APISIX Dashboard
- **8404** - HAProxy Statistics

### Akses Direct ke APISIX Nodes (opsional)
- **9180** - APISIX Node 1 HTTP
- **9543** - APISIX Node 1 HTTPS
- **9181** - APISIX Node 2 HTTP
- **9544** - APISIX Node 2 HTTPS
- **9182** - APISIX Node 3 HTTP
- **9545** - APISIX Node 3 HTTPS

## Cara Menggunakan

### 1. Persiapan Awal

Buat direktori yang diperlukan:
```bash
mkdir -p config/apisix_conf config/dashboard_conf config/haproxy
mkdir -p data/etcd1 data/etcd2 data/etcd3
mkdir -p logs/apisix1 logs/apisix2 logs/apisix3 logs/dashboard logs/haproxy
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

### 5. Testing

Test koneksi ke APISIX:
```bash
# Via load balancer
curl http://localhost:8070/

# Direct ke node tertentu
curl http://localhost:9180/
curl http://localhost:9181/
curl http://localhost:9182/
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

Akses HAProxy stats:
```
http://localhost:8404/stats
```

Verifikasi semua backend UP di HAProxy:
```bash
curl -s "http://localhost:8404/stats;csv" | grep "apisix_http_backend,apisix" | cut -d',' -f1,2,18
```

Output yang diharapkan:
```
apisix_http_backend,apisix1,UP
apisix_http_backend,apisix2,UP
apisix_http_backend,apisix3,UP
```

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

### HAProxy Configuration (`config/haproxy/haproxy.cfg`)

Konfigurasi load balancer:
- Frontend/backend settings
- Health check configuration
- Load balancing algorithm (roundrobin)

## Admin API

APISIX Admin API dapat diakses di:
- Node 1: `http://localhost:9180/apisix/admin`
- Node 2: `http://localhost:9181/apisix/admin`
- Node 3: `http://localhost:9182/apisix/admin`

Example request:
```bash
curl "http://127.0.0.1:9180/apisix/admin/routes" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1"
```

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
