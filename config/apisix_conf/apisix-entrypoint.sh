#!/bin/sh

# Wait for ETCD to be ready
echo "Waiting for ETCD cluster..."
max_attempts=30
attempt=0
until nc -z etcd1 2379 2>/dev/null; do
  attempt=$((attempt + 1))
  if [ $attempt -ge $max_attempts ]; then
    echo "ETCD not available after $max_attempts attempts, starting anyway..."
    break
  fi
  echo "ETCD not ready, waiting... (attempt $attempt/$max_attempts)"
  sleep 2
done
echo "ETCD cluster is ready!"

# Clean up old socket files and lock files
rm -f /usr/local/apisix/logs/*.sock 2>/dev/null || true
rm -f /usr/local/apisix/logs/*.pid 2>/dev/null || true

# Kill any orphaned nginx processes
pkill -9 nginx 2>/dev/null || true
sleep 1

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
        key: edd1c9f034335f136f87ad84b625c8f1
        role: admin

apisix:
  node_listen: 9080
  enable_admin: true
  enable_admin_cors: true
  allow_admin:
    - 0.0.0.0/0
  admin_listen:
    port: 9180
EOF

# Run APISIX
exec /docker-entrypoint.sh "$@"
