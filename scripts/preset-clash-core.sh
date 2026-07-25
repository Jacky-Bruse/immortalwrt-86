#!/bin/bash
set -e -o pipefail
#=================================================
# File name: preset-clash-core.sh
# Usage: <preset-clash-core.sh $platform> | example: <preset-clash-core.sh x86-64>
# System Required: Linux
# Version: 1.0
# Lisence: MIT
# Author: SuLingGG
# Blog: https://mlapp.cn
#=================================================

# 内核文件名用的是 Go 的架构叫法，与 OpenWrt 平台名做一次映射
case "$1" in
    x86-64)         CORE_ARCH="amd64" ;;
    armv8|aarch64)  CORE_ARCH="arm64" ;;
    *)              echo "unsupported platform: ${1:-<empty>}" >&2; exit 1 ;;
esac

mkdir -p files/etc/openclash/core

# CLASH_DEV_URL="https://raw.githubusercontent.com/vernesong/OpenClash/master/core-lateset/dev/clash-linux-${1}.tar.gz"
# CLASH_TUN_URL=$(curl -fsSL https://api.github.com/repos/vernesong/OpenClash/contents/core-lateset/premium | grep download_url | grep $1 | awk -F '"' '{print $4}')
#CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/master/core-lateset/meta/clash-linux-amd64.tar.gz"
CLASH_META_URL="https://github.com/vernesong/OpenClash/raw/refs/heads/core/dev/meta/clash-linux-${CORE_ARCH}.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Jacky-Bruse/v2ray-rules-dat/releases/latest/download/geosite.dat"

# wget -qO- $CLASH_DEV_URL | tar xOvz > files/etc/openclash/core/clash
# wget -qO- $CLASH_TUN_URL | gunzip -c > files/etc/openclash/core/clash_tun
wget -qO- $CLASH_META_URL | tar xOvz > files/etc/openclash/core/clash_meta
wget -qO- $GEOIP_URL > files/etc/openclash/GeoIP.dat
wget -qO- $GEOSITE_URL > files/etc/openclash/GeoSite.dat

chmod +x files/etc/openclash/core/clash*
