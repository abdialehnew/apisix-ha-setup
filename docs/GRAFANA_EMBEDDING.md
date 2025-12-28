# Cara Embed Grafana di APISIX Dashboard

## 🔧 Konfigurasi yang Sudah Diterapkan

Grafana sudah dikonfigurasi dengan settings berikut untuk mendukung embedding:

### 1. Environment Variables di Docker Compose
```yaml
- GF_SECURITY_ALLOW_EMBEDDING=true          # Izinkan embedding di iframe
- GF_AUTH_ANONYMOUS_ENABLED=true            # Enable anonymous access
- GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer         # Role untuk anonymous user
- GF_SECURITY_COOKIE_SAMESITE=none          # Cookie policy untuk iframe
- GF_SECURITY_COOKIE_SECURE=false           # HTTP cookie (set true jika HTTPS)
```

### 2. Grafana.ini Configuration
File konfigurasi custom sudah dimount di `/etc/grafana/grafana.ini` dengan settings:
- `allow_embedding = true`
- `cookie_samesite = none`
- Anonymous access enabled dengan role Viewer

## 📊 Cara Embed Grafana Panel ke APISIX Dashboard

### Opsi 1: Embed Individual Panel

1. **Buat atau buka dashboard di Grafana**
   - Akses: http://localhost:3000
   - Login: admin/admin

2. **Get Panel Embed URL**
   - Klik pada panel title
   - Pilih "Share" → "Link" tab
   - Enable "Shorten URL" (optional)
   - Copy URL

3. **Embed di APISIX Dashboard**
   ```html
   <iframe 
     src="http://localhost:3000/d-solo/dashboard-uid/dashboard-name?orgId=1&panelId=2&theme=light"
     width="100%" 
     height="400" 
     frameborder="0">
   </iframe>
   ```

### Opsi 2: Embed Full Dashboard

1. **Get Dashboard URL**
   - Buka dashboard yang ingin di-embed
   - Copy URL dari browser
   - Tambahkan parameter `&kiosk` untuk fullscreen mode

2. **Embed Code**
   ```html
   <iframe 
     src="http://localhost:3000/d/dashboard-uid/dashboard-name?orgId=1&kiosk=tv"
     width="100%" 
     height="800" 
     frameborder="0">
   </iframe>
   ```

## 🎨 Parameter URL untuk Customization

### Time Range
```
&from=now-6h&to=now           # Last 6 hours
&from=now-24h&to=now          # Last 24 hours
&from=now-7d&to=now           # Last 7 days
```

### Theme
```
&theme=light                  # Light theme
&theme=dark                   # Dark theme
```

### Kiosk Mode
```
&kiosk                        # Kiosk mode (hide top nav)
&kiosk=tv                     # TV mode (hide all controls)
```

### Refresh Rate
```
&refresh=5s                   # Refresh every 5 seconds
&refresh=1m                   # Refresh every 1 minute
&refresh=5m                   # Refresh every 5 minutes
```

### Variables (jika dashboard punya variables)
```
&var-node=apisix1            # Set variable value
&var-status=200              # Multiple variables
```

## 💻 Contoh Implementasi di APISIX Dashboard

### React/Vue Component
```javascript
// React Example
const GrafanaPanel = ({ panelId, dashboardUid }) => {
  const grafanaUrl = `http://localhost:3000/d-solo/${dashboardUid}/apisix-metrics?orgId=1&panelId=${panelId}&theme=light&from=now-6h&to=now&refresh=30s`;
  
  return (
    <div className="grafana-panel">
      <iframe
        src={grafanaUrl}
        width="100%"
        height="400px"
        frameBorder="0"
        title="Grafana Panel"
      />
    </div>
  );
};

// Usage
<GrafanaPanel panelId={2} dashboardUid="apisix-overview" />
```

### HTML Static
```html
<!DOCTYPE html>
<html>
<head>
  <title>APISIX Dashboard</title>
  <style>
    .dashboard-container {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 20px;
      padding: 20px;
    }
    .panel {
      border: 1px solid #ddd;
      border-radius: 8px;
      overflow: hidden;
    }
    iframe {
      border: none;
      width: 100%;
      height: 400px;
    }
  </style>
