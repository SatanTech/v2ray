#!/bin/bash

# Path file konfigurasi V2Ray
domain=`cat /etc/v2ray/domain`
config_file="/usr/local/etc/v2ray/config.json"
# Cek jika config.json ada
if [ ! -f "$config_file" ]; then
  echo "File konfigurasi $config_file tidak ditemukan!"
  exit 1
fi

# Meminta input username
read -rp "Masukkan username: " username

# Meminta input expired dalam jumlah hari
read -rp "Masukkan expired (dalam hari): " days

# Menghitung tanggal expired (tambahkan jumlah hari dari hari ini)
expired=$(date -d "+$days days" +"%Y-%m-%d")

# Generate UUID baru dari kernel
uuid=$(cat /proc/sys/kernel/random/uuid)

# Tambahkan client baru ke dalam config.json
sed -i '/#vmess$/a\### '"$username $exp"'\
},{"id": "'""$uuid""'","alterId": '"64"',"email": "'""$username""'"' /usr/local/etc/v2ray/config.json

# Restart V2Ray untuk menerapkan konfigurasi baru
systemctl restart v2ray

# simpan akun
cat > /etc/v2ray/$username-tls.json <<EOF
{
  "v": "2",
  "ps": "$username",
  "add": "$domain",
  "port": "443",
  "id": "$uuid",
  "aid": "64",
  "net": "ws",
  "type": "none",
  "host": "$domain",
  "path": "/v2ray-vmess",
  "tls": "tls"
}
EOF

cat > /etc/v2ray/$username-ntls.json <<EOF
{
  "v": "2",
  "ps": "$username",
  "add": "$domain",
  "port": "80",
  "id": "$uuid",
  "aid": "64",
  "net": "ws",
  "type": "none",
  "host": "$domain",
  "path": "/v2ray-vmess",
  "tls": "none"
}
EOF

# Membuat konfigurasi VMess
vmess_json=$(cat <<EOF
{
  "v": "2",
  "ps": "$username",
  "add": "$domain",
  "port": "443",
  "id": "$uuid",
  "aid": "64",
  "net": "ws",
  "type": "none",
  "host": "$domain",
  "path": "/v2ray-vmess",
  "tls": "tls"
}
EOF
)

vmess_ntls_json=$(cat <<EOF
{
  "v": "2",
  "ps": "$username",
  "add": "$domain",
  "port": "80",
  "id": "$uuid",
  "aid": "64",
  "net": "ws",
  "type": "none",
  "host": "$domain",
  "path": "/v2ray-vmess",
  "tls": "none"
}
EOF
)

# Encode VMess JSON ke Base64
vmess_base64=$(echo -n "$vmess_json" | base64 -w 0)
vmess_ntls_base64=$(echo -n "$vmess_ntls_json" | base64 -w 0)

# Menampilkan link VMess
echo "Akun VMess berhasil dibuat!"
echo "Username: $username"
echo "UUID: $uuid"
echo "Expired: $expired"
echo "Link VMess NTLS: vmess://$vmess_ntls_base64"
echo "Link VMess: vmess://$vmess_base64"