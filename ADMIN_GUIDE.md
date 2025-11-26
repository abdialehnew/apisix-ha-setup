# APISIX Admin API Guide

## Problem yang Sudah Diperbaiki

Error sebelumnya: `{"error_msg":"404 Route Not Found"}` saat akses admin API

### Penyebab Masalah:
1. **Admin key hardcoded** - Key di `apisix-entrypoint.sh` tidak match dengan `.env`
2. **Port mapping salah** - Port host tidak dipetakan ke admin API port (9180)
3. **Konfigurasi allow_admin** - Tidak tepat di struktur config deployment v3

### Solusi yang Diterapkan:
1. ✅ Update `apisix-entrypoint.sh` untuk menggunakan environment variable `APISIX_ADMIN_KEY` dan `APISIX_VIEWER_KEY`
2. ✅ Tambahkan port mapping untuk admin API di semua node APISIX
3. ✅ Perbaiki struktur konfigurasi untuk APISIX v3 dengan `deployment.admin.allow_admin`

## Port Mapping

### Node APISIX 1
- **Data Plane**: http://localhost:9180 (→ container:9080)
- **Admin API**: http://localhost:9280 (→ container:9180)
- **HTTPS**: https://localhost:9543 (→ container:9443)

### Node APISIX 2
- **Data Plane**: http://localhost:9181 (→ container:9080)
- **Admin API**: http://localhost:9281 (→ container:9180)
- **HTTPS**: https://localhost:9544 (→ container:9443)

### Node APISIX 3
- **Data Plane**: http://localhost:9182 (→ container:9080)
- **Admin API**: http://localhost:9282 (→ container:9180)
- **HTTPS**: https://localhost:9545 (→ container:9443)

## Admin API Credentials

Dari file `.env`:
- **Admin Key**: `edd1c9f034335f136f87ad84b625c8f1` (role: admin - full access)
- **Viewer Key**: `4054f7cf07e344346cd3f287985e76a2` (role: viewer - read only)

## Cara Menggunakan Admin API

### 1. List All Routes
```bash
curl http://localhost:9280/apisix/admin/routes \
  -H 'X-API-KEY: 4054f7cf07e344346cd3f287985e76a2'
```

### 2. Get Specific Route
```bash
curl http://localhost:9280/apisix/admin/routes/{route_id} \
  -H 'X-API-KEY: 4054f7cf07e344346cd3f287985e76a2'
```

### 3. Create New Route
```bash
curl http://localhost:9280/apisix/admin/routes \
  -H 'X-API-KEY: 4054f7cf07e344346cd3f287985e76a2' \
  -X PUT -d '{
    "uri": "/api/test",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "backend:8080": 1
      }
    }
  }'
```

### 4. Update Route
```bash
curl http://localhost:9280/apisix/admin/routes/{route_id} \
  -H 'X-API-KEY: 4054f7cf07e344346cd3f287985e76a2' \
  -X PATCH -d '{
    "status": 1
  }'
```

### 5. Delete Route
```bash
curl http://localhost:9280/apisix/admin/routes/{route_id} \
  -H 'X-API-KEY: 4054f7cf07e344346cd3f287985e76a2' \
  -X DELETE
```

### 6. List Services
```bash
curl http://localhost:9280/apisix/admin/services \
  -H 'X-API-KEY: 4054f7cf07e344346cd3f287985e76a2'
```

### 7. List Upstreams
```bash
curl http://localhost:9280/apisix/admin/upstreams \
  -H 'X-API-KEY: 4054f7cf07e344346cd3f287985e76a2'
```

### 8. List Consumers
```bash
curl http://localhost:9280/apisix/admin/consumers \
  -H 'X-API-KEY: 4054f7cf07e344346cd3f287985e76a2'
```

### 9. List Plugins
```bash
curl http://localhost:9280/apisix/admin/plugins/list \
  -H 'X-API-KEY: 4054f7cf07e344346cd3f287985e76a2'
```

### 10. Check APISIX Version
```bash
curl http://localhost:9280/apisix/admin/schema \
  -H 'X-API-KEY: 4054f7cf07e344346cd3f287985e76a2'
```

## Load Balancing

Untuk production, gunakan HAProxy yang sudah dikonfigurasi untuk load balancing ke semua node:
- **HAProxy HTTP**: http://localhost:8070
- **HAProxy HTTPS**: https://localhost:7443
- **HAProxy Stats**: http://localhost:8404/stats

## Tips

1. **Gunakan Viewer Key** untuk operasi read-only di production
2. **Semua node** APISIX berbagi state yang sama via ETCD cluster
3. **Admin API v3** digunakan (lihat header `X-API-VERSION: v3` di response)
4. **CORS enabled** untuk admin API sehingga bisa diakses dari browser

## Troubleshooting

### Jika masih mendapat 403 Forbidden:
1. Pastikan admin key benar
2. Cek logs: `docker logs apisix-node1 --tail 50`
3. Verifikasi config: `docker exec apisix-node1 cat /usr/local/apisix/conf/config.yaml`

### Jika mendapat Connection Refused:
1. Cek status container: `docker compose ps`
2. Tunggu hingga container healthy: `docker compose ps | grep healthy`
3. Restart jika perlu: `docker compose restart apisix1 apisix2 apisix3`

## References

- [APISIX Admin API Docs](https://apisix.apache.org/docs/apisix/admin-api/)
- [APISIX Configuration](https://apisix.apache.org/docs/apisix/deployment-modes/)
