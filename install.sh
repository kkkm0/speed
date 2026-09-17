#!/bin/bash

set -e

# ==========================================
# VPS Bandwidth Limiter
# Usage:
#   bash install.sh 100 200
#
# 100 = Upload Mbps
# 200 = Download Mbps
# ==========================================

CONFIG="/etc/vps-bandwidth.conf"
SCRIPT="/usr/local/sbin/vps-bandwidth.sh"
SERVICE="/etc/systemd/system/vps-bandwidth.service"

# ==========================================
# Root check
# ==========================================

if [ "$EUID" -ne 0 ]; then
    echo "错误：请使用 root 运行"
    exit 1
fi

# ==========================================
# 参数检查
# ==========================================

UPLOAD="$1"
DOWNLOAD="$2"

if [ -z "$UPLOAD" ] || [ -z "$DOWNLOAD" ]; then
    echo ""
    echo "用法:"
    echo ""
    echo "  bash install.sh <上传Mbps> <下载Mbps>"
    echo ""
    echo "例如:"
    echo "  bash install.sh 100 200"
    echo "  bash install.sh 500 500"
    echo "  bash install.sh 1000 1000"
    echo ""
    exit 1
fi

if ! [[ "$UPLOAD" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "错误：上传速度必须是数字"
    exit 1
fi

if ! [[ "$DOWNLOAD" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "错误：下载速度必须是数字"
    exit 1
fi

# ==========================================
# 自动检测公网网卡
# ==========================================

DEV=$(ip route get 1.1.1.1 2>/dev/null | awk '{
    for(i=1;i<=NF;i++)
        if($i=="dev") {
            print $(i+1)
            exit
        }
}')

if [ -z "$DEV" ]; then
    echo "错误：无法自动检测公网网卡"
    exit 1
fi

IFB="ifb0"

echo ""
echo "=========================================="
echo "       VPS Bandwidth Limiter"
echo "=========================================="
echo " Upload    : ${UPLOAD} Mbps"
echo " Download  : ${DOWNLOAD} Mbps"
echo " Interface : ${DEV}"
echo " IFB       : ${IFB}"
echo "=========================================="
echo ""

# ==========================================
# 安装 iproute2
# ==========================================

if ! command -v tc >/dev/null 2>&1; then
    echo "正在安装 iproute2..."

    apt-get update
    apt-get install -y iproute2
fi

# ==========================================
# 写入配置文件
# ==========================================

cat > "$CONFIG" <<EOF
UPLOAD=${UPLOAD}mbit
DOWNLOAD=${DOWNLOAD}mbit
DEV=${DEV}
IFB=${IFB}
EOF

# ==========================================
# 创建实际限速脚本
# ==========================================

cat > "$SCRIPT" <<'EOF'
#!/bin/bash

set -e

CONFIG="/etc/vps-bandwidth.conf"

if [ ! -f "$CONFIG" ]; then
    echo "配置文件不存在：$CONFIG"
    exit 1
fi

source "$CONFIG"

if [ -z "$UPLOAD" ] || [ -z "$DOWNLOAD" ]; then
    echo "UPLOAD 或 DOWNLOAD 未设置"
    exit 1
fi

if [ -z "$DEV" ]; then
    echo "DEV 未设置"
    exit 1
fi

if [ -z "$IFB" ]; then
    IFB="ifb0"
fi

echo "======================================"
echo " VPS Bandwidth Limit"
echo " Upload   : $UPLOAD"
echo " Download : $DOWNLOAD"
echo " Device   : $DEV"
echo " IFB      : $IFB"
echo "======================================"

# ======================================
# 加载 IFB
# ======================================

modprobe ifb

# ======================================
# 创建 IFB
# ======================================

if ! ip link show "$IFB" >/dev/null 2>&1; then
    ip link add "$IFB" type ifb
fi

ip link set "$IFB" up

# ======================================
# 清除旧规则
# ======================================

tc qdisc del dev "$DEV" root 2>/dev/null || true
tc qdisc del dev "$DEV" ingress 2>/dev/null || true
tc qdisc del dev "$IFB" root 2>/dev/null || true

# ======================================
# 出站
# VPS -> Internet
# ======================================

tc qdisc replace dev "$DEV" root tbf \
    rate "$UPLOAD" \
    burst 32kbit \
    latency 400ms

# ======================================
# 入站
# Internet -> VPS
# ======================================

tc qdisc replace dev "$DEV" handle ffff: ingress

tc filter replace dev "$DEV" parent ffff: \
    protocol all \
    u32 match u32 0 0 \
    action mirred egress redirect dev "$IFB"

tc qdisc replace dev "$IFB" root tbf \
    rate "$DOWNLOAD" \
    burst 32kbit \
    latency 400ms

echo ""
echo "======================================"
echo " 限速设置完成"
echo "======================================"
echo ""

tc qdisc show dev "$DEV"
tc qdisc show dev "$IFB"
EOF

chmod +x "$SCRIPT"

# ==========================================
# 创建 systemd 服务
# ==========================================

cat > "$SERVICE" <<EOF
[Unit]
Description=VPS Bandwidth Limit
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# ==========================================
# systemd
# ==========================================

systemctl daemon-reload

systemctl enable vps-bandwidth.service

systemctl restart vps-bandwidth.service

echo ""
echo "=========================================="
echo "        设置完成"
echo "=========================================="
echo ""
echo "上传限制 : ${UPLOAD} Mbps"
echo "下载限制 : ${DOWNLOAD} Mbps"
echo "网卡     : ${DEV}"
echo ""
echo "配置文件:"
echo "  $CONFIG"
echo ""
echo "修改速度:"
echo "  $CONFIG"
echo ""
echo "查看状态:"
echo "  systemctl status vps-bandwidth.service"
echo ""
echo "查看限速:"
echo "  tc qdisc show dev $DEV"
echo "  tc qdisc show dev $IFB"
echo ""
echo "=========================================="
