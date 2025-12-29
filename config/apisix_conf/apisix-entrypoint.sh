#!/bin/sh

# Wait for ETCD to be ready
echo "Waiting for ETCD cluster..."
sleep 5
echo "ETCD cluster should be ready!"

# Clean up old socket files and lock files
rm -f /usr/local/apisix/logs/*.sock 2>/dev/null || true
rm -f /usr/local/apisix/logs/*.pid 2>/dev/null || true

# Kill any orphaned nginx processes
pkill -9 nginx 2>/dev/null || true
sleep 1

# Set default admin key if not provided
ADMIN_KEY="${APISIX_ADMIN_KEY:-edd1c9f034335f136f87ad84b625c8f1}"
VIEWER_KEY="${APISIX_VIEWER_KEY:-4054f7cf07e344346cd3f287985e76a2}"

# Update config.yaml with complete configuration
cat > /usr/local/apisix/conf/config.yaml <<EOF
deployment:
  role: traditional
  role_traditional:
    config_provider: etcd
  etcd:
    host:
      - "http://etcd1:2379"
      - "http://etcd2:2379"
      - "http://etcd3:2379"
    prefix: /apisix
    timeout: 30
    startup_retry: 2
  admin:
    admin_key:
      - name: admin
        key: ${ADMIN_KEY}
        role: admin
      - name: viewer
        key: ${VIEWER_KEY}
        role: viewer
    admin_listen:
      ip: 0.0.0.0
      port: 9180
    https_admin: false
    admin_api_version: v3
    allow_admin:
      - 0.0.0.0/0

apisix:
  node_listen:
    - 9080
  enable_admin: true
  enable_admin_cors: true
  enable_dev_mode: false
  enable_reuseport: true
  enable_ipv6: true
  
  config_center: etcd
  
  allow_admin:
    - 0.0.0.0/0
  
  port_admin: 9180
  
  admin_audit_logs:
    enabled: true
    logging_plugin_name: file-logger
    logging_plugin_config:
      path: /usr/local/apisix/logs/admin_audit.log
      max_size: 104857600
      max_days: 30

  router:
    http: radixtree_uri
    ssl: radixtree_sni

  dns_resolver:
    - 127.0.0.11
    - 8.8.8.8
    - 1.1.1.1
  dns_resolver_valid: 30

nginx_config:
  error_log: /usr/local/apisix/logs/error.log
  error_log_level: warn
  
  worker_processes: auto
  worker_rlimit_nofile: 20480
  worker_shutdown_timeout: 240s
  
  event:
    worker_connections: 10620
  
  http:
    enable_access_log: true
    access_log: /usr/local/apisix/logs/access.log
    access_log_format: '\$remote_addr - \$remote_user [\$time_local] \$http_host "\$request" \$status \$body_bytes_sent \$request_time "\$http_referer" "\$http_user_agent" \$upstream_addr \$upstream_status \$upstream_response_time "\$upstream_scheme://\$upstream_host\$upstream_uri"'
    access_log_format_escape: default
    
    keepalive_timeout: 60s
    client_header_timeout: 60s
    client_body_timeout: 60s
    client_max_body_size: 0
    send_timeout: 10s
    
    underscores_in_headers: "on"
    real_ip_header: X-Real-IP
    
    lua_shared_dict:
      internal-status: 10m
      plugin-limit-req: 10m
      plugin-limit-count: 10m
      plugin-limit-conn: 10m
      prometheus-metrics: 10m
      plugin-api-breaker: 10m
      tracing_buffer: 10m
      plugin-limit-count-redis-cluster-slot-lock: 1m
      upstream-healthcheck: 32m
      worker-events: 10m
      lrucache-lock: 10m
      balancer-ewma: 10m
      balancer-ewma-locks: 10m
      balancer-ewma-last-touched-at: 10m
      plugin-limit-count-redis: 10m
      plugin-limit-count-local: 1m

plugins:
  - real-ip
  - client-control
  - proxy-control
  - request-id
  - zipkin
  - ext-plugin-pre-req
  - fault-injection
  - mocking
  - serverless-pre-function
  - cors
  - ip-restriction
  - ua-restriction
  - referer-restriction
  - csrf
  - uri-blocker
  - request-validation
  - openid-connect
  - authz-casbin
  - authz-casdoor
  - wolf-rbac
  - ldap-auth
  - hmac-auth
  - basic-auth
  - jwt-auth
  - key-auth
  - consumer-restriction
  - forward-auth
  - opa
  - serverless-post-function
  - ext-plugin-post-req
  - proxy-cache
  - proxy-mirror
  - proxy-rewrite
  - workflow
  - api-breaker
  - limit-conn
  - limit-count
  - limit-req
  - gzip
  - server-info
  - traffic-split
  - redirect
  - response-rewrite
  - degraphql
  - kafka-proxy
  - grpc-transcode
  - grpc-web
  - public-api
  - prometheus
  - datadog
  - echo
  - loggly
  - http-logger
  - splunk-hec-logging
  - skywalking-logger
  - google-cloud-logging
  - sls-logger
  - tcp-logger
  - kafka-logger
  - rocketmq-logger
  - syslog
  - udp-logger
  - file-logger
  - clickhouse-logger
  - tencent-cloud-cls
  - inspect
  - example-plugin

stream_plugins:
  - ip-restriction
  - limit-conn
  - mqtt-proxy
  - syslog

plugin_attr:
  prometheus:
    export_addr:
      ip: 0.0.0.0
      port: 9091
    export_uri: /apisix/prometheus/metrics
    metric_prefix: apisix_
    enable_export_server: true

  skywalking:
    service_name: APISIX
    service_instance_name: APISIX Instance Name
    endpoint_addr: http://127.0.0.1:12800
EOF

# Run APISIX
exec /docker-entrypoint.sh "$@"
