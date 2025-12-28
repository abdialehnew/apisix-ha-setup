# Grafana Integration untuk Logging & Monitoring

## Overview

Setup ini mengintegrasikan APISIX dengan Grafana menggunakan:
- **Grafana Loki** - Log aggregation dan querying
- **Prometheus** - Metrics collection
- **Grafana** - Visualization dashboard

## Architecture

```
APISIX → HTTP Logger → Loki → Grafana (Logs)
       ↓
       → Prometheus → Grafana (Metrics)
```

## Setup Components

### 1. Add Loki & Grafana to Docker Compose

Edit `docker-compose.yml`, tambahkan services:

```yaml
  # Grafana Loki - Log Aggregation
  loki:
    image: grafana/loki:latest
    container_name: apisix-loki
    restart: always
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - apisix-network
    volumes:
      - ./config/loki/loki-config.yaml:/etc/loki/local-config.yaml
      - ./data/loki:/loki

  # Prometheus - Metrics Collection
  prometheus:
    image: prom/prometheus:latest
    container_name: apisix-prometheus
    restart: always
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    networks:
      - apisix-network
    volumes:
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./data/prometheus:/prometheus

  # Grafana - Visualization
  grafana:
    image: grafana/grafana:latest
    container_name: apisix-grafana
    restart: always
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    networks:
      - apisix-network
    volumes:
      - ./config/grafana/provisioning:/etc/grafana/provisioning
      - ./data/grafana:/var/lib/grafana
    depends_on:
      - loki
      - prometheus
```

### 2. Loki Configuration

Create `config/loki/loki-config.yaml`:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32
  max_query_length: 721h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: true
  retention_period: 720h

ruler:
  storage:
    type: local
    local:
      directory: /loki/rules
  rule_path: /loki/rules-temp
  alertmanager_url: http://localhost:9093
  ring:
    kvstore:
      store: inmemory
  enable_api: true
```

### 3. Prometheus Configuration

Create `config/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'apisix-cluster'
    environment: 'production'

scrape_configs:
  # APISIX Nodes Metrics
  - job_name: 'apisix'
    static_configs:
      - targets:
        - 'apisix-node1:9091'
        - 'apisix-node2:9091'
        - 'apisix-node3:9091'
        labels:
          cluster: 'apisix'
          
  # HAProxy Metrics (requires haproxy_exporter)
  - job_name: 'haproxy'
    static_configs:
      - targets:
        - 'apisix-haproxy:8404'
        labels:
          service: 'haproxy'
          
  # ETCD Metrics
  - job_name: 'etcd'
    static_configs:
      - targets:
        - 'apisix-etcd1:2379'
        - 'apisix-etcd2:2379'
        - 'apisix-etcd3:2379'
        labels:
          service: 'etcd'
```

### 4. Grafana Provisioning

Create `config/grafana/provisioning/datasources/datasources.yml`:

```yaml
apiVersion: 1

datasources:
  # Loki for Logs
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: false
    editable: true
    jsonData:
      maxLines: 1000
      
  # Prometheus for Metrics
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: 15s
```

Create `config/grafana/provisioning/dashboards/dashboards.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'APISIX Dashboards'
    orgId: 1
    folder: 'APISIX'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards/json
```

### 5. Configure APISIX to Send Logs to Loki

Edit `config/apisix_conf/config.yaml`:

```yaml
apisix:
  admin_audit_logs:
    enabled: true
    logging_plugin_name: http-logger
    logging_plugin_config:
      uri: http://loki:3100/loki/api/v1/push
      timeout: 3
      retry_delay: 1
      batch_max_size: 1000
      buffer_duration: 60
      headers:
        Content-Type: application/json
```

### 6. Add HTTP Logger to Routes for Data Plane Logs

```bash
docker exec apisix-node1 curl "http://127.0.0.1:9180/apisix/admin/global_rules/1" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -X PUT -d '{
    "plugins": {
        "http-logger": {
            "uri": "http://loki:3100/loki/api/v1/push",
            "timeout": 3,
            "batch_max_size": 1000,
            "include_req_body": false,
            "include_resp_body": false,
            "concat_method": "json"
        },
        "request-id": {
            "header_name": "X-Request-Id",
            "include_in_response": true
        }
    }
}'
```

Atau per-route:

```bash
docker exec apisix-node1 curl "http://127.0.0.1:9180/apisix/admin/routes/1" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -X PUT -d '{
    "uri": "/api/*",
    "upstream_id": 1,
    "plugins": {
        "http-logger": {
            "uri": "http://loki:3100/loki/api/v1/push",
            "timeout": 3,
            "include_req_body": true,
            "include_resp_body": false
        }
    }
}'
```

## Starting the Stack

### 1. Create Required Directories

```bash
mkdir -p config/loki config/prometheus config/grafana/provisioning/{datasources,dashboards/json}
mkdir -p data/loki data/prometheus data/grafana
```

### 2. Start All Services

```bash
docker-compose up -d
```

### 3. Verify Services

```bash
# Check all services are running
docker-compose ps

