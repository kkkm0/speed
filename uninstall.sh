#!/bin/bash

set -e

CONFIG="/etc/vps-bandwidth.conf"
SCRIPT="/usr/local/sbin/vps-bandwidth.sh"
SERVICE="/etc/systemd/system/vps-bandwidth.service"

echo ""
echo "======================================"
echo " VPS Bandwidth Limiter Uninstaller"
echo "======================================"
echo ""

# 停止并禁用服务
systemctl disable --now vps-bandwidth.service 2>/dev/null || true

# 自动获取网卡
DEV=$(ip route get 1.1.1.1 2>/dev/null | awk '{
    for(i=1;i<=NF;i++)
        if($i=="dev") {
            print $(i+1)
            exit
        }
}')

# 删除 eth0 / 当前网卡规则
if [ -n "$DEV" ]; then
    tc qdisc del dev "$DEV" root 2>/dev/null || true
    tc qdisc del dev "$DEV" ingress 2>/dev/null || true
fi

# 删除 IFB
tc qdisc del dev ifb0 root 2>/dev/null || true
ip link delete ifb0 2>/dev/null || true

# 删除文件
rm -f "$CONFIG"
rm -f "$SCRIPT"
rm -f "$SERVICE"

systemctl daemon-reload

echo ""
echo "======================================"
echo " 带宽限制已经完全解除"
echo "======================================"
echo ""
