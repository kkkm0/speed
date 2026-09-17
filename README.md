# VPS Speed Limiter

一个简单的 Linux VPS 双向带宽限制工具。

基于 Linux `tc` + `TBF` + `IFB` 实现，可以同时限制：

* **上传速度**：VPS → Internet
* **下载速度**：Internet → VPS

支持 systemd 开机自动恢复限速。

适用于 Debian 12 等使用 `iproute2` 的 Linux 系统。

---

## ✨ 特性

* 🚀 一条命令完成安装
* ⬆️ 独立设置上传速度
* ⬇️ 独立设置下载速度
* 🔄 重启后自动恢复
* 🔧 重复执行即可修改速度
* 🌐 自动检测公网网卡
* 📦 自动创建 IFB 虚拟网卡
* 🧹 提供一键卸载
* 🐧 无需 Docker
* ⚡ 基于 Linux 原生 `tc`

---

## 📥 安装

需要使用 `root` 用户执行。

### 上传 100 Mbps / 下载 200 Mbps

```bash
wget -qO- https://raw.githubusercontent.com/kkkm0/speed/main/install.sh | bash -s -- 100 200
```

参数格式：

```text
install.sh <上传Mbps> <下载Mbps>
```

例如：

```text
100 200
↑   ↑
上传 下载
```

---

## 🚀 使用示例

### 100 / 200 Mbps

```bash
wget -qO- https://raw.githubusercontent.com/kkkm0/speed/main/install.sh | bash -s -- 100 200
```

### 500 / 500 Mbps

```bash
wget -qO- https://raw.githubusercontent.com/kkkm0/speed/main/install.sh | bash -s -- 500 500
```

### 1000 / 1000 Mbps

即双向 1 Gbps：

```bash
wget -qO- https://raw.githubusercontent.com/kkkm0/speed/main/install.sh | bash -s -- 1000 1000
```

### 上传 1000 Mbps / 下载 500 Mbps

```bash
wget -qO- https://raw.githubusercontent.com/kkkm0/speed/main/install.sh | bash -s -- 1000 500
```

### 上传 500 Mbps / 下载 1000 Mbps

```bash
wget -qO- https://raw.githubusercontent.com/kkkm0/speed/main/install.sh | bash -s -- 500 1000
```

---

## 🔧 修改速度

已经安装过的 VPS 不需要重新手动配置。

直接再次执行安装命令即可。

例如原来：

```text
100 / 200 Mbps
```

修改为：

```text
500 / 500 Mbps
```

直接执行：

```bash
wget -qO- https://raw.githubusercontent.com/kkkm0/speed/main/install.sh | bash -s -- 500 500
```

脚本会自动更新配置并立即应用。

---

## 📊 查看当前配置

查看配置文件：

```bash
cat /etc/vps-bandwidth.conf
```

例如：

```text
UPLOAD=500mbit
DOWNLOAD=500mbit
DEV=eth0
IFB=ifb0
```

---

## 🔍 查看限速状态

查看公网网卡：

```bash
ip -br link
```

查看 `tc`：

```bash
tc qdisc show dev eth0
```

查看 IFB：

```bash
tc qdisc show dev ifb0
```

查看 systemd：

```bash
systemctl status vps-bandwidth.service
```

---

## 🔄 开机自动恢复

安装完成后会自动创建：

```text
/etc/systemd/system/vps-bandwidth.service
```

并启用：

```bash
systemctl enable vps-bandwidth.service
```

因此 VPS 重启后，限速规则会自动重新加载。

可以通过：

```bash
systemctl is-enabled vps-bandwidth.service
```

确认是否启用了开机启动。

---

## 🧹 卸载

如果想完全解除带宽限制并恢复 VPS 原始网络速度：

```bash
wget -qO- https://raw.githubusercontent.com/kkkm0/speed/main/uninstall.sh | bash
```

卸载脚本会：

1. 停止 systemd 服务
2. 禁用开机自动限速
3. 删除 `tc` 限速规则
4. 删除 IFB
5. 删除配置文件
6. 删除限速脚本
7. 删除 systemd 服务

---

## ⚙️ 工作原理

### 上传

VPS → Internet

使用 `tc TBF` 直接限制公网网卡的出站流量。

```text
VPS
 │
 ▼
 eth0
 │
 TBF
 │
 ▼
Internet
```

### 下载

Internet → VPS

Linux 默认无法直接使用普通 TBF 对 ingress 流量进行整形，因此使用 IFB 将入站流量重定向到虚拟网卡，再进行 TBF 限速。

```text
Internet
   │
   ▼
 eth0
   │
 ingress
   │
   ▼
 ifb0
   │
  TBF
   │
   ▼
 VPS
```

因此可以分别控制：

```text
UPLOAD   = VPS → Internet
DOWNLOAD = Internet → VPS
```

---

## 📌 注意事项

### 1. 单位是 Mbps

例如：

```text
100  = 100 Mbps
500  = 500 Mbps
1000 = 1 Gbps
```

这里使用的是 **Mbit/s（Mbps）**，不是 MB/s。

换算：

```text
100 Mbps  ≈ 12.5 MB/s
500 Mbps  ≈ 62.5 MB/s
1000 Mbps ≈ 125 MB/s
```

实际测速速度可能会因为线路、测速服务器、TCP 并发、系统负载等因素低于设置值。

---

### 2. 限制的是整台 VPS

带宽限制作用于公网网卡。

例如：

```text
UPLOAD=500mbit
DOWNLOAD=500mbit
```

表示整台 VPS 的总出站/入站带宽分别限制在约 500 Mbps。

如果 VPS 上运行多个：

* Docker 容器
* 网站
* 节点
* 下载服务
* SSH
* 其他网络程序

它们共享这个带宽上限。

并不是每个程序各自拥有 500 Mbps。

---

### 3. 修改速度不会改变 VPS 服务商的套餐

该工具只是 Linux 系统层面的网络整形。

例如 VPS 实际可以跑：

```text
1 Gbps
```

设置：

```text
500 / 500
```

之后系统会主动将流量限制在约：

```text
500 Mbps
```

不会改变 VPS 服务商后台的带宽、流量套餐或计费规则。

---

## 📁 文件

安装后主要会创建：

```text
/etc/vps-bandwidth.conf
/usr/local/sbin/vps-bandwidth.sh
/etc/systemd/system/vps-bandwidth.service
```

GitHub 仓库：

```text
https://github.com/kkkm0/speed
```

---

## 📜 License

MIT License