# Check Loki is ready
curl http://localhost:3100/ready

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Grafana
curl http://localhost:3000/api/health
```

## Accessing Grafana

### 1. Login to Grafana

Open browser: `http://localhost:3000`

**Default credentials:**
- Username: `admin`
- Password: `admin` (change on first login)

### 2. Verify Data Sources

1. Go to **Configuration → Data Sources**
2. Verify **Loki** and **Prometheus** are connected
3. Click "Test" on each datasource

## Creating Dashboards

### Dashboard 1: APISIX Request Logs

1. Create New Dashboard
2. Add Panel → Select **Loki** as data source
3. LogQL query examples:

**All APISIX logs:**
```logql
{job="apisix"}
```

**Filter by status code:**
```logql
{job="apisix"} |= "status" | json | status >= 400
```

**Count errors by route:**
```logql
sum by (route_id) (rate({job="apisix"} | json | status >= 500 [5m]))
```

**Top slowest requests:**
```logql
{job="apisix"} | json | latency > 1.0
```

**Request rate per minute:**
```logql
sum(rate({job="apisix"}[1m]))
```

### Dashboard 2: APISIX Metrics (Prometheus)

1. Create New Dashboard
2. Add Panel → Select **Prometheus** as data source
3. PromQL query examples:

**Total Requests:**
```promql
sum(rate(apisix_http_status[5m]))
```

**Request Rate by Status:**
```promql
sum by (code) (rate(apisix_http_status[5m]))
```

**Average Latency:**
```promql
histogram_quantile(0.95, rate(apisix_http_latency_bucket[5m]))
```

**Active Connections:**
```promql
apisix_nginx_http_current_connections
```

**Bandwidth Usage:**
```promql
rate(apisix_bandwidth[5m])
```

**Upstream Health:**
```promql
apisix_node_info{is_healthy="true"}
```

**ETCD Status:**
```promql
up{job="etcd"}
```

### Dashboard 3: Admin API Audit Logs

```logql
{job="apisix-admin"} 
| json 
| request_method != "GET"
| line_format "{{.timestamp}} - {{.client_ip}} - {{.request_method}} {{.request_uri}} - {{.response_status}}"
```

**Configuration changes:**
```logql
{job="apisix-admin"} 
| json 
| request_uri =~ "/apisix/admin/(routes|services|upstreams|consumers).*"
| request_method =~ "PUT|POST|DELETE"
```

## Advanced LogQL Queries

### 1. Error Rate Alert Query
```logql
sum(rate({job="apisix"} | json | status >= 500 [5m])) > 10
```

### 2. High Latency Detection
```logql
{job="apisix"} 
| json 
| latency > 2.0
| line_format "{{.method}} {{.uri}} took {{.latency}}s"
```

### 3. Failed Authentication Attempts
```logql
{job="apisix"} 
| json 
| status = 401 or status = 403
| line_format "{{.timestamp}} - {{.client_ip}} - {{.uri}}"
```

### 4. Top Error Routes
```logql
topk(10, 
  sum by (route_id) (
    count_over_time({job="apisix"} | json | status >= 400 [1h])
  )
)
```

### 5. Request Body Size Distribution
```logql
histogram_quantile(0.95,
  sum(rate({job="apisix"} | json | unwrap bytes_sent [5m])) by (le)
)
```

## Alert Rules

### Prometheus Alert Rules

Create `config/prometheus/alert_rules.yml`:

```yaml
groups:
  - name: apisix_alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: sum(rate(apisix_http_status{code=~"5.."}[5m])) > 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors/sec"
          
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(apisix_http_latency_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          description: "95th percentile latency is {{ $value }}s"
          
      - alert: NodeDown
        expr: up{job="apisix"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "APISIX node is down"
          description: "{{ $labels.instance }} is unreachable"
          
      - alert: ETCDDown
        expr: up{job="etcd"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "ETCD node is down"
          description: "{{ $labels.instance }} is unreachable"
```

