# Audit Logging & Configuration Tracking

## Overview

APISIX setup ini dilengkapi dengan **native Admin API audit logging** untuk tracking semua aktivitas dan perubahan konfigurasi menggunakan fitur bawaan APISIX.

## Native Admin Audit Logs

APISIX menyediakan fitur native `admin_audit_logs` yang automatically track semua perubahan konfigurasi melalui Admin API.

### Configuration

Di `config.yaml`:
```yaml
apisix:
  admin_audit_logs:
    enabled: true
    logging_plugin_name: file-logger
    logging_plugin_config:
      path: /usr/local/apisix/logs/admin_audit.log
      max_size: 104857600  # 100MB
      max_days: 30
```

### Alternative Logging Plugins

#### 1. File Logger (Default)
```yaml
apisix:
  admin_audit_logs:
    enabled: true
    logging_plugin_name: file-logger
    logging_plugin_config:
      path: /usr/local/apisix/logs/admin_audit.log
      max_size: 104857600
      max_days: 30
```

#### 2. HTTP Logger (Centralized Logging)
```yaml
apisix:
  admin_audit_logs:
    enabled: true
    logging_plugin_name: http-logger
    logging_plugin_config:
      uri: http://elasticsearch:9200/apisix-audit/_doc
      timeout: 3
      retry_delay: 1
      batch_max_size: 1000
      buffer_duration: 60
```

#### 3. Kafka Logger (Real-time Streaming)
```yaml
apisix:
  admin_audit_logs:
    enabled: true
    logging_plugin_name: kafka-logger
    logging_plugin_config:
      broker_list:
        kafka-server:9092: {}
      kafka_topic: apisix-admin-audit
      timeout: 3
      batch_max_size: 1000
```

#### 4. Elasticsearch Logger
```yaml
apisix:
  admin_audit_logs:
    enabled: true
    logging_plugin_name: elasticsearch-logger
    logging_plugin_config:
      endpoint: http://elasticsearch:9200
      index: apisix-admin-audit
      timeout: 3
```

#### 5. Syslog
```yaml
apisix:
  admin_audit_logs:
    enabled: true
    logging_plugin_name: syslog
    logging_plugin_config:
      host: 127.0.0.1
      port: 514
      flush_limit: 1
      timeout: 3000
```

## Log Files

### 1. Admin Audit Log (Native) ⭐
**Location**: `logs/apisix{1,2,3}/admin_audit.log`

**RECOMMENDED**: Native APISIX feature yang automatic track semua Admin API operations.

Records all Admin API changes with full context:
```json
{
  "client_ip": "192.168.1.50",
  "route_id": "1",
  "request": {
    "method": "PUT",
    "uri": "/apisix/admin/routes/1",
    "headers": {
      "X-API-KEY": "edd***"
    },
    "body": {
      "uri": "/api/*",
      "upstream_id": 1,
      "plugins": {
        "jwt-auth": {}
      }
    }
  },
  "response": {
    "status": 201,
    "body": {
      "action": "set",
      "node": {
        "key": "/apisix/routes/1",
        "value": {...}
      }
    }
  },
  "latency": 0.025,
  "@timestamp": "2025-12-24T10:35:20Z"
}
```

Benefits:
- ✅ Automatic - tidak perlu konfigurasi manual per route
- ✅ Structured logging (JSON format)
- ✅ Complete request/response tracking
- ✅ Multiple logger backend support
- ✅ Built-in log rotation

### 2. Access Log (Data Plane)
**Location**: `logs/apisix{1,2,3}/access.log`

Records all incoming requests to the API Gateway:
```
Format: IP - User [Time] Host "Request" Status BytesSent ResponseTime "Referer" "UserAgent" UpstreamAddr UpstreamStatus UpstreamResponseTime "UpstreamURL" request_id:RequestID
```

Example:
```
192.168.1.100 - - [24/Dec/2025:10:30:45 +0000] api.example.com "POST /api/users HTTP/1.1" 200 1234 0.025 "-" "curl/7.68.0" 10.0.1.50:8080 200 0.023 "http://backend:8080/api/users" request_id:550e8400-e29b-41d4-a716-446655440000
```

### 2. Access Log (Data Plane)
**Location**: `logs/apisix{1,2,3}/access.log`

Records all incoming requests to the API Gateway:
```
Format: IP - User [Time] Host "Request" Status BytesSent ResponseTime "Referer" "UserAgent" UpstreamAddr UpstreamStatus UpstreamResponseTime "UpstreamURL" request_id:RequestID
```

Example:
```
192.168.1.100 - - [24/Dec/2025:10:30:45 +0000] api.example.com "POST /api/users HTTP/1.1" 200 1234 0.025 "-" "curl/7.68.0" 10.0.1.50:8080 200 0.023 "http://backend:8080/api/users" request_id:550e8400-e29b-41d4-a716-446655440000
```

### 3. Error Log
**Location**: `logs/apisix{1,2,3}/error.log`

