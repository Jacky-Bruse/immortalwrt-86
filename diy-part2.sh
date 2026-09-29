#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
sed -i 's/192.168.1.1/192.168.1.3/g' package/base-files/files/bin/config_generate
#sed -i 's/KERNEL_PATCHVER:=5.15/KERNEL_PATCHVER:=5.10/g' target/linux/x86/Makefile
#sed -i "s/.*PKG_VERSION:=.*/PKG_VERSION:=4.3.9_v1.2.14/" package/lean/qBittorrent-static/Makefile
# welcome test 

# 首次开机关闭流量卸载：ImmortalWrt 默认开启，会让 eqos 按设备限速失效
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-disable-flow-offload <<'EOF'
#!/bin/sh
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall
exit 0
EOF

# AdGuardHome 工作目录默认在 /var（内存盘），重启后规则和统计全丢，改到固定存储
# 24.10 选项名为 workdir，25.12 为 work_dir；仅在仍为默认值时修改，不覆盖手动设置
cat > files/etc/uci-defaults/99-adguardhome-workdir <<'EOF'
#!/bin/sh
for opt in work_dir workdir; do
	[ "$(uci -q get adguardhome.config.$opt)" = "/var/lib/adguardhome" ] || continue
	uci set adguardhome.config.$opt='/etc/adguardhome/work'
	uci commit adguardhome
done
exit 0
EOF
