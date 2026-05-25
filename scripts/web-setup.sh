#!/bin/bash
set -euo pipefail
exec > /var/log/web-setup.log 2>&1

echo "==> Waiting for apt lock to clear..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done

echo "==> Installing nginx..."
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

echo "==> Configuring nginx to proxy to internal load balancer (${internal_nlb_ip}:5000)..."
cat > /etc/nginx/sites-available/flask-app <<'NGINX_EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass         http://${internal_nlb_ip}:5000;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
    }
}
NGINX_EOF

ln -sf /etc/nginx/sites-available/flask-app /etc/nginx/sites-enabled/flask-app
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx

echo "==> Web tier setup complete."
