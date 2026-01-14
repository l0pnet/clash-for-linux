#!/bin/bash
set -euo pipefail

#################### 基本变量 ####################

Server_Dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Service_Name="clash-for-linux"

Service_User="${CLASH_SERVICE_USER:-clash}"
Service_Group="${CLASH_SERVICE_GROUP:-$Service_User}"

Unit_Path="/etc/systemd/system/${Service_Name}.service"
PID_FILE="$Server_Dir/temp/clash.pid"

#################### 权限检查 ####################

if [ "$(id -u)" -ne 0 ]; then
  echo -e "\033[31m[ERROR] 需要 root 权限来安装 systemd 单元\033[0m"
  exit 1
fi

#################### 用户 / 组 ####################

if ! getent group "$Service_Group" >/dev/null 2>&1; then
  groupadd --system "$Service_Group"
fi

if ! id "$Service_User" >/dev/null 2>&1; then
  useradd \
    --system \
    --no-create-home \
    --shell /usr/sbin/nologin \
    --gid "$Service_Group" \
    "$Service_User"
fi

#################### 目录初始化 ####################

install -d -m 0755 \
  "$Server_Dir/conf" \
  "$Server_Dir/logs" \
  "$Server_Dir/temp"

chown -R "$Service_User:$Service_Group" \
  "$Server_Dir/conf" \
  "$Server_Dir/logs" \
  "$Server_Dir/temp"

#################### 生成 systemd Unit ####################

cat >"$Unit_Path"<<EOF
[Unit]
Description=Clash for Linux
After=network.target
Wants=network.target

[Service]
Type=forking
WorkingDirectory=$Server_Dir

# 启动 / 停止
ExecStart=/bin/bash $Server_Dir/start.sh
ExecStop=/bin/bash $Server_Dir/shutdown.sh

# PID 管理
PIDFile=$PID_FILE

# 失败策略
Restart=on-failure
RestartSec=5
TimeoutStartSec=120
TimeoutStopSec=30

# 运行用户
User=$Service_User
Group=$Service_Group

# 环境变量
Environment=SYSTEMD_MODE=true
Environment=CLASH_ENV_FILE=$Server_Dir/temp/clash-for-linux.sh

[Install]
WantedBy=multi-user.target
EOF

#################### 刷新 systemd ####################

systemctl daemon-reload

echo -e "\033[32m[OK] 已生成 systemd 单元: ${Unit_Path}\033[0m"
echo -e "可执行以下命令启动服务："
echo -e "  sudo systemctl enable --now ${Service_Name}.service"