</head>
<body>
  <div class="dashboard-container">
    <!-- Request Rate Panel -->
    <div class="panel">
      <h3>Request Rate</h3>
      <iframe src="http://localhost:3000/d-solo/apisix-overview/apisix-metrics?orgId=1&panelId=1&theme=light&from=now-1h&to=now&refresh=30s"></iframe>
    </div>
    
    <!-- Error Rate Panel -->
    <div class="panel">
      <h3>Error Rate</h3>
      <iframe src="http://localhost:3000/d-solo/apisix-overview/apisix-metrics?orgId=1&panelId=2&theme=light&from=now-1h&to=now&refresh=30s"></iframe>
    </div>
    
    <!-- Latency Panel -->
    <div class="panel">
      <h3>Response Latency</h3>
      <iframe src="http://localhost:3000/d-solo/apisix-overview/apisix-metrics?orgId=1&panelId=3&theme=light&from=now-1h&to=now&refresh=30s"></iframe>
    </div>
    
    <!-- Active Connections -->
    <div class="panel">
      <h3>Active Connections</h3>
      <iframe src="http://localhost:3000/d-solo/apisix-overview/apisix-metrics?orgId=1&panelId=4&theme=light&from=now-1h&to=now&refresh=30s"></iframe>
    </div>
  </div>
</body>
</html>
```

## 🔐 Security Considerations

### Production Environment
Untuk production, sebaiknya:

1. **Disable Anonymous Access & Use Auth Proxy**
   ```yaml
   - GF_AUTH_ANONYMOUS_ENABLED=false
   - GF_AUTH_PROXY_ENABLED=true
   - GF_AUTH_PROXY_HEADER_NAME=X-WEBAUTH-USER
   ```

2. **Restrict Embedding Domain**
   Edit `grafana.ini`:
   ```ini
   [security]
   allow_embedding = true
   cookie_samesite = lax
   cookie_secure = true  # Jika menggunakan HTTPS
   
   # Tambahkan CSP header untuk restrict domain
   content_security_policy = true
   content_security_policy_template = """script-src 'self' 'unsafe-eval' 'unsafe-inline';object-src 'none';font-src 'self';style-src 'self' 'unsafe-inline';img-src * data:;base-uri 'self';connect-src 'self' grafana.com ws://$ROOT_PATH wss://$ROOT_PATH;manifest-src 'self';media-src 'none';form-action 'self';"""
   ```

3. **Use HTTPS**
   ```yaml
   - GF_SERVER_PROTOCOL=https
   - GF_SERVER_CERT_FILE=/path/to/cert.pem
   - GF_SERVER_CERT_KEY=/path/to/key.pem
   ```

4. **API Key Authentication** (Recommended)
   - Buat API Key di Grafana: Configuration → API Keys
   - Gunakan API Key untuk authenticated requests
   ```
   http://localhost:3000/d-solo/...?auth_token=YOUR_API_KEY
   ```

## 🚀 Deploy & Testing

### 1. Restart Grafana dengan Config Baru
```bash
docker-compose restart grafana
```

### 2. Verify Settings
```bash
# Check if embedding is enabled
curl -s http://localhost:3000/api/frontend/settings | jq '.allowEmbedding'

# Should return: true
```

### 3. Test Embedding
Buat file HTML test:
```html
<!DOCTYPE html>
<html>
<body>
  <h1>Test Grafana Embed</h1>
  <iframe 
    src="http://localhost:3000/d/apisix/apisix-overview?orgId=1&kiosk=tv" 
    width="1200" 
    height="800">
  </iframe>
</body>
</html>
```

## 📝 Troubleshooting

### Iframe Tidak Muncul / Blank
1. **Check browser console** untuk CSP errors
2. **Verify Grafana config**: `docker exec grafana cat /etc/grafana/grafana.ini | grep allow_embedding`
3. **Test anonymous access**: Buka Grafana di incognito/private window
4. **Check network tab**: Pastikan requests ke Grafana berhasil (status 200)

### "X-Frame-Options" Error
- Pastikan `allow_embedding = true` di grafana.ini
- Restart Grafana container

### CORS Issues
- Set `GF_SECURITY_COOKIE_SAMESITE=none` di docker-compose
- Jika menggunakan HTTPS, set `GF_SECURITY_COOKIE_SECURE=true`

### Anonymous Access Tidak Berfungsi
```bash
# Check anonymous settings
docker exec grafana grafana-cli admin settings list | grep anonymous

# Verify environment variables
docker exec grafana env | grep GF_AUTH_ANONYMOUS
```

## 📚 Resources

- [Grafana Sharing Documentation](https://grafana.com/docs/grafana/latest/panels-visualizations/panel-editor-overview/)
- [Grafana Configuration Options](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
- [Embedding Grafana Panels](https://grafana.com/docs/grafana/latest/dashboards/share-dashboards-panels/)