Update `prometheus.yml`:
```yaml
rule_files:
  - /etc/prometheus/alert_rules.yml
```

### Loki Alert Rules

Create `config/loki/alert_rules.yml`:

```yaml
groups:
  - name: apisix_log_alerts
    interval: 1m
    rules:
      - alert: HighAuthFailureRate
        expr: |
          sum(rate({job="apisix"} | json | status = 401 [5m])) > 5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High authentication failure rate"
          
      - alert: SecurityScanDetected
        expr: |
          sum(count_over_time({job="apisix"} |~ "(?i)(union.*select|<script|\.\.\/|etc\/passwd)" [5m])) > 0
        labels:
          severity: critical
        annotations:
          summary: "Potential security scan detected"
```

## Pre-built Dashboards

### Import APISIX Community Dashboard

1. Go to **Create → Import**
2. Use Grafana Dashboard ID: **11719** (APISIX Official)
3. Select **Prometheus** as data source
4. Click **Import**

### Custom Dashboard JSON

Create `config/grafana/provisioning/dashboards/json/apisix-overview.json`:

```json
{
  "dashboard": {
    "title": "APISIX Overview",
    "tags": ["apisix", "gateway"],
    "timezone": "browser",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(apisix_http_status[5m]))",
            "refId": "A"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(apisix_http_status{code=~\"5..\"}[5m]))",
            "refId": "A"
          }
        ]
      },
      {
        "title": "Recent Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"apisix\"}",
            "refId": "A"
          }
        ]
      }
    ]
  }
}
```

## Troubleshooting

### Logs Not Appearing in Loki

```bash
# Check APISIX can reach Loki
docker exec apisix-node1 curl -v http://loki:3100/ready

# Check Loki logs
docker logs apisix-loki

# Test manual log push
curl -X POST http://localhost:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{"streams": [{"stream": {"job": "test"}, "values": [["'"$(date +%s)000000000"'", "test message"]]}]}'

# Query logs directly from Loki
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="apisix"}' | jq
```

### Prometheus Not Scraping

```bash
# Check targets status
curl http://localhost:9090/api/v1/targets | jq

# Check APISIX metrics endpoint
curl http://localhost:9091/apisix/prometheus/metrics

# Check Prometheus logs
docker logs apisix-prometheus
```

### Grafana Connection Issues

```bash
# Check Grafana logs
docker logs apisix-grafana

# Verify datasource connectivity from Grafana container
docker exec apisix-grafana curl http://loki:3100/ready
docker exec apisix-grafana curl http://prometheus:9090/-/ready
```

## Performance Tuning

### Loki Performance

```yaml
# In loki-config.yaml
limits_config:
  ingestion_rate_mb: 32        # Increase for high throughput
  ingestion_burst_size_mb: 64
  max_query_length: 0          # Unlimited query range
  max_streams_per_user: 10000  # Increase for many routes
```

### HTTP Logger Batching

```json
{
  "http-logger": {
    "batch_max_size": 5000,     // Batch more logs
    "buffer_duration": 30,       // Flush every 30s
    "inactive_timeout": 10,      // Timeout for inactive buffers
    "include_req_body": false    // Reduce payload size
  }
}
```

## Best Practices

1. **Use Labels Wisely**: Don't create too many unique label combinations in Loki
2. **Filter Early**: Apply filters in LogQL queries as early as possible
3. **Retention Policy**: Set appropriate retention (default: 30 days)
4. **Index Only What You Query**: Index fields you frequently filter on
5. **Use Metrics for Aggregations**: Use Prometheus for counts/rates, Loki for log details
6. **Dashboard Refresh**: Set reasonable refresh intervals (30s-1m)
7. **Alert Thresholds**: Start conservative and adjust based on actual traffic

## Security

### Enable Authentication

Add to `docker-compose.yml`:

```yaml
  grafana:
    environment:
      - GF_AUTH_BASIC_ENABLED=true
      - GF_AUTH_ANONYMOUS_ENABLED=false
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-changeme}
```

### Restrict Access

```yaml
  loki:
    environment:
      - LOKI_AUTH_ENABLED=true
      
  prometheus:
    command:
      - '--web.enable-admin-api'
      - '--web.enable-lifecycle'
      - '--storage.tsdb.retention.time=15d'
```

## References

- [Grafana Loki Documentation](https://grafana.com/docs/loki/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [APISIX Prometheus Plugin](https://apisix.apache.org/docs/apisix/plugins/prometheus/)
- [LogQL Syntax](https://grafana.com/docs/loki/latest/logql/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
