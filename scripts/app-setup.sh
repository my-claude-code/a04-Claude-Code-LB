#!/bin/bash
set -euo pipefail
exec > /var/log/app-setup.log 2>&1

echo "==> Waiting for apt lock to clear..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done

echo "==> Installing dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv git

echo "==> Cloning app from GitHub..."
cd /opt
git clone https://github.com/my-claude-code/a02-Claude-Code-MYSQL.git flask-app
cd flask-app

echo "==> Creating virtual environment and installing packages..."
python3 -m venv venv
source venv/bin/activate
pip install --quiet -r requirements.txt
pip install --quiet gunicorn

echo "==> Writing .env..."
cat > .env <<'ENV_EOF'
ENTRA_CLIENT_ID=${entra_client_id}
ENTRA_CLIENT_SECRET=${entra_client_secret}
ENTRA_TENANT_ID=${entra_tenant_id}
REDIRECT_URI=https://${agw_fqdn}/auth/callback
FLASK_SECRET_KEY=${flask_secret_key}
DATABASE_URL=mysql+pymysql://${db_user}:${db_password}@${mysql_private_ip}:3306/${db_name}
ENV_EOF

echo "==> Waiting for MySQL on ${mysql_private_ip}..."
i=0
until python3 -c "
import pymysql
pymysql.connect(host='${mysql_private_ip}', user='${db_user}', password='${db_password}', database='${db_name}').close()
" 2>/dev/null; do
    i=$((i+1))
    echo "Attempt $i — MySQL not ready yet, retrying in 10s..."
    sleep 10
done
echo "MySQL is ready after $i attempt(s)."

echo "==> Initialising database schema..."
# Stagger to reduce race conditions between the two VMSS instances
sleep $((RANDOM % 20))
FLASK_APP=app.py venv/bin/flask init-db

echo "==> Creating systemd service for gunicorn..."
cat > /etc/systemd/system/flask-app.service <<'SVC_EOF'
[Unit]
Description=Flask Entra Notes (gunicorn)
After=network.target

[Service]
User=root
WorkingDirectory=/opt/flask-app
Environment=PATH=/opt/flask-app/venv/bin
ExecStart=/opt/flask-app/venv/bin/gunicorn -w 2 -b 0.0.0.0:5000 app:app
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC_EOF

systemctl daemon-reload
systemctl enable flask-app
systemctl start flask-app

echo "==> App tier setup complete. Listening on port 5000."