Records errors, warnings, and important events:
```
2025/12/24 10:40:15 [warn] 123#123: *456 upstream timed out (110: Connection timed out) while connecting to upstream
```

### 4. Custom Route Audit Log (Optional)
```json
{
  "timestamp": "2025-12-24T10:45:30Z",
  "client_ip": "192.168.1.100",
  "method": "POST",
  "uri": "/api/users",
  "status": 200,
  "latency": 0.025,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_agent": "curl/7.68.0",
  "request_body": "{\"name\":\"John Doe\"}",
  "response_body": "{\"id\":123,\"status\":\"created\"}"
}
```

## Enabling Audit Logging on Routes

**Note**: Admin API audit logging sudah **automatic enabled** melalui native `admin_audit_logs` configuration. Section ini hanya untuk per-route data plane logging.

### Option 1: File Logger (Local Storage)

```bash
docker exec apisix-node1 curl "http://127.0.0.1:9180/apisix/admin/routes/1" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -X PUT -d '{
    "uri": "/api/*",
    "upstream_id": 1,
    "plugins": {
        "file-logger": {
            "path": "/usr/local/apisix/logs/route_audit.log"
        },
        "request-id": {
            "header_name": "X-Request-Id",
            "include_in_response": true
        }
    }
}'
```

### Option 2: HTTP Logger (Centralized Logging)

Send logs to external logging service (ELK, Splunk, etc.):

```bash
docker exec apisix-node1 curl "http://127.0.0.1:9180/apisix/admin/routes/1" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -X PUT -d '{
    "uri": "/api/*",
    "upstream_id": 1,
    "plugins": {
        "http-logger": {
            "uri": "http://logging-service:9200/api/logs",
            "auth_header": "Bearer YOUR_TOKEN",
            "timeout": 3,
            "batch_max_size": 1000,
            "include_req_body": true,
            "include_resp_body": true
        },
        "request-id": {}
    }
}'
```

### Option 3: Syslog (System Logger)

```bash
docker exec apisix-node1 curl "http://127.0.0.1:9180/apisix/admin/routes/1" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -X PUT -d '{
    "uri": "/api/*",
    "upstream_id": 1,
    "plugins": {
        "syslog": {
            "host": "127.0.0.1",
            "port": 514,
            "flush_limit": 1,
            "timeout": 3000,
            "include_req_body": true
        }
    }
}'
```

### Option 4: Kafka Logger (Real-time Streaming)

```bash
docker exec apisix-node1 curl "http://127.0.0.1:9180/apisix/admin/routes/1" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -X PUT -d '{
    "uri": "/api/*",
    "upstream_id": 1,
    "plugins": {
        "kafka-logger": {
            "broker_list": {
                "kafka-server:9092": {}
            },
            "kafka_topic": "apisix-audit-logs",
            "timeout": 3,
            "batch_max_size": 1000,
            "include_req_body": true,
            "include_resp_body": true
        }
    }
}'
```

## Global Audit Logging

**Note**: Admin audit logging sudah global by default dengan native `admin_audit_logs`. Ini untuk data plane logging.

Enable audit logging for ALL routes using Global Rules:

```bash
docker exec apisix-node1 curl "http://127.0.0.1:9180/apisix/admin/global_rules/1" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -X PUT -d '{
    "plugins": {
        "file-logger": {
            "path": "/usr/local/apisix/logs/route_audit.log"
        },
        "request-id": {
            "header_name": "X-Request-Id",
            "include_in_response": true
        }
    }
}'
```

## Quick Start Examples

### 1. Basic Setup (File Logger)
Sudah configured by default melalui native admin_audit_logs. Untuk verify:
**Location**: `logs/apisix{1,2,3}/route_audit.log`

Per-route detailed audit trail (when file-logger plugin enabled on specific routes):
```json
{
  "timestamp": "2025-12-24T10:45:30Z",
  "client_ip": "192.168.1.100",
  "method": "POST",
  "uri": "/api/users",
  "status": 200,
  "latency": 0.025,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_agent": "curl/7.68.0",
  "request_body": "{\"name\":\"John Doe\"}",
  "response_body": "{\"id\":123,\"status\":\"created\"}"
}
```

## Monitoring Admin API Changes

### Real-time Monitoring

**Native Admin Audit Log (Recommended):**
```bash
# Monitor admin audit log (structured JSON)
docker exec apisix-node1 tail -f /usr/local/apisix/logs/admin_audit.log | jq '.'

# Filter specific operations
docker exec apisix-node1 tail -f /usr/local/apisix/logs/admin_audit.log | jq 'select(.request.method == "DELETE")'

# Track specific resource changes
docker exec apisix-node1 grep "routes/1" /usr/local/apisix/logs/admin_audit.log | jq '.'
```

### Track Configuration Changes

```bash
# List all route changes
docker exec apisix-node1 jq 'select(.request.uri | contains("/routes"))' /usr/local/apisix/logs/admin_audit.log

# Track who made changes (by API key)
docker exec apisix-node1 jq '.request.headers."X-API-KEY"' /usr/local/apisix/logs/admin_audit.log | sort | uniq -c

# Changes in last hour
docker exec apisix-node1 jq --arg time "$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M')" \
  'select(."@timestamp" > $time)' /usr/local/apisix/logs/admin_audit.log
```

