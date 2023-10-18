#!/usr/bin/env bash

set -e
exec 2>&1

UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
WSPATH=${WSPATH:-'argo'}

# generate warp config
wget -qO /usr/bin/warp-reg https://github.com/badafans/warp-reg/releases/download/v1.0/main-linux-amd64
chmod +x /usr/bin/warp-reg
/usr/bin/warp-reg > /etc/warp.conf
rm /usr/bin/warp-reg

WG_PRIVATE_KEY=$(grep private_key /etc/warp.conf | sed "s|.*: ||")
WG_PEER_PUBLIC_KEY=$(grep public_key /etc/warp.conf | sed "s|.*: ||")
WG_IP6_ADDR=$(grep v6 /etc/warp.conf | sed "s|.*: ||")
WG_RESERVED=$(grep reserved /etc/warp.conf | sed "s|.*: ||")
if [[ ! "${WG_RESERVED}" =~ , ]]; then
    WG_RESERVED=\"${WG_RESERVED}\"
fi

generate_config() {
  cat > /app/config.json << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "route": {
    "rules": [
      {
        "geosite": ["openai"],
        "outbound": "warp-IPv4-out"
      }
    ]
  },
  "inbounds": [
    {
      "sniff": true,
      "sniff_override_destination": true,
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": 63003,
      "users": [
        {
          "uuid": "${UUID}",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/${WSPATH}/vm",
        "max_early_data": 2048,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "direct",
      "tag": "warp-IPv4-out",
      "detour": "wireguard-out",
      "domain_strategy": "ipv4_only"
    },
    {
      "type": "direct",
      "tag": "warp-IPv6-out",
      "detour": "wireguard-out",
      "domain_strategy": "ipv6_only"
    },
    {
      "type": "wireguard",
      "tag": "wireguard-out",
      "server": "engage.cloudflareclient.com",
      "server_port": 2408,
      "local_address": [
        "198.18.0.1/32",
        "fd00::1/128"
      ],
      "private_key": "WG_PRIVATE_KEY",
      "peer_public_key": "WG_PEER_PUBLIC_KEY",
      "reserved": [0, 0, 0],
      "mtu": 1408
    }
  ]
}
EOF
}

generate_pm2_file() {
  cat > /app/ecosystem.config.js << EOF
module.exports = {
  apps: [
    {
      name: "web",
      script: "/app/app* run -c /app/config.json"
    }
  ]
}
EOF
}

generate_config
generate_pm2_file

sed -i "s|WG_PRIVATE_KEY|${WG_PRIVATE_KEY}|;s|WG_PEER_PUBLIC_KEY|${WG_PEER_PUBLIC_KEY}|;s|fd00::1|${WG_IP6_ADDR}|;s|\[0, 0, 0\]|${WG_RESERVED}|" /app/config.json

[ -e /app/ecosystem.config.js ] && pm2 start /app/ecosystem.config.js