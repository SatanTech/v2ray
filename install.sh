#!/bin/bash

# Cek jika Anda adalah root
if [ "$(id -u)" -ne 0 ]; then
  echo "Harap jalankan script ini sebagai root"
  exit 1
fi

# Meminta domain dari user
#read -rp "Masukkan domain Anda: " domain
mkdir -p /etc/v2ray
touch /etc/v2ray/domain
#echo "$domain" > /etc/v2ray/domain

domainku=`cat /etc/v2ray/domain`

# Generate UUID dari kernel
uuid=$(cat /proc/sys/kernel/random/uuid)

# Update dan install dependencies
apt update -y && apt upgrade -y
apt install -y curl socat wget

# Install V2Ray Core
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

apt install nginx -y
mkdir -p /etc/nginx/ssl

mkdir /root/.acme.sh
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domainku --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $domainku --fullchainpath /etc/nginx/ssl/certificate.crt --keypath /etc/nginx/ssl/private.key --ecc

# Konfigurasi Nginx
cat > /etc/nginx/sites-available/v2ray.conf << END
server {
    listen 80;
    listen 443 ssl;
    server_name $domain;
    ssl_certificate /etc/nginx/ssl/certificate.crt;
    ssl_certificate_key /etc/nginx/ssl/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;

location ~ /v2ray-vmess {
if ($http_upgrade != "Websocket") {
rewrite /(.*) /v2ray-vmess break;
}
proxy_redirect off;
proxy_pass http://127.0.0.1:10000;
proxy_http_version 1.1;
proxy_set_header Upgrade \$http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host \$http_host;
}

location /v2ray-vless {
proxy_redirect off;
proxy_pass http://127.0.0.1:10001;
proxy_http_version 1.1;
proxy_set_header Upgrade \$http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host \$http_host;
    }
}
END

# Aktifkan konfigurasi Nginx dan restart
ln -s /etc/nginx/sites-available/v2ray.conf /etc/nginx/sites-enabled/
systemctl restart nginx

# Buat konfigurasi V2Ray untuk VMess dan VLESS
cat > /usr/local/etc/v2ray/config.json << END
{
    "log": {
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log",
        "loglevel": "info"
    },
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": 10085,
            "protocol": "dokodemo-door",
            "settings": {
                "address": "127.0.0.1"
            },
            "tag": "api"
        },
        {
            "listen": "127.0.0.1",
            "port": "10000",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "f857943f-808c-4e22-b479-099f56b06e5d",
                        "alterId": 64
#vmess
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/v2ray-vmess"
                }
            }
        },
        {
            "listen": "127.0.0.1",
            "port": "10001",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "f857943f-808c-4e22-b479-099f56b06e5d"
#vless
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/v2ray-vless"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        },
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "blocked"
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "ip": [
                    "0.0.0.0/8",
                    "10.0.0.0/8",
                    "100.64.0.0/10",
                    "169.254.0.0/16",
                    "172.16.0.0/12",
                    "192.0.0.0/24",
                    "192.0.2.0/24",
                    "192.168.0.0/16",
                    "198.18.0.0/15",
                    "198.51.100.0/24",
                    "203.0.113.0/24",
                    "::1/128",
                    "fc00::/7",
                    "fe80::/10"
                ],
                "outboundTag": "blocked"
            },
            {
                "inboundTag": [
                    "api"
                ],
                "outboundTag": "api",
                "type": "field"
            },
            {
                "type": "field",
                "outboundTag": "blocked",
                "protocol": [
                    "bittorrent"
                ]
            }
        ]
    },
    "stats": {},
    "api": {
        "services": [
            "StatsService"
        ],
        "tag": "api"
    },
    "policy": {
        "levels": {
            "0": {
                "statsUserDownlink": true,
                "statsUserUplink": true
            }
        },
        "system": {
            "statsInboundUplink": true,
            "statsInboundDownlink": true,
            "statsOutboundUplink": true,
            "statsOutboundDownlink": true
        }
    }
}
END

# Restart V2Ray untuk menerapkan konfigurasi
systemctl restart v2ray

wget -q https://raw.githubusercontent.com/SatanTech/v2ray/refs/heads/main/vmess.sh && chmod +x *

echo "Instalasi selesai. VMess dan VLESS berjalan di domain $domain dengan port 443."
