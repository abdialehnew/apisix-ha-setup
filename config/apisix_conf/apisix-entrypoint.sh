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

# Update config.yaml with ETCD endpoints
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
  node_listen: 9080
  enable_admin: true
  enable_admin_cors: true
EOF

# Run APISIX
exec /docker-entrypoint.sh "$@"