## Log Rotation

Logs automatically rotate based on configuration:
- **Max size**: 100MB per file
- **Retention**: 30 days
- **Compression**: Gzip for old logs

### Manual Log Rotation
```bash
# Rotate access logs
docker exec apisix-node1 sh -c "mv /usr/local/apisix/logs/access.log /usr/local/apisix/logs/access.log.$(date +%Y%m%d-%H%M%S) && kill -USR1 \$(cat /usr/local/apisix/logs/nginx.pid)"

# Rotate admin logs
docker exec apisix-node1 sh -c "mv /usr/local/apisix/logs/admin_access.log /usr/local/apisix/logs/admin_access.log.$(date +%Y%m%d-%H%M%S) && kill -USR1 \$(cat /usr/local/apisix/logs/nginx.pid)"
```

## Log Analysis Examples

### Most Active IPs
```bash
docker exec apisix-node1 awk '{print $1}' /usr/local/apisix/logs/access.log | sort | uniq -c | sort -rn | head -10
```

### Response Status Distribution
```bash
docker exec apisix-node1 awk '{print $9}' /usr/local/apisix/logs/access.log | sort | uniq -c | sort -rn
```

### Average Response Time
```bash
docker exec apisix-node1 awk '{sum+=$11; count++} END {print sum/count}' /usr/local/apisix/logs/access.log
```

### Failed Requests (4xx, 5xx)
```bash
docker exec apisix-node1 awk '$9 >= 400' /usr/local/apisix/logs/access.log
```

### Admin API Changes by User
```bash
docker exec apisix-node1 grep "admin_key:" /usr/local/apisix/logs/admin_access.log | awk -F'admin_key:' '{print $2}' | sort | uniq -c
```

## Integration with External Tools

### Elasticsearch + Kibana

Use HTTP Logger to send logs to Elasticsearch:
```json
{
    "http-logger": {
        "uri": "http://elasticsearch:9200/apisix-logs/_doc",
        "timeout": 3,
        "batch_max_size": 1000
    }
}
```

### Prometheus + Grafana

APISIX exposes metrics at:
```
http://localhost:9091/apisix/prometheus/metrics
```

Add to `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'apisix'
    static_configs:
      - targets: 
        - 'apisix-node1:9091'
        - 'apisix-node2:9091'
        - 'apisix-node3:9091'
```

### Splunk

```bash
docker exec apisix-node1 curl "http://127.0.0.1:9180/apisix/admin/routes/1" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -X PUT -d '{
    "plugins": {
        "splunk-hec-logging": {
            "endpoint": {
                "uri": "https://splunk:8088/services/collector",
                "token": "YOUR_HEC_TOKEN"
            },
            "ssl_verify": false
        }
    }
}'
```

## Security Considerations

### 1. Protect Log Files
```bash
# Set appropriate permissions
chmod 600 logs/apisix*/admin_access.log
```

### 2. Mask Sensitive Data

Configure to exclude sensitive headers:
```json
{
    "file-logger": {
        "path": "/usr/local/apisix/logs/audit.log",
        "include_req_body": false,
        "include_req_body_expr": [
            ["arg_password", "~*", ".*"]
        ]
    }
}
```

### 3. Limit Log Retention
```bash
# Auto-cleanup old logs (add to crontab)
0 2 * * * find /path/to/logs -name "*.log.*" -mtime +30 -delete
```

## Troubleshooting

### Logs Not Being Written
```bash
# Check permissions
docker exec apisix-node1 ls -la /usr/local/apisix/logs/

# Check disk space
docker exec apisix-node1 df -h /usr/local/apisix/logs/

# Restart APISIX
docker-compose restart apisix1 apisix2 apisix3
```

### High Log Volume
```bash
# Reduce log level
# Edit config.yaml: error_log_level: error

# Disable access log for specific routes
{
    "plugins": {
        "file-logger": {
            "path": "/dev/null"
        }
    }
}
```

## Best Practices

1. **Enable Request ID** on all routes for request tracing
2. **Use structured logging** (JSON format) for easier parsing
3. **Implement log rotation** to prevent disk space issues
4. **Monitor Admin API** access for security audit
5. **Set up alerts** for suspicious activities
6. **Regular backup** of audit logs for compliance
7. **Use centralized logging** for multi-node deployments

## Compliance Requirements

This logging configuration supports:
- **SOC 2**: Audit trail of all system changes
- **PCI DSS**: Transaction logging and monitoring
- **GDPR**: Data access tracking
- **HIPAA**: Healthcare data access audit
- **ISO 27001**: Security event logging

## References

- [APISIX Logging Plugins](https://apisix.apache.org/docs/apisix/plugins/file-logger/)
- [APISIX Admin API](https://apisix.apache.org/docs/apisix/admin-api/)
- [Log Format Variables](https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format)
